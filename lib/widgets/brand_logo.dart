import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Container(
        color: Colors.transparent,
        width: size,
        height: size,
        child: SvgPicture.asset(
          'assets/images/brand_logo.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => Image.asset(
            'assets/images/brand_logo.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
