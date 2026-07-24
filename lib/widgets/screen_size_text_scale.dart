import 'package:flutter/material.dart';

double appTextScaleForSize(Size size) {
  final shortestSide = size.shortestSide;

  if (shortestSide >= 900) {
    return 1.12;
  }
  if (shortestSide >= 600) {
    return 1.06;
  }
  return 1;
}

class ScreenSizeTextScale extends StatelessWidget {
  final Widget child;

  const ScreenSizeTextScale({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final textScale = appTextScaleForSize(mediaQuery.size);

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: TextScaler.linear(textScale)),
      child: child,
    );
  }
}
