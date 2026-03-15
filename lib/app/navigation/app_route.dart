import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

enum AppRouteTransition { fadeThrough, sharedAxisHorizontal, fadeScale }

PageRoute<T> buildAppRoute<T>({
  required Widget page,
  AppRouteTransition transition = AppRouteTransition.fadeThrough,
  RouteSettings? settings,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return page;
        },
    transitionsBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          return switch (transition) {
            AppRouteTransition.fadeThrough => FadeThroughTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              fillColor: Colors.transparent,
              child: child,
            ),
            AppRouteTransition.sharedAxisHorizontal => SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.horizontal,
              fillColor: Colors.transparent,
              child: child,
            ),
            AppRouteTransition.fadeScale => FadeScaleTransition(
              animation: animation,
              child: child,
            ),
          };
        },
  );
}
