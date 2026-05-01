import 'package:dio/dio.dart';

/// Expanseur `@url:<url>` côté client. Détecte tous les marqueurs dans le
/// texte d'entrée, fetche les pages en parallèle (taille capée) et inline le
/// résultat en bloc `--- Attached Context (URL) ---` avant l'envoi.
///
/// Hermes voit juste un long string — pas besoin que l'agent appelle
/// `web_extract` pour des URLs déjà connues : un round-trip de moins.
class ContextRefsExpander {
  ContextRefsExpander({Dio? dio, int maxBytes = 8000, Duration? timeout})
      : _dio = dio ?? Dio(),
        _maxBytes = maxBytes,
        _timeout = timeout ?? const Duration(seconds: 8);

  final Dio _dio;
  final int _maxBytes;
  final Duration _timeout;

  /// Capture `@url:<url>` jusqu'au prochain whitespace. URL doit commencer
  /// par http:// ou https:// (autres schemes ignorés volontairement).
  static final _refRegex = RegExp(
    r'@url:(https?://[^\s]+)',
    caseSensitive: false,
  );

  /// Détecte les marqueurs sans les fetcher — utile pour afficher un état
  /// "fetching N URLs" dans l'UI.
  List<String> findRefs(String input) {
    return _refRegex
        .allMatches(input)
        .map((m) => m.group(1)!)
        .toSet()
        .toList();
  }

  /// Expanse `input` : retourne une copie où chaque `@url:<url>` est suivi
  /// d'un bloc `--- Attached Context (url) --- <text> --- /Attached ---`.
  /// Si une URL fail (timeout, 4xx, 5xx, parse), on la marque `[fetch failed]`
  /// et on continue — pas d'exception qui bloque l'envoi.
  Future<String> expand(String input) async {
    final urls = findRefs(input);
    if (urls.isEmpty) return input;

    final results = await Future.wait(
      urls.map((u) => _fetchOne(u)),
    );

    final buf = StringBuffer(input);
    for (var i = 0; i < urls.length; i++) {
      final url = urls[i];
      final body = results[i];
      buf
        ..write('\n\n--- Attached Context ($url) ---\n')
        ..write(body)
        ..write('\n--- /Attached ---');
    }
    return buf.toString();
  }

  Future<String> _fetchOne(String url) async {
    try {
      final res = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          connectTimeout: _timeout,
          headers: {
            'User-Agent': 'hermui/1.x (+attached-context)',
            'Accept': 'text/html,text/plain;q=0.9,*/*;q=0.5',
          },
        ),
      );
      final raw = res.data ?? '';
      return _stripHtml(raw);
    } catch (_) {
      return '[fetch failed]';
    }
  }

  /// Strip très basique HTML → texte. Vire scripts/styles, balises, et
  /// collapse les whitespaces. Tronque à `_maxBytes` bytes.
  String _stripHtml(String raw) {
    var s = raw
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (s.length > _maxBytes) {
      s = '${s.substring(0, _maxBytes)}… [truncated]';
    }
    return s.isEmpty ? '[empty body]' : s;
  }
}
