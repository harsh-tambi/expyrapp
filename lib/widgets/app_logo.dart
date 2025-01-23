import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final Color backgroundColor;
  final bool showBackground;
  final BoxFit fit;

  const AppLogo({
    super.key,
    required this.size,
    this.color,
    this.backgroundColor = AppTheme.darkGreen,
    this.showBackground = false,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    Widget logo = Image.asset(
      'assets/images/Expyrailogo.png',
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        print('Error loading logo: $error');
        return Icon(
          Icons.eco,
          color: Colors.white,
          size: size * 0.6,
        );
      },
    );

    if (!showBackground) {
      return SizedBox(
        width: size,
        height: size,
        child: logo,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: logo,
      ),
    );
  }
}
