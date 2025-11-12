import 'package:flutter/material.dart';

PageRoute<T> fadeRouteWhite<T>(Widget page, {Duration? duration}) {
  return PageRouteBuilder<T>(
    opaque: true,
    barrierColor: Colors.transparent,
    transitionDuration: duration ?? const Duration(milliseconds: 200),
    reverseTransitionDuration: duration ?? const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // 전환 중에도 바닥을 흰색으로 강제 채움
      final wrapped = const DecoratedBox(
        decoration: BoxDecoration(color: Colors.white),
        child: SizedBox.expand(), // 바닥 전체 흰색
      );

      return Stack(
        fit: StackFit.expand,
        children: [
          wrapped,
          FadeTransition(opacity: animation, child: child),
        ],
      );
    },
  );
}
