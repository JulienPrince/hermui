/// Stub de la version Web — chargée uniquement sur native, ne sera jamais
/// appelée (le code à l'appel route via `kIsWeb`).
Stream<String> sseStreamLines(String url, Map<String, String> headers) {
  throw UnsupportedError('sseStreamLines: stub appelé sur une plateforme non-web');
}
