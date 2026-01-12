import 'dart:math';
import 'dart:ui' as ui;

enum LipFinish { matte, glossy }

class DrawingUtils {
  static List<ui.Offset> sortByX(List<ui.Offset> pts) {
    final copy = List<ui.Offset>.from(pts);
    copy.sort((a, b) => a.dx.compareTo(b.dx));
    return copy;
  }

  static ui.Path catmullRomToBezierPath(List<ui.Offset> pts, {double tension = 0.7}) {
    if (pts.length < 2) return ui.Path();
    final t = tension.clamp(0.0, 1.0);

    ui.Offset p(int i) {
      if (i < 0) return pts.first;
      if (i >= pts.length) return pts.last;
      return pts[i];
    }

    final path = ui.Path()..moveTo(pts.first.dx, pts.first.dy);

    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = p(i - 1);
      final p1 = p(i);
      final p2 = p(i + 1);
      final p3 = p(i + 2);

      final c1 = ui.Offset(
        p1.dx + (p2.dx - p0.dx) * (t / 6.0),
        p1.dy + (p2.dy - p0.dy) * (t / 6.0),
      );
      final c2 = ui.Offset(
        p2.dx - (p3.dx - p1.dx) * (t / 6.0),
        p2.dy - (p3.dy - p1.dy) * (t / 6.0),
      );

      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  static ui.Rect boundsOf(List<ui.Offset> pts) {
    double minX = pts.first.dx, maxX = pts.first.dx;
    double minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts.skip(1)) {
      minX = min(minX, p.dx);
      maxX = max(maxX, p.dx);
      minY = min(minY, p.dy);
      maxY = max(maxY, p.dy);
    }
    return ui.Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  static ui.Path pathFromPoints(List<ui.Offset> pts, {bool close = true}) {
    final path = ui.Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    if (close) path.close();
    return path;
  }
}
