import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _AtomLogoPainter(),
    );
  }
}

class _AtomLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Slanted Pillar
    final path1 = Path();
    path1.moveTo(size.width * 0.65, size.height * 0.1);
    path1.lineTo(size.width * 0.85, size.height * 0.1);
    path1.lineTo(size.width * 0.65, size.height * 0.9);
    path1.lineTo(size.width * 0.45, size.height * 0.9);
    path1.close();
    canvas.drawPath(path1, paint);

    // Orbital Curve/Swish
    final path2 = Path();
    final rect = Rect.fromLTWH(
      size.width * 0.1,
      size.height * 0.45,
      size.width * 0.45,
      size.height * 0.45,
    );
    path2.addOval(rect);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
