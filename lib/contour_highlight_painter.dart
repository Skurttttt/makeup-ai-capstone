import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'look_engine.dart';

class ContourHighlightPainter {
  final Face face;
  final double intensity;
  final FaceShape faceShape;

  ContourHighlightPainter({
    required this.face,
    required this.intensity,
    required this.faceShape,
  });

  void paint(Canvas canvas, Size size) {
    final k = intensity.clamp(0.0, 1.0);
    if (k <= 0.0) return;

    final box = face.boundingBox;
    final faceW = box.width;
    final faceH = box.height;

    // scale-aware blur so it’s consistent near/far
    final sigmaBase = max(faceW, faceH) * 0.012;
    final sigmaSoft = sigmaBase * 2.0;
    final sigmaWide = sigmaBase * 3.3;

    // Face oval clip (prevents contour/highlight from affecting outside face)
    final faceOval = face.contours[FaceContourType.face]?.points;
    if (faceOval != null && faceOval.length >= 10) {
      final pts = faceOval.map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble())).toList();
      final clip = _smoothClosedPath(pts, target: 44);
      canvas.save();
      canvas.clipPath(clip);

      _paintInside(canvas, box, faceW, faceH, k, sigmaSoft, sigmaWide);

      canvas.restore();
    } else {
      // Fallback if contour missing: still paint but without clip
      _paintInside(canvas, box, faceW, faceH, k, sigmaSoft, sigmaWide);
    }
  }

  void _paintInside(
    Canvas canvas,
    Rect box,
    double faceW,
    double faceH,
    double k,
    double sigmaSoft,
    double sigmaWide,
  ) {
    double blushYFactor;
    switch (faceShape) {
      case FaceShape.round:
        blushYFactor = 0.58;
        break;
      case FaceShape.square:
        blushYFactor = 0.64;
        break;
      case FaceShape.oval:
        blushYFactor = 0.62;
        break;
      case FaceShape.heart:
        blushYFactor = 0.60;
        break;
      case FaceShape.unknown:
        blushYFactor = 0.62;
        break;
    }

    // ---------------- Nose highlight (Screen / SoftLight) ----------------
    final noseCenterX = box.left + faceW * 0.50;
    final noseTopY = box.top + faceH * 0.35;
    final noseBottomY = box.top + faceH * 0.62;

    final noseRect = ui.Rect.fromCenter(
      center: ui.Offset(noseCenterX, (noseTopY + noseBottomY) / 2),
      width: faceW * 0.06,
      height: (noseBottomY - noseTopY),
    );

    final nosePath = Path()..addRRect(RRect.fromRectXY(noseRect, faceW * 0.08, faceW * 0.08));
    final noseBounds = noseRect.inflate(faceW * 0.18);
    canvas.saveLayer(noseBounds, Paint());

    canvas.drawPath(
      nosePath,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(
          ui.Offset(noseRect.center.dx, noseRect.top),
          ui.Offset(noseRect.center.dx, noseRect.bottom),
          [
            Colors.white.withOpacity(0.22 * k),
            Colors.white.withOpacity(0.03 * k),
          ],
        )
        ..blendMode = BlendMode.screen
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaSoft),
    );

    canvas.restore();

    // ---------------- Cheekbone highlight (Screen) ----------------
    void drawCheekHighlight({required bool left}) {
      final cx = left ? (box.left + faceW * 0.30) : (box.left + faceW * 0.70);
      final cy = box.top + faceH * (blushYFactor - 0.085);

      final rect = ui.Rect.fromCenter(
        center: ui.Offset(cx, cy),
        width: faceW * 0.19,
        height: faceH * 0.06,
      );

      final r = max(rect.width, rect.height) * 0.75;
      final bounds = rect.inflate(r * 0.8);

      canvas.saveLayer(bounds, Paint());

      canvas.drawRRect(
        RRect.fromRectXY(rect, rect.width * 0.45, rect.height * 0.45),
        Paint()
          ..isAntiAlias = true
          ..shader = ui.Gradient.radial(
            rect.center,
            r,
            [
              Colors.white.withOpacity(0.16 * k),
              Colors.white.withOpacity(0.0),
            ],
            const [0.0, 1.0],
          )
          ..blendMode = BlendMode.screen
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaSoft),
      );

      canvas.restore();
    }

    drawCheekHighlight(left: true);
    drawCheekHighlight(left: false);

    // ---------------- Cheek contour (Multiply, lower opacity, softer) ----------------
    void drawCheekContour({required bool left}) {
      final cx = left ? (box.left + faceW * 0.32) : (box.left + faceW * 0.68);
      final cy = box.top + faceH * 0.71;

      final rect = ui.Rect.fromCenter(
        center: ui.Offset(cx, cy),
        width: faceW * 0.24,
        height: faceH * 0.10,
      );

      final r = max(rect.width, rect.height) * 1.08;
      final bounds = rect.inflate(r * 0.7);

      canvas.saveLayer(bounds, Paint());

      // core shadow
      canvas.drawRRect(
        RRect.fromRectXY(rect, rect.width * 0.55, rect.height * 0.55),
        Paint()
          ..isAntiAlias = true
          ..shader = ui.Gradient.radial(
            rect.center,
            r,
            [
              Colors.black.withOpacity(0.11 * k), // ✅ lowered so it won’t kill blush
              Colors.black.withOpacity(0.0),
            ],
            const [0.0, 1.0],
          )
          ..blendMode = BlendMode.multiply
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaSoft),
      );

      // wide melt
      canvas.drawRRect(
        RRect.fromRectXY(rect, rect.width * 0.55, rect.height * 0.55),
        Paint()
          ..isAntiAlias = true
          ..color = Colors.black.withOpacity(0.018 * k)
          ..blendMode = BlendMode.multiply
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaWide),
      );

      canvas.restore();
    }

    drawCheekContour(left: true);
    drawCheekContour(left: false);

    // ---------------- Jawline contour (Multiply, very soft) ----------------
    final jawRect = ui.Rect.fromLTRB(
      box.left + faceW * 0.15,
      box.top + faceH * 0.84,
      box.right - faceW * 0.15,
      box.top + faceH * 0.93,
    );

    final jawBounds = jawRect.inflate(faceW * 0.22);
    canvas.saveLayer(jawBounds, Paint());

    canvas.drawRRect(
      RRect.fromRectXY(jawRect, jawRect.height * 0.75, jawRect.height * 0.75),
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(
          ui.Offset(jawRect.left, jawRect.center.dy),
          ui.Offset(jawRect.right, jawRect.center.dy),
          [
            Colors.black.withOpacity(0.06 * k),
            Colors.black.withOpacity(0.11 * k),
            Colors.black.withOpacity(0.06 * k),
          ],
          const [0.0, 0.5, 1.0],
        )
        ..blendMode = BlendMode.multiply
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaWide),
    );

    canvas.restore();
  }

  // ---- Helpers (simple smooth closed path) ----
  Path _smoothClosedPath(List<ui.Offset> pts, {required int target}) {
    final s = _resample(pts, target);
    final path = Path()..moveTo(s.first.dx, s.first.dy);

    for (int i = 0; i < s.length - 1; i++) {
      final p0 = s[i];
      final p1 = s[i + 1];
      final mid = ui.Offset((p0.dx + p1.dx) * 0.5, (p0.dy + p1.dy) * 0.5);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }

    final pLast = s.last;
    final pFirst = s.first;
    final mid = ui.Offset((pLast.dx + pFirst.dx) * 0.5, (pLast.dy + pFirst.dy) * 0.5);
    path.quadraticBezierTo(pLast.dx, pLast.dy, mid.dx, mid.dy);

    path.close();
    return path;
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
}
