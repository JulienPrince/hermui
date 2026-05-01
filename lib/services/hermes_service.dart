import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/constants.dart';
import 'sse.dart' as sse;

class ChatMessage {
  final String role;
  final String content;
  const ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// Soumission d'un run — réponse de POST /v1/runs.
class RunSubmission {
  RunSubmission({required this.runId, this.sessionId, this.status});
  final String runId;
  final String? sessionId;
  final String? status;
}

/// Usage tokens — payload de l'event run.completed.
class TokenUsage {
  const TokenUsage({this.inputTokens = 0, this.outputTokens = 0});
  final int inputTokens;
  final int outputTokens;

  static TokenUsage? fromJson(dynamic v) {
    if (v is! Map) return null;
    int parse(dynamic n) => n is int ? n : (n is num ? n.toInt() : 0);
    return TokenUsage(
      inputTokens: parse(v['input_tokens'] ?? v['inputTokens']),
      outputTokens: parse(v['output_tokens'] ?? v['outputTokens']),
    );
  }
}

class JobSummary {
  final String id;
  final String name;
  final String? prompt;
  final String? schedule;
  final String? status;
  final bool? enabled;
  final DateTime? lastRun;
  final DateTime? nextRun;
  final String? lastResult;
  final Map<String, dynamic> raw;

  JobSummary({
    required this.id,
    required this.name,
    this.prompt,
    this.schedule,
    this.status,
    this.enabled,
    this.lastRun,
    this.nextRun,
    this.lastResult,
    required this.raw,
  });

  factory JobSummary.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v is String) return DateTime.tryParse(v);
      if (v is int) {
        return DateTime.fromMillisecondsSinceEpoch(
          v > 9999999999 ? v : v * 1000,
        );
      }
      return null;
    }

    /// Coerce uniquement les valeurs effectivement stringy. Évite que des Map
    /// imbriqués (ex: `{prompt: {text: "..."}}`) ne fassent foirer le cast.
    String? asStr(dynamic v) {
      if (v is String) return v;
      if (v is num || v is bool) return v.toString();
      return null;
    }

    /// Récupère une valeur potentiellement nichée (`trigger.expression` etc.).
    dynamic nested(List<List<String>> paths) {
      for (final path in paths) {
        dynamic v = json;
        for (final key in path) {
          if (v is Map && v[key] != null) {
            v = v[key];
          } else {
            v = null;
            break;
          }
        }
        if (v != null) return v;
      }
      return null;
    }

    return JobSummary(
      id: asStr(json['id']) ??
          asStr(json['_id']) ??
          asStr(json['job_id']) ??
          asStr(json['name']) ??
          '',
      name: asStr(json['name']) ??
          asStr(json['title']) ??
          asStr(json['id']) ??
          'job',
      prompt: asStr(json['prompt']) ??
          asStr(json['instructions']) ??
          asStr(json['description']) ??
          asStr(nested([
            ['task', 'prompt'],
            ['payload', 'prompt'],
          ])),
      // Hermes envoie `schedule` en objet imbriqué + `schedule_display` en
      // string. On préfère le display ; sinon on plonge dans l'objet.
      schedule: asStr(json['schedule_display']) ??
          asStr(nested([
            ['schedule', 'display'],
            ['schedule', 'expr'],
            ['schedule', 'cron'],
            ['schedule', 'expression'],
          ])) ??
          asStr(json['schedule']) ??
          asStr(json['cron']) ??
          asStr(json['cron_expression']) ??
          asStr(json['expression']),
      status: asStr(json['status']) ??
          asStr(json['state']) ??
          (json['enabled'] == false ? 'paused' : null),
      enabled: json['enabled'] is bool ? json['enabled'] as bool : null,
      lastRun: parseDate(json['last_run_at'] ??
          json['last_run'] ??
          json['lastRun'] ??
          json['lastRunAt']),
      nextRun: parseDate(json['next_run_at'] ??
          json['next_run'] ??
          json['nextRun'] ??
          json['nextRunAt'] ??
          json['scheduled_for']),
      lastResult: asStr(json['last_error']) ??
          asStr(json['last_status']) ??
          asStr(json['last_result']) ??
          asStr(json['lastResult']) ??
          asStr(json['last_output']),
      raw: json,
    );
  }
}

