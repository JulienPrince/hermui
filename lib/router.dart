import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'screens/chat_screen.dart';
import 'screens/history_screen.dart';
import 'screens/jobs_screen.dart';
import 'screens/setup_screen.dart';
import 'theme/tokens.dart';
import 'widgets/bottom_nav.dart';

abstract class AppRoutes {
  static const setup = '/setup';
  static const chat = '/chat';
  static const history = '/history';
  static const jobs = '/jobs';
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(settingsProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.chat,
    refreshListenable: refresh,
    redirect: (context, state) {
      final settings = ref.read(settingsProvider);
      if (!settings.ready) return null;
      final goingToSetup = state.matchedLocation == AppRoutes.setup;
      if (!settings.isConfigured && !goingToSetup) return AppRoutes.setup;
      if (settings.isConfigured && goingToSetup) return AppRoutes.chat;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.setup,
        builder: (_, _) => const SetupScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.chat,
                builder: (_, _) => const ChatScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (_, _) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.jobs,
                builder: (_, _) => const JobsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    debugLogDiagnostics: kDebugMode,
  );
});

class _MainShell extends StatelessWidget {
  const _MainShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HermesTokens.surface,
      body: shell,
      bottomNavigationBar: HermesBottomNav(shell: shell),
    );
  }
}
