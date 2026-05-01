// Public API du SSE client — dispatche entre native (jamais appelé en
// pratique, géré par Dio) et Web (`dart:html` HttpRequest pour streaming réel
// via `onProgress`).
export 'sse_web_stub.dart' if (dart.library.html) 'sse_web.dart';