/// Payload de création/mise à jour d'un job.
class JobInput {
  const JobInput({
    this.name,
    required this.prompt,
    required this.schedule,
    this.skills,
  });

  final String? name;
  final String prompt;
  final String schedule;
  final List<String>? skills;

  Map<String, dynamic> toJson() => {
        if (name != null && name!.isNotEmpty) 'name': name,
        'prompt': prompt,
        'schedule': schedule,
        if (skills != null) 'skills': skills,
      };
}

class HermesException implements Exception {
  final String message;
  final int? statusCode;
  HermesException(this.message, {this.statusCode});
  @override
  String toString() => 'HermesException($statusCode): $message';
}

class HermesService {
  HermesService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _sessionHeader = 'X-Hermes-Session-Id';

  final FlutterSecureStorage _storage;
  Dio? _dio;
  String? _cachedKey;
  String? _cachedBaseUrl;

  Future<String?> getApiKey() async {
    _cachedKey ??= await _storage.read(key: AppConstants.storageKeyApiKey);
    return _cachedKey;
  }

  Future<String> getBaseUrl() async {
    _cachedBaseUrl ??= await _storage.read(key: AppConstants.storageKeyBaseUrl);
    return _cachedBaseUrl?.isNotEmpty == true
        ? _cachedBaseUrl!
        : AppConstants.defaultBaseUrl;
  }

  Future<void> saveSettings({required String apiKey, String? baseUrl}) async {
    await _storage.write(
      key: AppConstants.storageKeyApiKey,
      value: apiKey,
    );
    await _storage.write(
      key: AppConstants.storageKeyBaseUrl,
      value: (baseUrl == null || baseUrl.isEmpty)
          ? AppConstants.defaultBaseUrl
          : baseUrl,
    );
    _cachedKey = apiKey;
    _cachedBaseUrl = baseUrl?.isEmpty == true ? null : baseUrl;
    _dio = null;
  }

  Future<void> clearSettings() async {
    await _storage.delete(key: AppConstants.storageKeyApiKey);
    await _storage.delete(key: AppConstants.storageKeyBaseUrl);
    _cachedKey = null;
    _cachedBaseUrl = null;
    _dio = null;
  }

