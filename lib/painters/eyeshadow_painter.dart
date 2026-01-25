import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../utils.dart';
import '../look_engine.dart';

class EyeshadowPainter {
  final Face face;
  final Color eyeshadowColor;
  final double intensity;

  /// Turn on when calibrating eyelid fit
  final bool debug;

  EyeshadowPainter({
    required this.face,
    required this.eyeshadowColor,
    required this.intensity,
    this.debug = false,
  });

  // ----------------- BASIC HELPERS -----------------

  List<ui.Offset>? _contourPoints(FaceContourType type) {
    final pts = face.contours[type]?.points;
    if (pts == null || pts.length < 3) return null;
    return pts.map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble())).toList();
  }

  List<ui.Offset>? _eyebrowTop(FaceContourType type) {
    final pts = face.contours[type]?.points;
    if (pts == null || pts.length < 3) return null;
    return pts
        .map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble()))
        .toList();
  }

  ui.Offset _normalize(ui.Offset v) {
    final len = math.sqrt(v.dx * v.dx + v.dy * v.dy);
    if (len < 1e-6) return const ui.Offset(0, -1);
    return ui.Offset(v.dx / len, v.dy / len);
  }

  ui.Offset _perp(ui.Offset v) => ui.Offset(-v.dy, v.dx);

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  ui.Offset _lerpOffset(ui.Offset a, ui.Offset b, double t) =>
      ui.Offset(_lerp(a.dx, b.dx, t), _lerp(a.dy, b.dy, t));

  List<ui.Offset> _smoothMovingAverage(List<ui.Offset> pts, int window) {
    if (pts.length <= 2 || window <= 0) return pts;
    final out = <ui.Offset>[];
    for (int i = 0; i < pts.length; i++) {
      final start = math.max(0, i - window);
      final end = math.min(pts.length - 1, i + window);
      double sx = 0, sy = 0;
      int c = 0;
      for (int j = start; j <= end; j++) {
        sx += pts[j].dx;
        sy += pts[j].dy;
        c++;
      }
      out.add(ui.Offset(sx / c, sy / c));
    }
    return out;
  }

  // ----------------- EYE GEOMETRY -----------------

  /// Industry standard approach for full coverage:
  /// X-binning across the whole eye width + forced corner lid points
  List<ui.Offset> _getUpperLidCurve(List<ui.Offset> eyePoints) {
    final b = DrawingUtils.boundsOf(eyePoints);
    final width = b.width;
    if (width < 4) return eyePoints;

    // Adaptive bins (denser = better coverage)
    final bins = math.max(10, math.min(18, (width / 5).round()));
    final binW = width / bins;

    // Helper: pick top-most point inside x-range
    ui.Offset? pickTop(double x0, double x1) {
      ui.Offset? best;
      for (final p in eyePoints) {
        if (p.dx >= x0 && p.dx <= x1) {
          if (best == null || p.dy < best.dy) best = p;
        }
      }
      return best;
    }

    // Force lid corners (most important fix)
    final edgeBand = width * 0.18;
    final leftCorner = pickTop(b.left, b.left + edgeBand);
    final rightCorner = pickTop(b.right - edgeBand, b.right);

    // Bin picks across width
    final picked = <ui.Offset>[];
    for (int i = 0; i < bins; i++) {
      final x0 = b.left + i * binW;
      final x1 = x0 + binW;
      final best = pickTop(x0, x1);
      if (best != null) picked.add(best);
    }

    // Merge + sort by X
    final all = <ui.Offset>[
      if (leftCorner != null) leftCorner,
      ...picked,
      if (rightCorner != null) rightCorner,
    ]..sort((a, b) => a.dx.compareTo(b.dx));

    // Smooth for stability
    final smoothed = _smoothMovingAverage(all, 2);

    // Resample to stable point count for consistent region
    const target = 11;
    if (smoothed.length <= target) return smoothed;

    final out = <ui.Offset>[];
    for (int i = 0; i < target; i++) {
      final t = i / (target - 1);
      final idx = (t * (smoothed.length - 1)).round();
      out.add(smoothed[idx]);
    }
    return out;
  }

  /// Get eye corners using minX/maxX points (works well for MLKit contours)
  (ui.Offset inner, ui.Offset outer) _eyeCorners(List<ui.Offset> eyePoints) {
    ui.Offset minX = eyePoints.first;
    ui.Offset maxX = eyePoints.first;
    for (final p in eyePoints) {
      if (p.dx < minX.dx) minX = p;
      if (p.dx > maxX.dx) maxX = p;
    }
    return (minX, maxX);
  }

  /// Build a smooth Catmull-Rom-like curve through points
  Path _smoothPath(List<ui.Offset> pts, {bool closed = false}) {
    final path = Path();
    if (pts.isEmpty) return path;
    if (pts.length == 1) {
      path.addOval(Rect.fromCircle(center: pts.first, radius: 1));
      return path;
    }

    path.moveTo(pts.first.dx, pts.first.dy);

    // Quadratic smoothing (stable and fast)
    for (int i = 1; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final mid = ui.Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);

    if (closed) path.close();
    return path;
  }

  List<ui.Offset> _shiftAlongNormal(List<ui.Offset> pts, ui.Offset normal, double dist) {
    return pts.map((p) => ui.Offset(p.dx + normal.dx * dist, p.dy + normal.dy * dist)).toList();
  }

  List<ui.Offset> _taperEnds(List<ui.Offset> pts, ui.Offset axisDir, double taperDist) {
    if (pts.length < 3) return pts;

    final first = pts.first;
    final last = pts.last;

    // Pull the first and last slightly inward along axis to avoid "wingy blocks"
    final inFirst = ui.Offset(first.dx + axisDir.dx * taperDist, first.dy + axisDir.dy * taperDist);
    final inLast = ui.Offset(last.dx - axisDir.dx * taperDist, last.dy - axisDir.dy * taperDist);

    final out = List<ui.Offset>.from(pts);
    out[0] = inFirst;
    out[out.length - 1] = inLast;
    return out;
  }

  /// Fix the "paint on the eye" issue properly (robust eye-hole path)
  Path _eyeClosedPath(List<ui.Offset> eyePoints) {
    // Sort points around centroid to avoid self-intersecting polygons
    double cx = 0, cy = 0;
    for (final p in eyePoints) {
      cx += p.dx;
      cy += p.dy;
    }
    cx /= eyePoints.length;
    cy /= eyePoints.length;

    final sorted = List<ui.Offset>.from(eyePoints)
      ..sort((a, b) {
        final aa = math.atan2(a.dy - cy, a.dx - cx);
        final bb = math.atan2(b.dy - cy, b.dx - cx);
        return aa.compareTo(bb);
      });

    final p = Path()..moveTo(sorted.first.dx, sorted.first.dy);
    for (int i = 1; i < sorted.length; i++) {
      p.lineTo(sorted[i].dx, sorted[i].dy);
    }
    p.close();
    return p;
  }

  /// STEP 1A: Update function signature
  /// Creates eyelid region *oriented to the eye tilt*
  Path _createEyelidRegionOriented({
    required List<ui.Offset> upperLid,
    required List<ui.Offset> eyePoints,
    required ui.Rect eyeBounds,
    required ui.Offset axisDir,
    required ui.Offset normalUp,
    required double maxCreaseLift, // ✅ NEW
  }) {
    if (upperLid.length < 3) {
      // fallback: simple region
      final h = eyeBounds.height;
      final w = eyeBounds.width;

      final top = eyeBounds.top;
      final left = eyeBounds.left;
      final right = eyeBounds.right;
      final cx = eyeBounds.center.dx;

      return Path()
        ..moveTo(left, top)
        ..quadraticBezierTo(cx, top - h * 0.35, right, top)
        ..lineTo(right, top + h * 0.25)
        ..quadraticBezierTo(cx, top + h * 0.45, left, top + h * 0.25)
        ..close();
    }

    // STEP 4 — Use maxCreaseLift inside _createEyelidRegionOriented
    final eyeH = eyeBounds.height;

    // keep close to lash line
    final lashLift = math.max(eyeH * 0.02, 1.2);

    // ✅ brow-aware crease height
    final creaseLift = math.max(maxCreaseLift, eyeH * 0.70);

    var lower = _shiftAlongNormal(upperLid, normalUp, lashLift);
    var upper = _shiftAlongNormal(upperLid, normalUp, creaseLift);

    // Keep taper disabled for now
    // final taper = math.max(eyeBounds.width * 0.06, 2.0);
    // lower = _taperEnds(lower, axisDir, taper);
    // upper = _taperEnds(upper, axisDir, taper * 0.8);

    // Smooth more to remove jitter
    lower = _smoothMovingAverage(lower, 2);
    upper = _smoothMovingAverage(upper, 2);

    final lowerCurve = _smoothPath(lower, closed: false);
    final upperCurve = _smoothPath(upper.reversed.toList(), closed: false);

    final region = Path()
      ..addPath(lowerCurve, ui.Offset.zero)
      ..lineTo(upper.first.dx, upper.first.dy)
      ..addPath(upperCurve, ui.Offset.zero)
      ..close();

    // Subtract eyeball area so shadow never goes inside eye opening
    final eyePath = _eyeClosedPath(eyePoints);

    return Path.combine(PathOperation.difference, region, eyePath);
  }

  // ----------------- PAINT -----------------

  void _drawAccurateEyeshadow(
    Canvas canvas,
    FaceContourType eyeType,
    double k,
    Color color,
  ) {
    if (k < 0.01) return;

    final eyePoints = _contourPoints(eyeType);
    if (eyePoints == null || eyePoints.length < 6) return;

    final eyeBounds = DrawingUtils.boundsOf(eyePoints);
    final eyeW = eyeBounds.width;
    final eyeH = eyeBounds.height;

    if (eyeW < 6 || eyeH < 6) return;

    final upperLid = _getUpperLidCurve(eyePoints);
    if (upperLid.length < 3) return;

    // Eye axis & normal (tilt-aware)
    final (c0, c1) = _eyeCorners(eyePoints);
    var axisDir = _normalize(ui.Offset(c1.dx - c0.dx, c1.dy - c0.dy));
    
    // STEP 2 — Make the normal ALWAYS point toward the eyebrow
    var normal = _perp(axisDir);

    // ✅ Brow-aware normal orientation (industry-standard stability)
    final browPoints = eyeType == FaceContourType.leftEye
        ? _eyebrowTop(FaceContourType.leftEyebrowTop)
        : _eyebrowTop(FaceContourType.rightEyebrowTop);

    final eyeCenter = eyeBounds.center;

    // If we have brow points, use them to force normal direction
    if (browPoints != null && browPoints.isNotEmpty) {
      // brow "closest to eyelid" = max Y (lower brow edge)
      final browY = browPoints.map((p) => p.dy).reduce(math.max);
      final browX = browPoints.map((p) => p.dx).reduce((a, b) => a + b) / browPoints.length;

      final browPoint = ui.Offset(browX, browY);
      final toBrow = _normalize(ui.Offset(browPoint.dx - eyeCenter.dx, browPoint.dy - eyeCenter.dy));

      // If normal points away from brow, flip it
      final dot = normal.dx * toBrow.dx + normal.dy * toBrow.dy;
      if (dot < 0) normal = ui.Offset(-normal.dx, -normal.dy);
    } else {
      // fallback: keep normal going upward on screen
      if (normal.dy > 0) normal = ui.Offset(-normal.dx, -normal.dy);
    }

    // ✅ This guarantees "normalUp" is actually toward brow bone, not randomly up/down.

    // STEP 3 — Compute maxCreaseLift correctly (and pass it)
    double maxCreaseLift;
    if (browPoints != null && browPoints.isNotEmpty) {
      // closest brow edge to eyelid = maxY
      final browY = browPoints.map((p) => p.dy).reduce(math.max);

      // distance from eyelid top to brow underside
      maxCreaseLift = (browY - eyeBounds.top) * 0.78;

      // safety clamp
      maxCreaseLift = maxCreaseLift.clamp(eyeH * 0.55, eyeH * 1.10);
    } else {
      maxCreaseLift = (eyeH * 0.95);
    }

    // Region
    final region = _createEyelidRegionOriented(
      upperLid: upperLid,
      eyePoints: eyePoints,
      eyeBounds: eyeBounds,
      axisDir: axisDir,
      normalUp: normal,
      maxCreaseLift: maxCreaseLift, // ✅ NEW
    );

    // Tight clip (bigger than bounds to allow blur)
    final padX = eyeW * 0.40;
    final padYTop = eyeH * 0.90;
    final padYBot = eyeH * 0.25;

    final clipRect = ui.Rect.fromLTRB(
      eyeBounds.left - padX,
      eyeBounds.top - padYTop,
      eyeBounds.right + padX,
      eyeBounds.bottom + padYBot,
    );

    canvas.save();
    canvas.clipRect(clipRect);

    // Debug outlines
    if (debug) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..isAntiAlias = true;

      // Draw eyebrow points if available
      if (browPoints != null) {
        for (final point in browPoints) {
          canvas.drawCircle(point, 1.5, p..color = Colors.red);
        }
      }
      
      canvas.drawRect(clipRect, p..color = Colors.cyan.withOpacity(0.5));
      canvas.drawPath(region, p..color = Colors.green.withOpacity(0.8));
      
      // Draw normal direction for debugging
      final normalEnd = ui.Offset(
        eyeCenter.dx + normal.dx * 20,
        eyeCenter.dy + normal.dy * 20,
      );
      canvas.drawLine(eyeCenter, normalEnd, p..color = Colors.orange..strokeWidth = 2.0);
    }

    // Draw in a layer so blend/blur feels like skin (and not sticker paint)
    final layerPaint = Paint()..isAntiAlias = true;
    canvas.saveLayer(clipRect, layerPaint);

    // Gradient direction: along the normal (lash -> crease)
    final lashPoint = ui.Offset(
      eyeCenter.dx - normal.dx * (eyeH * 0.10),
      eyeCenter.dy - normal.dy * (eyeH * 0.10),
    );
    final creasePoint = ui.Offset(
      eyeCenter.dx + normal.dx * (eyeH * 0.85),
      eyeCenter.dy + normal.dy * (eyeH * 0.85),
    );

    // PASS 1: Base multiply gradient (gives "pigment in skin" feel)
    final baseShader = ui.Gradient.linear(
      lashPoint,
      creasePoint,
      [
        color.withOpacity(0.70 * k),
        color.withOpacity(0.45 * k),
        color.withOpacity(0.18 * k),
        Colors.transparent,
      ],
      const [0.0, 0.45, 0.75, 1.0],
    );

    final basePaint = Paint()
      ..shader = baseShader
      ..blendMode = BlendMode.multiply
      ..isAntiAlias = true;

    canvas.drawPath(region, basePaint);

    // PASS 2: SoftLight wash (warmer, more natural)
    final softLight = Paint()
      ..color = color.withOpacity(0.20 * k)
      ..blendMode = BlendMode.softLight
      ..isAntiAlias = true;

    canvas.drawPath(region, softLight);

    // PASS 3: Feather edge (blurred stroke around region)
    final featherW = math.max(eyeH * 0.18, 4.0);
    final feather = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = featherW
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.22 * k)
      ..blendMode = BlendMode.multiply
      ..isAntiAlias = true
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, eyeH * 0.35);

    canvas.drawPath(region, feather);

    // PASS 4: Subtle center "diffusion" blob (prevents banding)
    final blobCenter = ui.Offset(
      eyeCenter.dx,
      eyeBounds.top - eyeH * 0.10,
    );

    final diffusion = Paint()
      ..shader = ui.Gradient.radial(
        blobCenter,
        eyeW * 0.55,
        [
          color.withOpacity(0.16 * k),
          Colors.transparent,
        ],
        const [0.0, 1.0],
      )
      ..blendMode = BlendMode.softLight
      ..isAntiAlias = true
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, eyeH * 0.40);

    canvas.drawPath(region, diffusion);

    // optional tiny inner corner lift (very subtle)
    final innerCorner = (eyeType == FaceContourType.leftEye)
        ? ui.Offset(eyeBounds.left + eyeW * 0.28, eyeBounds.top + eyeH * 0.25)
        : ui.Offset(eyeBounds.right - eyeW * 0.28, eyeBounds.top + eyeH * 0.25);

    final innerGlow = Paint()
      ..shader = ui.Gradient.radial(
        innerCorner,
        eyeW * 0.22,
        [
          Colors.white.withOpacity(0.10 * k),
          Colors.transparent,
        ],
        const [0.0, 1.0],
      )
      ..blendMode = BlendMode.softLight
      ..isAntiAlias = true
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, eyeH * 0.55);

    canvas.drawPath(region, innerGlow);

    canvas.restore(); // layer
    canvas.restore(); // clip
  }

  void paint(Canvas canvas, Size size) {
    final k = intensity.clamp(0.0, 1.0);
    if (k <= 0) return;

    _drawAccurateEyeshadow(canvas, FaceContourType.leftEye, k, eyeshadowColor);
    _drawAccurateEyeshadow(canvas, FaceContourType.rightEye, k, eyeshadowColor);
  }
}