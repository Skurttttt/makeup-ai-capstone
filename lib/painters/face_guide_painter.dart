import 'package:flutter/material.dart';

/// Painter that draws a face position guide overlay on the camera preview
class FaceGuidePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  FaceGuidePainter({
    this.color = const Color(0xFFFF4D97),
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Calculate the oval dimensions for the face guide
    // Make it centered and sized appropriately for a face
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final ovalWidth = size.width * 0.65;
    final ovalHeight = size.height * 0.75;

    // Draw the main oval for face positioning
    final ovalRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: ovalWidth,
      height: ovalHeight,
    );
    canvas.drawOval(ovalRect, paint);

    // Draw corner brackets for better visual guidance
    final bracketLength = 30.0;
    final bracketPaint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 1
      ..strokeCap = StrokeCap.round;

    // Top-left bracket
    canvas.drawLine(
      Offset(ovalRect.left, ovalRect.top + bracketLength),
      Offset(ovalRect.left, ovalRect.top),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(ovalRect.left, ovalRect.top),
      Offset(ovalRect.left + bracketLength, ovalRect.top),
      bracketPaint,
    );

    // Top-right bracket
    canvas.drawLine(
      Offset(ovalRect.right - bracketLength, ovalRect.top),
      Offset(ovalRect.right, ovalRect.top),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(ovalRect.right, ovalRect.top),
      Offset(ovalRect.right, ovalRect.top + bracketLength),
      bracketPaint,
    );

    // Bottom-left bracket
    canvas.drawLine(
      Offset(ovalRect.left, ovalRect.bottom - bracketLength),
      Offset(ovalRect.left, ovalRect.bottom),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(ovalRect.left, ovalRect.bottom),
      Offset(ovalRect.left + bracketLength, ovalRect.bottom),
      bracketPaint,
    );

    // Bottom-right bracket
    canvas.drawLine(
      Offset(ovalRect.right - bracketLength, ovalRect.bottom),
      Offset(ovalRect.right, ovalRect.bottom),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(ovalRect.right, ovalRect.bottom),
      Offset(ovalRect.right, ovalRect.bottom - bracketLength),
      bracketPaint,
    );

    // Draw a subtle crosshair at center for alignment
    final crosshairLength = 15.0;
    final crosshairPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Horizontal line
    canvas.drawLine(
      Offset(centerX - crosshairLength, centerY),
      Offset(centerX + crosshairLength, centerY),
      crosshairPaint,
    );

    // Vertical line
    canvas.drawLine(
      Offset(centerX, centerY - crosshairLength),
      Offset(centerX, centerY + crosshairLength),
      crosshairPaint,
    );

    // Draw text instruction at the bottom
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Position your face within the guide',
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 14,
          fontWeight: FontWeight.w500,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.7),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        centerX - textPainter.width / 2,
        ovalRect.bottom + 20,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
