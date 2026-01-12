import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'utils.dart';
import 'look_engine.dart';

class EyeshadowPainter {
  final Face face;
  final Color eyeshadowColor;
  final double intensity;

  EyeshadowPainter({
    required this.face,
    required this.eyeshadowColor,
    required this.intensity,
  });

  // ---------- PROFESSIONAL EYESHADOW HELPER FUNCTIONS ----------

  /// Get smooth upper eyelid curve from eye points
  List<ui.Offset> _getUpperLidCurve(List<ui.Offset> eyePoints) {
    if (eyePoints.length < 8) return eyePoints;
    
    // Find min and max Y to identify top half
    double minY = double.infinity, maxY = -double.infinity;
    for (final p in eyePoints) {
      minY = min(minY, p.dy);
      maxY = max(maxY, p.dy);
    }
    
    // Take points in the upper 40% of eye (more stable)
    final upperThreshold = minY + (maxY - minY) * 0.40;
    var upperPoints = eyePoints.where((p) => p.dy <= upperThreshold).toList();
    
    if (upperPoints.length < 3) {
      // Fallback: take all points with Y less than average
      final avgY = (minY + maxY) / 2;
      upperPoints = eyePoints.where((p) => p.dy <= avgY).toList();
    }
    
    // Sort by X for consistent drawing
    upperPoints.sort((a, b) => a.dx.compareTo(b.dx));
    
    // Reduce jitter by averaging nearby points
    final smoothed = <ui.Offset>[];
    final windowSize = 2;
    
    for (int i = 0; i < upperPoints.length; i++) {
      int start = max(0, i - windowSize);
      int end = min(upperPoints.length - 1, i + windowSize);
      
      double sumX = 0, sumY = 0;
      int count = 0;
      
      for (int j = start; j <= end; j++) {
        sumX += upperPoints[j].dx;
        sumY += upperPoints[j].dy;
        count++;
      }
      
      smoothed.add(ui.Offset(sumX / count, sumY / count));
    }
    
    // Downsample to 6-8 points for smooth curve
    final step = max(1, smoothed.length ~/ 6);
    final result = <ui.Offset>[];
    for (int i = 0; i < smoothed.length; i += step) {
      if (result.length < 8) {
        result.add(smoothed[i]);
      }
    }
    
    // Ensure we have first and last points
    if (result.isNotEmpty && !result.contains(smoothed.first)) {
      result.insert(0, smoothed.first);
    }
    if (result.isNotEmpty && !result.contains(smoothed.last)) {
      result.add(smoothed.last);
    }
    
    return result;
  }

  /// Create accurate eyelid region that sits on the eyelid
  Path _createAccurateEyelidRegion({
    required List<ui.Offset> upperLid,
    required ui.Rect eyeBounds,
    required List<ui.Offset> allEyePoints,
  }) {
    final path = Path();
    
    if (upperLid.length < 3) {
      // Fallback: create simple region based on eye bounds
      final simpleRegion = Path()
        ..moveTo(eyeBounds.left, eyeBounds.top)
        ..quadraticBezierTo(
          eyeBounds.center.dx,
          eyeBounds.top - eyeBounds.height * 0.3,
          eyeBounds.right,
          eyeBounds.top,
        )
        ..lineTo(eyeBounds.right, eyeBounds.top + eyeBounds.height * 0.3)
        ..quadraticBezierTo(
          eyeBounds.center.dx,
          eyeBounds.top + eyeBounds.height * 0.5,
          eyeBounds.left,
          eyeBounds.top + eyeBounds.height * 0.3,
        )
        ..close();
      return simpleRegion;
    }
    
    // 1. Create the lower boundary (lash line) - use upper lid points but lift slightly
    final liftFromLid = max(eyeBounds.height * 0.05, 2.0); // Slight lift from actual lid
    final lowerPoints = upperLid.map((p) => 
      ui.Offset(p.dx, p.dy - liftFromLid)
    ).toList();
    
    // 2. Create the upper boundary (crease) - lift more for eyeshadow area
    final creaseLift = max(eyeBounds.height * 0.4, 8.0);
    final upperPoints = upperLid.map((p) => 
      ui.Offset(p.dx, p.dy - creaseLift)
    ).toList();
    
    // 3. Create smooth curves for both boundaries
    final lowerCurve = _createSmoothCurve(lowerPoints);
    final upperCurve = _createSmoothCurve(upperPoints.reversed.toList());
    
    // 4. Combine into closed region
    path.addPath(upperCurve, ui.Offset.zero);
    path.lineTo(lowerPoints.last.dx, lowerPoints.last.dy);
    path.addPath(lowerCurve, ui.Offset.zero);
    path.close();
    
    return path;
  }

  /// Create smooth curve from points
  Path _createSmoothCurve(List<ui.Offset> points) {
    if (points.length < 2) {
      return Path();
    }
    
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    
    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
      return path;
    }
    
    // Use quadratic bezier for smoother curves
    for (int i = 1; i < points.length - 1; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      
      // Control point is midpoint between p0 and p2
      final controlX = (p0.dx + p2.dx) / 2;
      final controlY = (p0.dy + p2.dy) / 2;
      
      path.quadraticBezierTo(controlX, controlY, p1.dx, p1.dy);
    }
    
    // Add final segment
    path.lineTo(points.last.dx, points.last.dy);
    