  Future<bool> isConfigured() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  Future<Dio> _client() async {
    if (_dio != null) return _dio!;
    final key = await getApiKey();
    final baseUrl = await getBaseUrl();
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: AppConstants.requestTimeout,
        receiveTimeout: AppConstants.requestTimeout,
        sendTimeout: AppConstants.requestTimeout,
        headers: {
          if (key != null && key.isNotEmpty) 'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        },
      ),
    );
    _dio = dio;
    return dio;
  }

  Never _throw(DioException e) {
    final code = e.response?.statusCode;
    throw HermesException(_humanize(e), statusCode: code);
  }

  String _humanize(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Délai d\'attente dépassé. Vérifiez votre connexion ou l\'URL.';
      case DioExceptionType.connectionError:
        return 'Connexion impossible au serveur Hermes. Vérifiez l\'URL et le réseau.';
      case DioExceptionType.badCertificate:
        return 'Certificat SSL invalide.';
      case DioExceptionType.cancel:
        return 'Requête annulée.';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 401 || code == 403) {
          return 'Clé API refusée (HTTP $code). Vérifiez le Bearer token.';
        }
        if (code == 404) {
          return 'Endpoint introuvable (HTTP 404).';
        }
        if (code != null && code >= 500) {
          return 'Erreur serveur Hermes (HTTP $code).';
        }
        final body = e.response?.data;
        final detail = body is Map && body['error'] != null
            ? body['error'].toString()
            : body is Map && body['message'] != null
                ? body['message'].toString()
                : body is String
                    ? body
                    : null;
        return detail?.isNotEmpty == true
            ? 'Erreur HTTP $code : $detail'
            : 'Erreur HTTP $code';
      case DioExceptionType.unknown:
        return e.message ?? 'Erreur réseau inconnue.';
    }
  }

  Future<bool> health() async {
    try {
      final dio = await _client();
      final res = await dio.get(AppConstants.pathHealth);
      return res.statusCode != null && res.statusCode! < 400;
    } on DioException {
      return false;
    }
  }

  /// Soumet un run à `/v1/runs`.
  /// Le sessionId optionnel est passé via `X-Hermes-Session-Id` pour reprendre
  /// une conversation. Le retour `RunSubmission` contient le runId à utiliser
  /// pour le streaming SSE.
  Future<RunSubmission> submitRun(
    String input, {
    String? sessionId,
    String model = AppConstants.defaultModel,
  }) async {
    try {
      final dio = await _client();
      final res = await dio.post(
        AppConstants.pathRuns,
        data: {'model': model, 'input': input},
        options: Options(headers: _sessionHeaders(sessionId)),
      );
      final data = res.data;
      String? runId;
      String? returnedSession;
      String? status;
      if (data is Map) {
        runId = data['run_id'] as String? ??
            data['runId'] as String? ??
            data['id'] as String?;
        returnedSession = data['session_id'] as String? ??
            data['sessionId'] as String? ??
            data['hermes_session_id'] as String?;
        status = data['status'] as String?;
      }
      runId ??= _extractHeader(res.headers, 'x-hermes-run-id');
      returnedSession ??= _extractSessionId(res.headers);
      if (runId == null || runId.isEmpty) {
        throw HermesException('Run ID absent de la réponse');
      }
      // Si Hermes ne renvoie pas explicitement de session_id, on garde celui
      // qu'on avait (resume) ou on tombe sur le run_id pour avoir au moins un
      // identifiant local stable.
      returnedSession ??= sessionId ?? runId;
      return RunSubmission(
        runId: runId,
        sessionId: returnedSession,
        status: status,
      );
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Stream SSE des events d'un run via `GET /v1/runs/{runId}/events`.
  ///
  /// Sur Web, Dio bufferise la réponse XHR — on bypass via `dart:html`
  /// HttpRequest + `onProgress` pour avoir un streaming réel. Sur natif,
  /// Dio stream parfaitement, on garde son chemin.
  Stream<Map<String, dynamic>> streamRunEvents(String runId) async* {
    if (kIsWeb) {
      yield* _streamRunEventsWeb(runId);
      return;
    }
    yield* _streamRunEventsNative(runId);
  }

  Stream<Map<String, dynamic>> _streamRunEventsNative(String runId) async* {
    final dio = await _client();
    try {
      final response = await dio.get<ResponseBody>(
        '${AppConstants.pathRuns}/$runId/events',
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: AppConstants.streamTimeout,
          headers: {'Accept': 'text/event-stream'},
        ),
      );
      final body = response.data;
      if (body == null) return;
      final lines = body.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        final event = _parseSseLine(line);
        if (event == null) continue;
        if (event.isEmpty) return; // sentinel [DONE]
        yield event;
      }
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Stream<Map<String, dynamic>> _streamRunEventsWeb(String runId) async* {
    final baseUrl = await getBaseUrl();
    final key = await getApiKey();
    final url = '$baseUrl${AppConstants.pathRuns}/$runId/events';
    final headers = {
      if (key != null && key.isNotEmpty) 'Authorization': 'Bearer $key',
      'Accept': 'text/event-stream',
    };
    await for (final line in sse.sseStreamLines(url, headers)) {
      final event = _parseSseLine(line);
      if (event == null) continue;
      if (event.isEmpty) return; // sentinel [DONE]
      yield event;
    }
  }

  /// Parse une ligne SSE.
  /// - Renvoie `null` pour les lignes vides / commentaires / non-`data`
  /// - Renvoie un Map vide pour `[DONE]` (sentinel pour terminer)
  /// - Renvoie le Map JSON parsé sinon
  Map<String, dynamic>? _parseSseLine(String line) {
    if (line.isEmpty) return null;
    if (line.startsWith(':')) return null; // keep-alive / commentaire
    if (!line.startsWith('data:')) return null;
    final payload = line.substring(5).trim();
    if (payload.isEmpty) return null;
    if (payload == '[DONE]') return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  /// Arrête un run en cours.
  Future<void> stopRun(String runId) async {
    try {
      final dio = await _client();
      await dio.post('${AppConstants.pathRuns}/$runId/stop');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  // ---- helpers privés ----

  String? _extractHeader(Headers headers, String name) {
    return headers.value(name) ?? headers.value(name.toUpperCase());
  }

  Future<List<JobSummary>> listJobs() async {
    try {
      final dio = await _client();
      final res = await dio.get(AppConstants.pathJobs);
      return _parseList(res.data, JobSummary.fromJson);
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<JobSummary> getJob(String id) async {
    try {
      final dio = await _client();
      final res = await dio.get('${AppConstants.pathJobs}/$id');
      return _parseJob(res.data, 'détails');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<JobSummary> createJob(JobInput input) async {
    try {
      final dio = await _client();
      final res = await dio.post(AppConstants.pathJobs, data: input.toJson());
      return _parseJob(res.data, 'création');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<JobSummary> updateJob(String id, JobInput input) async {
    try {
      final dio = await _client();
      final res = await dio.patch(
        '${AppConstants.pathJobs}/$id',
        data: input.toJson(),
      );
      return _parseJob(res.data, 'mise à jour');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<void> deleteJob(String id) async {
    try {
      final dio = await _client();
      await dio.delete('${AppConstants.pathJobs}/$id');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<JobSummary> triggerJob(String id) async {
    try {
      final dio = await _client();
      final res = await dio.post('${AppConstants.pathJobs}/$id/run');
      return _parseJob(res.data, 'exécution');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<JobSummary> pauseJob(String id) async {
    try {
      final dio = await _client();
      final res = await dio.post('${AppConstants.pathJobs}/$id/pause');
      return _parseJob(res.data, 'pause');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<JobSummary> resumeJob(String id) async {
    try {
      final dio = await _client();
      final res = await dio.post('${AppConstants.pathJobs}/$id/resume');
      return _parseJob(res.data, 'reprise');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Parse une réponse de job — supporte `{"job": {...}}` (cas des actions
  /// pause/resume/run d'Hermes) ou un Map direct (création / GET).
  JobSummary _parseJob(dynamic data, String op) {
    if (data is Map) {
      final inner = data['job'];
      if (inner is Map) {
        return JobSummary.fromJson(Map<String, dynamic>.from(inner));
      }
      return JobSummary.fromJson(Map<String, dynamic>.from(data));
    }
    throw HermesException('Réponse de $op invalide');
  }

  Map<String, String> _sessionHeaders(String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) return const {};
    return {_sessionHeader: sessionId};
  }

  String? _extractSessionId(Headers headers) {
    return headers.value('x-hermes-session-id') ??
        headers.value('X-Hermes-Session-Id');
  }

  List<T> _parseList<T>(dynamic data, T Function(Map<String, dynamic>) build) {
    Iterable<dynamic>? items;
    if (data is List) items = data;
    if (data is Map) {
      for (final key in const ['data', 'items', 'jobs', 'responses', 'results']) {
        final v = data[key];
        if (v is List) {
          items = v;
          break;
        }
      }
    }
    if (items == null) return const [];
    return items
        .whereType<Map>()
        .map((m) => build(Map<String, dynamic>.from(m)))
        .toList();
  }
}
