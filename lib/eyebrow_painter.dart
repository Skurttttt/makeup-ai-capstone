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

  // ============================
  // ✅ EMA SMOOTHING (Anti-jitter)
  // ============================

  /// EMA alpha:
  /// - Lower = more stable but more lag
  /// - Higher = more responsive but less stable
  ///
  /// Recommended: 0.25–0.45
  final double emaAlpha;

  EyebrowPainter({
    required this.face,
    required this.browColor,
    required this.intensity,
    this.thickness = 1.0,
    this.hairStrokes = true,
    this.sceneLuminance = 0.50,
    this.yOffsetFactor = 0.015,
    this.debugMode = false,
    this.emaAlpha = 0.35,
  });

  // Static cache across frames (per face trackingId + side)
  static final Map<String, _EmaState> _emaCache = {};

  // For cleanup
  static int _frameCounter = 0;
  static const int _maxIdleFrames = 60; // ~1 sec at 60fps (tweak if needed)
  static const int _maxCacheEntries = 12;

  void paint(Canvas canvas, Size size) {
    final k0 = intensity.clamp(0.0, 1.0);
    if (k0 <= 0.0) return;

    // Get eyebrow contours (top). These exist when enableContours=true.
    final leftRaw = _contourOffsets(face.contours[FaceContourType.leftEyebrowTop]?.points);
    final rightRaw = _contourOffsets(face.contours[FaceContourType.rightEyebrowTop]?.points);

    if (leftRaw.length < 4 && rightRaw.length < 4) return;

    _frameCounter++;
    _cleanupEmaCacheIfNeeded();

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

    // ✅ EMA smoothing keys (needs trackingId)
    final tid = face.trackingId;
    final leftPts = _emaSmoothIfPossible(
      raw: leftRaw,
      key: _emaKey(tid, 'L'),
      alpha: emaAlpha,
    );
    final rightPts = _emaSmoothIfPossible(
      raw: rightRaw,
      key: _emaKey(tid, 'R'),
      alpha: emaAlpha,
    );

    if (leftPts.length >= 4) {
      _drawBrow(
        canvas: canvas,
        pts: leftPts,
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

    if (rightPts.length >= 4) {
      _drawBrow(
        canvas: canvas,
        pts: rightPts,
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
  // ✅ EMA smoothing logic
  // ----------------------------

  String _emaKey(int? trackingId, String side) {
    // If trackingId is null, smoothing becomes unreliable (different face objects),
    // so we disable smoothing by returning a unique "no-track" key.
    if (trackingId == null) return 'NO_TRACK_$side_${identityHashCode(face)}';
    return 'T$trackingId-$side';
  }

  List<ui.Offset> _emaSmoothIfPossible({
    required List<ui.Offset> raw,
    required String key,
    required double alpha,
  }) {
    if (raw.isEmpty) return raw;

    final a = alpha.clamp(0.05, 0.85);

    final prev = _emaCache[key];
    if (prev == null || prev.points.length != raw.length) {
      _emaCache[key] = _EmaState(
        points: List<ui.Offset>.from(raw),
        lastSeenFrame: _frameCounter,
      );
      return raw;
    }

    final smoothed = <ui.Offset>[];
    for (int i = 0; i < raw.length; i++) {
      final p = prev.points[i];
      final r = raw[i];

      // EMA: new = prev*(1-a) + raw*a
      final x = ui.lerpDouble(p.dx, r.dx, a)!;
      final y = ui.lerpDouble(p.dy, r.dy, a)!;
      smoothed.add(ui.Offset(x, y));
    }

    prev.points = smoothed;
    prev.lastSeenFrame = _frameCounter;

    return smoothed;
  }

  void _cleanupEmaCacheIfNeeded() {
    if (_emaCache.isEmpty) return;

    // 1) Remove old entries that haven't been used in a while
    final toRemove = <String>[];
    _emaCache.forEach((k, v) {
      if ((_frameCounter - v.lastSeenFrame) > _maxIdleFrames) toRemove.add(k);
    });
    for (final k in toRemove) {
      _emaCache.remove(k);
    }

    // 2) Hard cap to prevent runaway growth (rare, but safe)
    if (_emaCache.length > _maxCacheEntries) {
      // remove oldest
      final entries = _emaCache.entries.toList()
        ..sort((a, b) => a.value.lastSeenFrame.compareTo(b.value.lastSeenFrame));
      final extra = _emaCache.length - _maxCacheEntries;
      for (int i = 0; i < extra; i++) {
        _emaCache.remove(entries[i].key);
      }
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

    // PASS 3 (optional): micro hair strokes
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

    // ✅ IMPORTANT:
    // Use deterministic RNG so hair placement is stable frame-to-frame.
    // If you randomize every frame, smoothing won't fully fix shimmer.
    //
    // Use trackingId if available, else fallback.
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

class _EmaState {
  List<ui.Offset> points;
  int lastSeenFrame;

  _EmaState({
    required this.points,
    required this.lastSeenFrame,
  });
}