    return path;
  }

  /// Get eye contour points from face
  List<ui.Offset>? _contourPoints(FaceContourType type) {
    final pts = face.contours[type]?.points;
    if (pts == null || pts.length < 3) return null;
    return pts.map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble())).toList();
  }

  /// Main professional eyeshadow painting function
  void _drawAccurateEyeshadow(
    Canvas canvas,
    FaceContourType eyeType,
    double intensity,
    Color eyeshadowColor,
  ) {
    final k = max(0.2, intensity); // Minimum 0.2 opacity so it doesn't vanish
    if (k < 0.01) return;
    
    // Get eye contour points
    final eyePoints = _contourPoints(eyeType);
    if (eyePoints == null || eyePoints.length < 6) return;
    
    // Get eye bounds for sizing
    final eyeBounds = DrawingUtils.boundsOf(eyePoints);
    final eyeWidth = eyeBounds.width;
    final eyeHeight = eyeBounds.height;
    
    // Skip if eye is too small
    if (eyeWidth < 5 || eyeHeight < 5) return;
    
    // Get upper lid curve
    final upperLid = _getUpperLidCurve(eyePoints);
    if (upperLid.length < 2) return;
    
    // Create accurate eyelid region
    final eyelidRegion = _createAccurateEyelidRegion(
      upperLid: upperLid,
      eyeBounds: eyeBounds,
      allEyePoints: eyePoints,
    );
    
    // Calculate tight clipping bounds
    final clipPadding = eyeWidth * 0.3;
    final clipRect = ui.Rect.fromLTRB(
      eyeBounds.left - clipPadding,
      eyeBounds.top - eyeHeight * 0.5,
      eyeBounds.right + clipPadding,
      eyeBounds.bottom + eyeHeight * 0.2,
    );
    
    // Save canvas state
    canvas.save();
    
    // 1. Clip to eye area
    canvas.clipRect(clipRect);
    
    // 2. Optional: Add debug outline to see region
    final debug = false; // Set to true to see the region outline
    if (debug) {
      final debugPaint = Paint()
        ..color = Colors.green.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawPath(eyelidRegion, debugPaint);
    }
    
    // 3. Create eye exclusion mask (prevents painting on eyeball)
    final eyePath = Path();
    if (eyePoints.length > 2) {
      eyePath.moveTo(eyePoints.first.dx, eyePoints.first.dy);
      for (int i = 1; i < eyePoints.length; i++) {
        eyePath.lineTo(eyePoints[i].dx, eyePoints[i].dy);
      }
      eyePath.close();
    }
    
    // Create region that excludes the eyeball
    final regionWithHole = Path.combine(
      PathOperation.difference,
      eyelidRegion,
      eyePath,
    );
    
    // --- PASS 1: Base gradient (vertical fade) ---
    final gradient = ui.Gradient.linear(
      ui.Offset(eyeBounds.center.dx, eyeBounds.top + eyeHeight * 0.2), // Start near lash line
      ui.Offset(eyeBounds.center.dx, eyeBounds.top - eyeHeight * 0.3), // End above eye
      [
        eyeshadowColor.withOpacity(0.7 * k),  // Strongest near lash line
        eyeshadowColor.withOpacity(0.4 * k),  // Medium intensity
        eyeshadowColor.withOpacity(0.15 * k), // Faded
        Colors.transparent,                    // Complete fade
      ],
      [0.0, 0.4, 0.7, 1.0],
    );
    
    final basePaint = Paint()
      ..shader = gradient
      ..blendMode = BlendMode.multiply
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(regionWithHole, basePaint);
    
    // --- PASS 2: SoftLight blend for natural look ---
    final softLightPaint = Paint()
      ..color = eyeshadowColor.withOpacity(0.25 * k)
      ..blendMode = BlendMode.softLight
      ..isAntiAlias = true
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6.0);
    
    canvas.drawPath(regionWithHole, softLightPaint);
    
    // --- PASS 3: Edge feathering ---
    final featherPaint = Paint()
      ..color = eyeshadowColor.withOpacity(0.3 * k)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(eyeHeight * 0.15, 4.0)
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.multiply
      ..isAntiAlias = true
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8.0);
    
    canvas.drawPath(regionWithHole, featherPaint);
    
    // --- PASS 4: Inner corner highlight (optional) ---
    final innerCornerPaint = Paint()
      ..shader = ui.Gradient.radial(
        ui.Offset(
          eyeType == FaceContourType.leftEye 
            ? eyeBounds.left + eyeWidth * 0.3
            : eyeBounds.right - eyeWidth * 0.3,
          eyeBounds.top + eyeHeight * 0.4,
        ),
        eyeWidth * 0.2,
        [
          Colors.white.withOpacity(0.15 * k),
          Colors.transparent,
        ],
        [0.0, 1.0],
      )
      ..blendMode = BlendMode.softLight
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10.0);
    
    canvas.drawPath(regionWithHole, innerCornerPaint);
    
    canvas.restore();
  }

  void paint(Canvas canvas, Size size) {
    final k = intensity.clamp(0.0, 1.0);
    if (k == 0) return;
    
    // Draw accurate eyeshadow for both eyes
    _drawAccurateEyeshadow(canvas, FaceContourType.leftEye, k, eyeshadowColor);
    _drawAccurateEyeshadow(canvas, FaceContourType.rightEye, k, eyeshadowColor);
  }
}