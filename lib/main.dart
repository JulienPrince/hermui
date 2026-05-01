import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'providers.dart';
import 'router.dart';
import 'services/notifications.dart';
import 'theme/tokens.dart';
import 'widgets/animated_splash.dart';

/// Clé globale pour le `ScaffoldMessenger` — utilisée par `NotificationsService`
/// pour afficher des toasts sur Web.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: HermesTokens.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  NotificationsService.instance.attachMessenger(scaffoldMessengerKey);
  await NotificationsService.instance.init();
  runApp(const ProviderScope(child: HermesApp()));
}

class HermesApp extends ConsumerStatefulWidget {
  const HermesApp({super.key});

  @override
  ConsumerState<HermesApp> createState() => _HermesAppState();
}

class _HermesAppState extends ConsumerState<HermesApp> {
  /// Durée minimum d'affichage du splash animé — sinon les settings se
  /// chargent en quelques ms et l'animation est imperceptible.
  static const _minSplash = Duration(milliseconds: 1100);
  bool _splashElapsed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(_minSplash, () {
      if (mounted) setState(() => _splashElapsed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);

    if (!settings.ready || !_splashElapsed) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const AnimatedSplash(),
      );
    }

    return MaterialApp.router(
      title: 'Hermes',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: _buildTheme(),
      routerConfig: router,
      scaffoldMessengerKey: scaffoldMessengerKey,
      scrollBehavior: const _HermesScrollBehavior(),
    );
  }
}

/// Scroll behavior global :
/// - Pas d'effet stretch (le ressort Material qui déforme les widgets)
/// - Bounce iOS-style sur toutes les plateformes (plus discret)
class _HermesScrollBehavior extends MaterialScrollBehavior {
  const _HermesScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // aucune indication d'overscroll, on s'appuie sur le bounce
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}

ThemeData _buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: HermesTokens.accent,
    brightness: Brightness.dark,
    primary: HermesTokens.accent,
    surface: HermesTokens.surface,
    onSurface: HermesTokens.text,
    error: HermesTokens.error,
    outline: HermesTokens.border,
    outlineVariant: HermesTokens.borderStrong,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: HermesTokens.text,
      displayColor: HermesTokens.text,
    ),
    scaffoldBackgroundColor: HermesTokens.surface,
    canvasColor: HermesTokens.surface,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: HermesTokens.surface,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: HermesTokens.border,
      thickness: 1,
      space: 1,
    ),
  );
}
