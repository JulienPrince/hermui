// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// `dart:html` est l'API la plus stable pour streamer une réponse HTTP
// progressivement côté navigateur. `package:web` n'expose pas encore
// `onProgress` de manière simple. On accepte la deprecation pour ce fichier
// (chargé uniquement sur Web).

import 'dart:async';
import 'dart:html' as html;

/// Stream chaque ligne SSE reçue par XHR `onProgress`. Bufferise les chunks
/// partiels — une ligne incomplète attend le prochain progress event.
///
/// Émet ligne par ligne (sans le `\n`). L'appelant reste responsable du
/// parsing SSE (`data:` / commentaires `:`).
Stream<String> sseStreamLines(String url, Map<String, String> headers) {
  final controller = StreamController<String>();
  final xhr = html.HttpRequest()..open('GET', url);

  headers.forEach((k, v) => xhr.setRequestHeader(k, v));

  var lastLength = 0;
  final buffer = StringBuffer();

  void flush({required bool finalFlush}) {
    final text = xhr.responseText ?? '';
    if (text.length > lastLength) {
      buffer.write(text.substring(lastLength));
      lastLength = text.length;
    }
    var current = buffer.toString();
    var nlIndex = current.indexOf('\n');
    while (nlIndex >= 0) {
      final line = current.substring(0, nlIndex);
      // Strip CR éventuel (CRLF).
      final clean = line.endsWith('\r')
          ? line.substring(0, line.length - 1)
          : line;
      controller.add(clean);
      current = current.substring(nlIndex + 1);
      nlIndex = current.indexOf('\n');
    }
    buffer
      ..clear()
      ..write(current);
    if (finalFlush && current.isNotEmpty) {
      controller.add(current);
      buffer.clear();
    }
  }

  xhr.onProgress.listen((_) => flush(finalFlush: false));
  xhr.onLoad.listen((_) {
    flush(finalFlush: true);
    controller.close();
  });
  xhr.onError.listen((_) {
    controller.addError(Exception('SSE: erreur XHR'));
    controller.close();
  });
  xhr.onAbort.listen((_) {
    controller.close();
  });

  controller.onCancel = () {
    try {
      xhr.abort();
    } catch (_) {}
  };

  xhr.send();
  return controller.stream;
}
