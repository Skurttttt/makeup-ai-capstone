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

  /// Pick stable upper-lid points:
  /// - Use the upper band of the eye contour
  /// - Sort by X
  /// - Smooth & downsample
  List<ui.Offset> _getUpperLidCurve(List<ui.Offset> eyePoints) {
    if (eyePoints.length < 8) return eyePoints;

    double minY = double.infinity, maxY = -double.infinity;
    for (final p in eyePoints) {
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }

    final upperThreshold = minY + (maxY - minY) * 0.45; // slightly wider than 0.40
    var upper = eyePoints.where((p) => p.dy <= upperThreshold).toList();

    if (upper.length < 3) {
      final avgY = (minY + maxY) / 2;
      upper = eyePoints.where((p) => p.dy <= avgY).toList();
    }

    upper.sort((a, b) => a.dx.compareTo(b.dx));
    upper = _smoothMovingAverage(upper, 2);

    // Downsample to ~7 points for stability
    final target = 7;
    if (upper.length <= target) return upper;

    final out = <ui.Offset>[];
    for (int i = 0; i < target; i++) {
      final t = i / (target - 1);
      final idx = (t * (upper.length - 1)).round();
      out.add(upper[idx]);
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
    // NOTE: "inner/outer" depends on left/right eye, but for axis direction it doesn't matter.
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

  Path _eyeClosedPath(List<ui.Offset> eyePoints) {
    final p = Path();
    p.moveTo(eyePoints.first.dx, eyePoints.first.dy);
    for (int i = 1; i < eyePoints.length; i++) {
      p.lineTo(eyePoints[i].dx, eyePoints[i].dy);
    }
    p.close();
    return p;
  }

  /// Creates eyelid region *oriented to the eye tilt*
  Path _createEyelidRegionOriented({
    required List<ui.Offset> upperLid,
    required List<ui.Offset> eyePoints,
    required ui.Rect eyeBounds,
    required ui.Offset axisDir,
    required ui.Offset normalUp,
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

    final eyeH = eyeBounds.height;

    // These are the key tuning knobs for “sits on lid”
    final lashLift = math.max(eyeH * 0.06, 2.0);  // small lift from lash line
    final creaseLift = math.max(eyeH * 0.55, 10.0); // lid height / crease area

    var lower = _shiftAlongNormal(upperLid, normalUp, lashLift);
    var upper = _shiftAlongNormal(upperLid, normalUp, creaseLift);

    // Taper the ends so it blends better in corners
    final taper = math.max(eyeBounds.width * 0.06, 2.0);
    lower = _taperEnds(lower, axisDir, taper);
    upper = _taperEnds(upper, axisDir, taper * 0.8);

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
    var normal = _perp(axisDir);

    // Make sure normal points "up" (negative y in screen coords)
    if (normal.dy > 0) normal = ui.Offset(-normal.dx, -normal.dy);

    // Region
    final region = _createEyelidRegionOriented(
      upperLid: upperLid,
      eyePoints: eyePoints,
      eyeBounds: eyeBounds,
      axisDir: axisDir,
      normalUp: normal,
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

      canvas.drawRect(clipRect, p..color = Colors.cyan.withOpacity(0.5));
      canvas.drawPath(region, p..color = Colors.green.withOpacity(0.8));
    }

    // Draw in a layer so blend/blur feels like skin (and not sticker paint)
    final layerPaint = Paint()..isAntiAlias = true;
    canvas.saveLayer(clipRect, layerPaint);

    // Gradient direction: along the normal (lash -> crease)
    final lashPoint = ui.Offset(
      eyeBounds.center.dx - normal.dx * (eyeH * 0.10),
      eyeBounds.center.dy - normal.dy * (eyeH * 0.10),
    );
    final creasePoint = ui.Offset(
      eyeBounds.center.dx + normal.dx * (eyeH * 0.85),
      eyeBounds.center.dy + normal.dy * (eyeH * 0.85),
    );

    // PASS 1: Base multiply gradient (gives “pigment in skin” feel)
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

    // PASS 4: Subtle center “diffusion” blob (prevents banding)
    final blobCenter = ui.Offset(
      eyeBounds.center.dx,
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
