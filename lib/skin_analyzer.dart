import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum SkinTone { light, medium, tan, deep }
enum Undertone { warm, cool, neutral }

class SkinAnalysisResult {
  final SkinTone tone;
  final Undertone undertone;

  final int avgR;
  final int avgG;
  final int avgB;

  /// 0.0–1.0 overall sampling confidence
  final double confidence;

  const SkinAnalysisResult({
    required this.tone,
    required this.undertone,
    required this.avgR,
    required this.avgG,
    required this.avgB,
    required this.confidence,
  });
}

enum _Region { leftCheek, rightCheek, forehead }

class _SampleResult {
  final int r;
  final int g;
  final int b;
  final int used;
  final int total;

  const _SampleResult({
    required this.r,
    required this.g,
    required this.b,
    required this.used,
    required this.total,
  });

  double get confidence => total == 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
}

class _Polygon {
  final List<ui.Offset> pts;
  final ui.Rect bounds;
  const _Polygon(this.pts, this.bounds);
}

class SkinAnalyzer {
  /// Multi-region skin analysis with contour exclusion:
  /// - Samples left cheek + right cheek + forehead
  /// - Avoids pixels inside eyes/lips/eyebrows polygons (makeup/hair)
  /// - Weighted RGB average by used pixels
  /// - Undertone vote weighted by region confidence
  static Future<SkinAnalysisResult> analyze(ui.Image image, Face face) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      return const SkinAnalysisResult(
        tone: SkinTone.medium,
        undertone: Undertone.neutral,
        avgR: 128,
        avgG: 110,
        avgB: 100,
        confidence: 0.0,
      );
    }

    final bytes = byteData.buffer.asUint8List();
    final w = image.width;
    final h = image.height;
    final box = face.boundingBox;

    // Build exclusion polygons once (eyes, lips, eyebrows)
    final exclusions = _buildExclusionPolygons(face);

    final rectLeft = _rectForRegion(_Region.leftCheek, box, w, h);
    final rectRight = _rectForRegion(_Region.rightCheek, box, w, h);
    final rectForehead = _rectForRegion(_Region.forehead, box, w, h);

    final sLeft = _sampleRect(bytes, w, h, rectLeft, exclusions);
    final sRight = _sampleRect(bytes, w, h, rectRight, exclusions);
    final sForehead = _sampleRect(bytes, w, h, rectForehead, exclusions);

    final weighted = _weightedAverage([sLeft, sRight, sForehead]);

    final avgR = weighted.$1;
    final avgG = weighted.$2;
    final avgB = weighted.$3;

    final overallConf = _overallConfidence([sLeft, sRight, sForehead]);

    final lum = _luminance(avgR, avgG, avgB);
    final tone = _toneFromLuminance(lum);

    final undertone = _voteUndertone([
      _regionVote(sLeft),
      _regionVote(sRight),
      _regionVote(sForehead),
    ]);

    return SkinAnalysisResult(
      tone: tone,
      undertone: undertone,
      avgR: avgR,
      avgG: avgG,
      avgB: avgB,
      confidence: overallConf,
    );
  }

  // ---------- Exclusion polygons (eyes/lips/eyebrows) ----------

  static List<_Polygon> _buildExclusionPolygons(Face face) {
    final polys = <_Polygon>[];

    void addContour(FaceContourType type) {
      final pts = face.contours[type]?.points;
      if (pts == null || pts.length < 3) return;

      final offsets = pts
          .map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble()))
          .toList(growable: false);

      polys.add(_Polygon(offsets, _boundsOf(offsets)));
    }

    // Eyes
    addContour(FaceContourType.leftEye);
    addContour(FaceContourType.rightEye);

    // Lips (these four cover most lip area)
    addContour(FaceContourType.upperLipTop);
    addContour(FaceContourType.upperLipBottom);
    addContour(FaceContourType.lowerLipTop);
    addContour(FaceContourType.lowerLipBottom);

    // Eyebrows (often hair pixels; safer to exclude)
    addContour(FaceContourType.leftEyebrowTop);
    addContour(FaceContourType.leftEyebrowBottom);
    addContour(FaceContourType.rightEyebrowTop);
    addContour(FaceContourType.rightEyebrowBottom);

    return polys;
  }

  static ui.Rect _boundsOf(List<ui.Offset> pts) {
    double minX = pts.first.dx, maxX = pts.first.dx;
    double minY = pts.first.dy, maxY = pts.first.dy;

    for (final p in pts.skip(1)) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return ui.Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  static bool _isInsideAnyExclusion(double x, double y, List<_Polygon> polys) {
    final p = ui.Offset(x, y);

    for (final poly in polys) {
      // quick bounding box check first (fast)
      if (!poly.bounds.contains(p)) continue;
      // precise polygon check
      if (_pointInPolygon(p, poly.pts)) return true;
    }
    return false;
  }

  /// Ray-casting point-in-polygon
  static bool _pointInPolygon(ui.Offset p, List<ui.Offset> poly) {
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final xi = poly[i].dx, yi = poly[i].dy;
      final xj = poly[j].dx, yj = poly[j].dy;

      final intersects = ((yi > p.dy) != (yj > p.dy)) &&
          (p.dx < (xj - xi) * (p.dy - yi) / ((yj - yi) == 0 ? 1e-9 : (yj - yi)) + xi);

      if (intersects) inside = !inside;
    }
    return inside;
  }

  // ---------- Core computations ----------

  static (int, int, int) _weightedAverage(List<_SampleResult> samples) {
    int wSum = 0;
    int rSum = 0, gSum = 0, bSum = 0;

    for (final s in samples) {
      final weight = max(0, s.used);
      wSum += weight;
      rSum += s.r * weight;
      gSum += s.g * weight;
      bSum += s.b * weight;
    }

    if (wSum <= 0) return (128, 110, 100);

    return (
      (rSum / wSum).round(),
      (gSum / wSum).round(),
      (bSum / wSum).round(),
    );
  }

  static double _overallConfidence(List<_SampleResult> samples) {
    int totalAll = 0;
    int usedAll = 0;

    for (final s in samples) {
      totalAll += s.total;
      usedAll += s.used;
    }

    if (totalAll <= 0) return 0.0;
    return (usedAll / totalAll).clamp(0.0, 1.0);
  }

  static double _luminance(int r, int g, int b) {
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  static SkinTone _toneFromLuminance(double lum) {
    if (lum >= 185) return SkinTone.light;
    if (lum >= 150) return SkinTone.medium;
    if (lum >= 115) return SkinTone.tan;
    return SkinTone.deep;
  }

  static Undertone _undertoneFromRGB(int r, int g, int b) {
    final rb = r - b;
    final gb = g - b;

    if (rb > 18 && gb > 10) return Undertone.warm;
    if (b - r > 10 || b - g > 10) return Undertone.cool;

    final rg = r - g;
    if (rg > 15 && b < g) return Undertone.warm;

    return Undertone.neutral;
  }

  // ---------- Undertone voting ----------

  static (Undertone tone, double weight) _regionVote(_SampleResult s) {
    final weight = s.confidence;
    final u = _undertoneFromRGB(s.r, s.g, s.b);
    return (u, weight);
  }

  static Undertone _voteUndertone(List<(Undertone, double)> votes) {
    double warm = 0, cool = 0, neutral = 0;

    for (final v in votes) {
      final u = v.$1;
      final w = v.$2;
      switch (u) {
        case Undertone.warm:
          warm += w;
          break;
        case Undertone.cool:
          cool += w;
          break;
        case Undertone.neutral:
          neutral += w;
          break;
      }
    }

    final total = warm + cool + neutral;
    if (total < 0.05) return Undertone.neutral;

    if (warm >= cool && warm >= neutral) return Undertone.warm;
    if (cool >= warm && cool >= neutral) return Undertone.cool;
    return Undertone.neutral;
  }

  // ---------- Sampling rectangles ----------

  static ui.Rect _rectForRegion(_Region region, ui.Rect box, int imgW, int imgH) {
    final x0 = box.left;
    final y0 = box.top;
    final bw = box.width;
    final bh = box.height;

    ui.Rect rect;

    switch (region) {
      case _Region.leftCheek:
        rect = ui.Rect.fromLTRB(
          x0 + bw * 0.18,
          y0 + bh * 0.52,
          x0 + bw * 0.42,
          y0 + bh * 0.72,
        );
        break;

      case _Region.rightCheek:
        rect = ui.Rect.fromLTRB(
          x0 + bw * 0.58,
          y0 + bh * 0.52,
          x0 + bw * 0.82,
          y0 + bh * 0.72,
        );
        break;

      case _Region.forehead:
        rect = ui.Rect.fromLTRB(
          x0 + bw * 0.35,
          y0 + bh * 0.18,
          x0 + bw * 0.65,
          y0 + bh * 0.32,
        );
        break;
    }

    return ui.Rect.fromLTRB(
      rect.left.clamp(0.0, imgW.toDouble() - 1),
      rect.top.clamp(0.0, imgH.toDouble() - 1),
      rect.right.clamp(1.0, imgW.toDouble()),
      rect.bottom.clamp(1.0, imgH.toDouble()),
    );
  }

  // ---------- Pixel sampling (with contour exclusion) ----------

  static _SampleResult _sampleRect(
    Uint8List rgba,
    int w,
    int h,
    ui.Rect rect,
    List<_Polygon> exclusions,
  ) {
    int rSum = 0, gSum = 0, bSum = 0;
    int used = 0;
    int total = 0;

    final left = rect.left.round().clamp(0, w - 1);
    final top = rect.top.round().clamp(0, h - 1);
    final right = rect.right.round().clamp(0, w);
    final bottom = rect.bottom.round().clamp(0, h);

    const step = 3;

    for (int y = top; y < bottom; y += step) {
      for (int x = left; x < right; x += step) {
        total++;

        // Skip pixels inside exclusion polygons (eyes/lips/eyebrows)
        if (exclusions.isNotEmpty && _isInsideAnyExclusion(x.toDouble(), y.toDouble(), exclusions)) {
          continue;
        }

        final idx = (y * w + x) * 4;
        if (idx + 3 >= rgba.length) continue;

        final r = rgba[idx];
        final g = rgba[idx + 1];
        final b = rgba[idx + 2];
        final a = rgba[idx + 3];

        if (a < 200) continue;

        final lum = _luminance(r, g, b);
        if (lum < 40 || lum > 245) continue;

        rSum += r;
        gSum += g;
        bSum += b;
        used++;
      }
    }

    if (used == 0) {
      return _SampleResult(
        r: 128,
        g: 110,
        b: 100,
        used: 0,
        total: max(1, total),
      );
    }

    return _SampleResult(
      r: (rSum / used).round(),
      g: (gSum / used).round(),
      b: (bSum / used).round(),
      used: used,
      total: max(1, total),
    );
  }
}
