// lib/eyebrow_painter.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class EyebrowPainter {
  final Face face;
  final Color browColor;

  /// User intensity (0..1) from your UI slider
  final double intensity;

  /// Brow thickness multiplier: 0.85 thin, 1.05 medium, 1.35 bold
  final double thickness;

  /// If true: adds subtle hair-like strokes (still very lightweight)
  final bool hairStrokes;

  /// Scene luminance (0..1) for adaptive blending in uneven lighting
  final double sceneLuminance;

  /// ✅ Fix for “floating brows”
  /// Positive moves DOWN (y+), negative moves UP (y-)
  /// Recommended: 0.010 to 0.020
  final double yOffsetFactor;

  /// Optional debug overlay
  final bool debugMode;

  /// ✅ Anti-jitter stabilization strength (EMA)
  /// 0.0 = no smoothing, 0.65–0.85 = good stabilization
  final double emaAlpha;

  /// ✅ How long to keep EMA cache keys (prevents memory growth)
  final Duration emaTtl;

  EyebrowPainter({
    required this.face,
    required this.browColor,
    required this.intensity,
    this.thickness = 1.0,
    this.hairStrokes = true,
    this.sceneLuminance = 0.50,
    this.yOffsetFactor = 0.015,
    this.debugMode = false,
    this.emaAlpha = 0.78,
    this.emaTtl = const Duration(seconds: 6),
  });

  // ----------------------------
  // EMA cache (static = shared)
  // ----------------------------
  static final Map<String, List<ui.Offset>> _emaCache = {};
  static final Map<String, DateTime> _emaTouched = {};

  String _emaKey(int? trackingId, bool isLeft) {
    // NOTE: identityHashCode(face) is in dart:core (no import needed)
    if (trackingId == null) {
      return 'NO_TRACK_${isLeft ? "L" : "R"}_${identityHashCode(face)}';
    }
    return 'TID_${trackingId}_${isLeft ? "L" : "R"}';
  }

  void _pruneEma() {
    final now = DateTime.now();
    final dead = <String>[];
    _emaTouched.forEach((k, t) {
      if (now.difference(t) > emaTtl) dead.add(k);
    });
    for (final k in dead) {
      _emaTouched.remove(k);
      _emaCache.remove(k);
    }
  }

  List<ui.Offset> _emaSmoothPoints({
    required String key,
    required List<ui.Offset> raw,
  }) {
    if (raw.isEmpty) return raw;

    final a = emaAlpha.clamp(0.0, 0.98);
    // If alpha is 0 => no smoothing
    if (a <= 0.0) return raw;

    final prev = _emaCache[key];

    // First time: seed cache with current raw points
    if (prev == null || prev.isEmpty) {
      _emaCache[key] = List<ui.Offset>.from(raw);
      _emaTouched[key] = DateTime.now();
      return raw;
    }

    // If ML returns different count, reset (avoid index mismatch artifacts)
    if (prev.length != raw.length) {
      _emaCache[key] = List<ui.Offset>.from(raw);
      _emaTouched[key] = DateTime.now();
      return raw;
    }

    final out = <ui.Offset>[];
    for (int i = 0; i < raw.length; i++) {
      final p = raw[i];
      final q = prev[i];
      out.add(ui.Offset(
        ui.lerpDouble(q.dx, p.dx, 1.0 - a)!,
        ui.lerpDouble(q.dy, p.dy, 1.0 - a)!,
      ));
    }

    _emaCache[key] = out;
    _emaTouched[key] = DateTime.now();
    return out;
  }

  void paint(Canvas canvas, Size size) {
    final k0 = intensity.clamp(0.0, 1.0);
    if (k0 <= 0.0) return;

    _pruneEma();

    // Get eyebrow contours (top). These exist when enableContours=true.
    final leftRaw = _contourOffsets(face.contours[FaceContourType.leftEyebrowTop]?.points);
    final rightRaw = _contourOffsets(face.contours[FaceContourType.rightEyebrowTop]?.points);

    if (leftRaw.length < 4 && rightRaw.length < 4) return;

    // ✅ EMA stabilization (prevents shimmering)
    final left = leftRaw.length >= 4
        ? _emaSmoothPoints(
            key: _emaKey(face.trackingId, true),
            raw: leftRaw,
          )
        : leftRaw;

    final right = rightRaw.length >= 4
        ? _emaSmoothPoints(
            key: _emaKey(face.trackingId, false),
            raw: rightRaw,
          )
        : rightRaw;

    final box = face.boundingBox;
    final faceW = max(1.0, box.width);
    final faceH = max(1.0, box.height);

    // Lighting adaptation (dark -> softer edges, slightly reduced contrast)
    final l = sceneLuminance.clamp(0.0, 1.0);
    final darkT = ((0.35 - l) / 0.35).clamp(0.0, 1.0);
    final brightT = ((l - 0.78) / 0.22).clamp(0.0, 1.0);

    // Brow stroke width depends on face size (normalized)
    final baseStroke = (faceW * 0.010).clamp(1.2, 4.0);
    final strokeW = baseStroke * thickness;

    // Blur: darker scene = increase blur to hide edges
    final blur = (faceW * 0.010).clamp(1.2, 5.0) *
        ui.lerpDouble(1.0, 1.25, darkT)! *
        ui.lerpDouble(1.0, 0.90, brightT)!;

    // Opacity: keep natural. In dark, reduce overlay a bit to avoid harsh borders.
    final opacity = (0.22 + 0.35 * k0) *
        ui.lerpDouble(1.0, 0.86, darkT)! *
        ui.lerpDouble(1.0, 0.92, brightT)!;

    // Apply slight brown realism: desaturate a bit
    final base = _softenColor(browColor, darkT: darkT);

    if (left.length >= 4) {
      _drawBrow(
        canvas: canvas,
        pts: left,
        box: box,
        faceW: faceW,
        faceH: faceH,
        strokeW: strokeW,
        blur: blur,
        color: base,
        opacity: opacity,
        isLeft: true,
        darkT: darkT,
      );
    }

    if (right.length >= 4) {
      _drawBrow(
        canvas: canvas,
        pts: right,
        box: box,
        faceW: faceW,
        faceH: faceH,
        strokeW: strokeW,
        blur: blur,
        color: base,
        opacity: opacity,
        isLeft: false,
        darkT: darkT,
      );
    }
  }

  // ----------------------------
  // Brow Rendering
  // ----------------------------
  void _drawBrow({
    required Canvas canvas,
    required List<ui.Offset> pts,
    required Rect box,
    required double faceW,
    required double faceH,
    required double strokeW,
    required double blur,
    required Color color,
    required double opacity,
    required bool isLeft,
    required double darkT,
  }) {
    // ✅ Fix “floating”: move brow DOWN a bit
    final dy = faceH * yOffsetFactor;
    final shifted = pts.map((p) => ui.Offset(p.dx, p.dy + dy)).toList();

    // Smooth + resample for clean curves
    final smooth = _resample(shifted, 14);
    final path = _buildSmoothOpenPath(smooth);

    // Layer bounds for texture-friendly blending
    final bounds = path.getBounds().inflate(max(6.0, strokeW * 6));

    canvas.saveLayer(bounds, Paint());

    // PASS 1: base brow stroke (softLight preserves skin texture better than normal)
    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withOpacity(opacity)
        ..blendMode = BlendMode.softLight
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur),
    );

    // PASS 2: subtle deepen for definition (reduce in dark scenes)
    final deepen = ui.lerpDouble(1.0, 0.55, darkT)!;
    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW * 0.86
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withOpacity(opacity * 0.50 * deepen)
        ..blendMode = BlendMode.multiply
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur * 0.75),
    );

    // PASS 3 (optional): micro hair strokes (stable seed)
    if (hairStrokes) {
      _drawHairStrokes(
        canvas: canvas,
        curve: smooth,
        color: color,
        opacity: opacity,
        strokeW: strokeW,
        blur: blur,
        isLeft: isLeft,
        darkT: darkT,
      );
    }

    // Debug overlay
    if (debugMode) {
      final p = Paint()
        ..color = Colors.green.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawPath(path, p);

      for (final pt in smooth) {
        canvas.drawCircle(pt, 2.0, Paint()..color = Colors.red);
      }
    }

    canvas.restore();
  }

  void _drawHairStrokes({
    required Canvas canvas,
    required List<ui.Offset> curve,
    required Color color,
    required double opacity,
    required double strokeW,
    required double blur,
    required bool isLeft,
    required double darkT,
  }) {
    if (curve.length < 6) return;

    // ✅ Deterministic seed (prevents flicker/shimmer across frames)
    final seed = (face.trackingId ?? 7) * 1000 + (isLeft ? 13 : 29);
    final rng = Random(seed);

    final step = 2;

    // Reduce hair strokes in dark scenes (so they don’t reveal edges)
    final hairPass = ui.lerpDouble(1.0, 0.65, darkT)!;

    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(opacity * 0.35 * hairPass)
      ..blendMode = BlendMode.overlay
      ..strokeWidth = max(0.8, strokeW * 0.35)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur * 0.40);

    for (int i = 1; i < curve.length - 2; i += step) {
      final p0 = curve[i - 1];
      final p1 = curve[i];
      final p2 = curve[i + 1];

      // Tangent direction
      final tx = (p2.dx - p0.dx);
      final ty = (p2.dy - p0.dy);
      final len = max(1e-6, sqrt(tx * tx + ty * ty));

      // Normal (perpendicular) direction
      final nx = -ty / len;
      final ny = tx / len;

      // Hair stroke length
      final baseLen = 5.0 + rng.nextDouble() * 6.0;
      final jitter = (rng.nextDouble() - 0.5) * 0.8;

      // Slight direction bias: hair grows slightly upward + outward
      final outward = isLeft ? -1.0 : 1.0;
      final sx = p1.dx + nx * jitter + outward * 0.25;
      final sy = p1.dy + ny * jitter - 0.30;

      final ex = sx + nx * baseLen;
      final ey = sy + ny * baseLen;

      // Not every point gets a stroke (keep it subtle)
      if (rng.nextDouble() < 0.65) {
        canvas.drawLine(ui.Offset(sx, sy), ui.Offset(ex, ey), paint);
      }
    }
  }

  // ----------------------------
  // Helpers
  // ----------------------------
  List<ui.Offset> _contourOffsets(List<Point<int>>? pts) {
    if (pts == null || pts.isEmpty) return const [];
    return pts.map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble())).toList();
  }

  List<ui.Offset> _resample(List<ui.Offset> pts, int n) {
    if (pts.isEmpty) return pts;
    if (pts.length <= n) return pts;

    final out = <ui.Offset>[];
    final step = (pts.length - 1) / (n - 1);

    for (int i = 0; i < n; i++) {
      final idx = i * step;
      final a = idx.floor();
      final b = min(pts.length - 1, a + 1);
      final t = idx - a;

      final pa = pts[a];
      final pb = pts[b];

      out.add(ui.Offset(
        ui.lerpDouble(pa.dx, pb.dx, t)!,
        ui.lerpDouble(pa.dy, pb.dy, t)!,
      ));
    }
    return out;
  }

  Path _buildSmoothOpenPath(List<ui.Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (pts.length < 3) {
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      return path;
    }

    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final mid = ui.Offset((p0.dx + p1.dx) * 0.5, (p0.dy + p1.dy) * 0.5);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  Color _softenColor(Color c, {required double darkT}) {
    final hsl = HSLColor.fromColor(c);
    final s = (hsl.saturation * ui.lerpDouble(0.92, 0.82, darkT)!).clamp(0.0, 1.0);
    final l = (hsl.lightness * ui.lerpDouble(1.00, 0.92, darkT)!).clamp(0.0, 1.0);
    return hsl.withSaturation(s).withLightness(l).toColor();
  }
}
