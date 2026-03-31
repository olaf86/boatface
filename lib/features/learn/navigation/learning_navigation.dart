import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation/app_route.dart';
import '../../../app/navigation/app_shell.dart';
import '../../review/presentation/review_screen.dart';

void pushLearningReviewPage(BuildContext context) {
  Navigator.of(context).push(_buildLearningReviewRoute());
}

void openLearningReviewFlow(BuildContext context, WidgetRef ref) {
  final NavigatorState navigator = Navigator.of(context);
  ref.read(appShellTabControllerProvider.notifier).select(AppShellTab.learning);
  navigator.popUntil((Route<dynamic> route) => route.isFirst);
  navigator.push(_buildLearningReviewRoute());
}

PageRoute<void> _buildLearningReviewRoute() {
  return buildAppRoute<void>(
    page: const ReviewPage(),
    transition: AppRouteTransition.sharedAxisHorizontal,
  );
}
