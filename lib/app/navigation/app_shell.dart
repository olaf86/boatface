import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/settings_screen.dart';
import '../../features/learn/presentation/learning_screen.dart';
import '../../features/quiz/application/racer_master_sync_controller.dart';
import '../../features/ranking/presentation/ranking_screen.dart';
import '../../shared/privacy/privacy_preferences_controller.dart';
import 'app_route.dart';

enum AppShellTab { learning, home, ranking }

extension AppShellTabX on AppShellTab {
  String get label => switch (this) {
    AppShellTab.home => '遊ぶ',
    AppShellTab.learning => '学ぶ',
    AppShellTab.ranking => 'ランキング',
  };

  IconData get icon => switch (this) {
    AppShellTab.home => Icons.home_rounded,
    AppShellTab.learning => Icons.menu_book_rounded,
    AppShellTab.ranking => Icons.leaderboard_rounded,
  };
}

final NotifierProvider<AppShellTabController, AppShellTab>
appShellTabControllerProvider =
    NotifierProvider<AppShellTabController, AppShellTab>(
      AppShellTabController.new,
    );

class AppShellTabController extends Notifier<AppShellTab> {
  @override
  AppShellTab build() => AppShellTab.home;

  void select(AppShellTab tab) {
    if (state == tab) {
      return;
    }
    state = tab;
  }
}

class AppShellScreen extends ConsumerStatefulWidget {
  const AppShellScreen({super.key});

  @override
  ConsumerState<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends ConsumerState<AppShellScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(racerMasterSyncControllerProvider.notifier)
          .startBackgroundSyncIfNeeded();
      unawaited(
        ref
            .read(privacyPreferencesControllerProvider)
            .preparePrivacyMessagingOnAppStart(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppShellTab currentTab = ref.watch(appShellTabControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(currentTab.label),
        actions: <Widget>[
          IconButton(
            tooltip: '設定',
            onPressed: () {
              Navigator.of(context).push(
                buildAppRoute<void>(
                  page: const SettingsScreen(),
                  transition: AppRouteTransition.sharedAxisHorizontal,
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: IndexedStack(
        index: currentTab.index,
        children: <Widget>[
          const LearningScreen(),
          const HomeScreen(),
          const RankingScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab.index,
        onDestinationSelected: (int index) =>
            _selectTab(AppShellTab.values[index]),
        destinations: AppShellTab.values
            .map(
              (AppShellTab tab) =>
                  NavigationDestination(icon: Icon(tab.icon), label: tab.label),
            )
            .toList(growable: false),
      ),
    );
  }

  void _selectTab(AppShellTab tab) {
    ref.read(appShellTabControllerProvider.notifier).select(tab);
  }
}

void navigateToAppShellTab(
  BuildContext context,
  WidgetRef ref,
  AppShellTab tab,
) {
  ref.read(appShellTabControllerProvider.notifier).select(tab);
  Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
}
