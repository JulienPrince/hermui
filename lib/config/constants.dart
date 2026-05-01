/// Constantes & configuration de l'app.
///
/// L'URL par défaut est injectée à la compilation via `--dart-define` afin de
/// ne jamais hardcoder une instance privée dans le code source publié.
class AppConstants {
  /// URL par défaut proposée à l'écran Setup. Vide → l'utilisateur doit la saisir.
  /// Override : `flutter run --dart-define=HERMES_DEFAULT_BASE_URL=https://...`
  static const String defaultBaseUrl = String.fromEnvironment(
    'HERMES_DEFAULT_BASE_URL',
    defaultValue: '',
  );

  /// Hint affiché dans le champ URL si aucune valeur par défaut n'est compilée.
  static const String baseUrlPlaceholder = 'https://your-hermes-instance.com';

  static const String storageKeyApiKey = 'hermes_api_key';
  static const String storageKeyBaseUrl = 'hermes_base_url';

  static const String pathHealth = '/health';
  static const String pathChatCompletions = '/v1/chat/completions'; // legacy
  static const String pathRuns = '/v1/runs';
  static const String pathJobs = '/api/jobs';

  static const String defaultModel = 'hermes-agent';

  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration streamTimeout = Duration(minutes: 5);
}
