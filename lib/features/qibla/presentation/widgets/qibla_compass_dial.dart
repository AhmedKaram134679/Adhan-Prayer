import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class QiblaCompassDial extends StatelessWidget {
  /// Qibla direction in degrees from North (0° to 360°).
  final double qiblaBearing;

  /// Current device heading in degrees from North (0° to 360°), or null if sensor unavailable.
  final double? deviceHeading;

  /// Whether the phone is currently aligned towards the Kaaba (within threshold).
  final bool isAlignedWithQibla;

  const QiblaCompassDial({
    super.key,
    required this.qiblaBearing,
    this.deviceHeading,
    this.isAlignedWithQibla = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dial rotation angle in radians:
    // If device heading is available, the dial rotates counter-clockwise by deviceHeading
    // so the dial points to True North relative to the physical world.
    final dialRotation = deviceHeading != null ? -deviceHeading! * (math.pi / 180.0) : 0.0;

    return Center(
      child: SizedBox(
        width: 300,
        height: 300,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow when aligned with Qibla
            if (isAlignedWithQibla)
              Container(
                width: 290,
                height: 290,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryLight.withValues(alpha: 0.4),
                      blurRadius: 28,
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),

            // Rotating Compass Rose & Kaaba Pointer
            Transform.rotate(
              angle: dialRotation,
              child: CustomPaint(
                size: const Size(280, 280),
                painter: _CompassPainter(
                  isDark: isDark,
                  qiblaBearing: qiblaBearing,
                  isAligned: isAlignedWithQibla,
                ),
              ),
            ),

            // Center device indicator (Top phone pointer)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.navigation,
                  size: 28,
                  color: isAlignedWithQibla
                      ? AppColors.primaryLight
                      : (isDark ? AppColors.accent : AppColors.primary),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isAlignedWithQibla ? AppColors.primaryLight : AppColors.accent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final bool isDark;
  final double qiblaBearing;
  final bool isAligned;

  _CompassPainter({
    required this.isDark,
    required this.qiblaBearing,
    required this.isAligned,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Dial Background circle
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF1E222A) : const Color(0xFFF1F3F5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Border ring
    final borderPaint = Paint()
      ..color = isAligned
          ? AppColors.primaryLight
          : (isDark ? const Color(0xFF323846) : const Color(0xFFD3D7E0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = isAligned ? 3.5 : 2.0;
    canvas.drawCircle(center, radius - 2, borderPaint);

    // Inner subtle ring
    final innerRingPaint = Paint()
      ..color = isDark ? const Color(0xFF282E3B) : const Color(0xFFE2E5EA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius - 35, innerRingPaint);

    // 2. Compass Ticks & Cardinal Labels (N, E, S, W)
    final tickPaint = Paint()
      ..color = isDark ? const Color(0xFF5A6275) : const Color(0xFFA0A5B5)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final majorTickPaint = Paint()
      ..color = isDark ? Colors.white70 : Colors.black87
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const cardinalLabels = {0: 'N', 90: 'E', 180: 'S', 270: 'W'};

    for (int deg = 0; deg < 360; deg += 5) {
      final rad = deg * (math.pi / 180.0);
      final isCardinal = deg % 90 == 0;
      final isMajor = deg % 30 == 0;

      final double tickLength = isCardinal ? 14 : (isMajor ? 10 : 5);
      final startR = radius - 4;
      final endR = radius - 4 - tickLength;

      final startPos = Offset(
        center.dx + startR * math.sin(rad),
        center.dy - startR * math.cos(rad),
      );
      final endPos = Offset(
        center.dx + endR * math.sin(rad),
        center.dy - endR * math.cos(rad),
      );

      canvas.drawLine(startPos, endPos, isCardinal || isMajor ? majorTickPaint : tickPaint);

      if (isCardinal) {
        final label = cardinalLabels[deg]!;
        final textSpan = TextSpan(
          text: label,
          style: TextStyle(
            color: deg == 0
                ? const Color(0xFFE63946) // Red North
                : (isDark ? Colors.white : Colors.black87),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        final textR = radius - 28;
        final textPos = Offset(
          center.dx + textR * math.sin(rad) - textPainter.width / 2,
          center.dy - textR * math.cos(rad) - textPainter.height / 2,
        );
        textPainter.paint(canvas, textPos);
      }
    }

    // 3. Kaaba Marker / Pointer towards Qibla Bearing
    final qiblaRad = qiblaBearing * (math.pi / 180.0);
    final kaabaRadius = radius - 52;
    final kaabaCenter = Offset(
      center.dx + kaabaRadius * math.sin(qiblaRad),
      center.dy - kaabaRadius * math.cos(qiblaRad),
    );

    // Line from center to Kaaba
    final pointerLinePaint = Paint()
      ..color = isAligned ? AppColors.primaryLight : AppColors.accent
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final lineStart = Offset(
      center.dx + 25 * math.sin(qiblaRad),
      center.dy - 25 * math.cos(qiblaRad),
    );
    final lineEnd = Offset(
      center.dx + (kaabaRadius - 16) * math.sin(qiblaRad),
      center.dy - (kaabaRadius - 16) * math.cos(qiblaRad),
    );
    canvas.drawLine(lineStart, lineEnd, pointerLinePaint);

    // Kaaba icon badge
    final badgePaint = Paint()
      ..color = isAligned ? AppColors.primary : const Color(0xFF1B1B1B)
      ..style = PaintingStyle.fill;
    final badgeBorder = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(kaabaCenter, 14, badgePaint);
    canvas.drawCircle(kaabaCenter, 14, badgeBorder);

    // Kaaba cube symbol
    final cubePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final cubeRect = Rect.fromCenter(center: kaabaCenter, width: 12, height: 12);
    canvas.drawRect(cubeRect, cubePaint);

    // Golden Kiswah band on Kaaba icon
    final goldBand = Paint()
      ..color = AppColors.accentLight
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(cubeRect.left, cubeRect.top + 3),
      Offset(cubeRect.right, cubeRect.top + 3),
      goldBand,
    );
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) {
    return oldDelegate.qiblaBearing != qiblaBearing ||
        oldDelegate.isAligned != isAligned ||
        oldDelegate.isDark != isDark;
  }
}
