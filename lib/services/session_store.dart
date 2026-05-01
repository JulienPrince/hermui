import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StoredTurn {
  StoredTurn({required this.role, required this.content});
  final String role;
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  static StoredTurn? fromJson(Map<String, dynamic> json) {
    final role = json['role'] as String?;
    final content = json['content'] as String?;
    if (role == null || content == null) return null;
    return StoredTurn(role: role, content: content);
  }
}

/// Métadonnées + tours d'une session conservés localement.
class LocalSession {
  LocalSession({
    required this.sessionId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.preview,
    this.turns = const [],
  });

  final String sessionId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? preview;
  final List<StoredTurn> turns;

  LocalSession copyWith({
    String? title,
    DateTime? updatedAt,
    String? preview,
    List<StoredTurn>? turns,
  }) {
    return LocalSession(
      sessionId: sessionId,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      preview: preview ?? this.preview,
      turns: turns ?? this.turns,
    );
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'preview': preview,
        'turns': turns.map((t) => t.toJson()).toList(),
      };

  static LocalSession? fromJson(Map<String, dynamic> json) {
    final id = json['sessionId'] as String?;
    if (id == null || id.isEmpty) return null;
    final rawTurns = json['turns'];
    final turns = <StoredTurn>[];
    if (rawTurns is List) {
      for (final t in rawTurns) {
        if (t is Map) {
          final st = StoredTurn.fromJson(Map<String, dynamic>.from(t));
          if (st != null) turns.add(st);
        }
      }
    }
    return LocalSession(
      sessionId: id,
      title: (json['title'] as String?) ?? 'Session',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      preview: json['preview'] as String?,
      turns: turns,
    );
  }
}

class SessionStore {
  SessionStore({Future<SharedPreferences>? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance();

  static const _sessionsKey = 'hermes_sessions_v2';
  static const _lastSessionIdKey = 'hermes_last_session_id';

  final Future<SharedPreferences> _prefs;

  Future<List<LocalSession>> list() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_sessionsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <LocalSession>[];
      for (final item in decoded) {
        if (item is Map) {
          final s = LocalSession.fromJson(Map<String, dynamic>.from(item));
          if (s != null) out.add(s);
        }
      }
      out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<LocalSession?> findById(String sessionId) async {
    final all = await list();
    for (final s in all) {
      if (s.sessionId == sessionId) return s;
    }
    return null;
  }

  Future<void> upsert(LocalSession session) async {
    final current = await list();
    final next = [
      session,
      ...current.where((s) => s.sessionId != session.sessionId),
    ];
    await _save(next);
  }

  Future<void> delete(String sessionId) async {
    final current = await list();
    final next = current.where((s) => s.sessionId != sessionId).toList();
    await _save(next);
    final lastId = await getLastSessionId();
    if (lastId == sessionId) await setLastSessionId(null);
  }

  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_sessionsKey);
    await prefs.remove(_lastSessionIdKey);
  }

  Future<String?> getLastSessionId() async {
    final prefs = await _prefs;
    return prefs.getString(_lastSessionIdKey);
  }

  Future<void> setLastSessionId(String? id) async {
    final prefs = await _prefs;
    if (id == null || id.isEmpty) {
      await prefs.remove(_lastSessionIdKey);
    } else {
      await prefs.setString(_lastSessionIdKey, id);
    }
  }

  Future<void> _save(List<LocalSession> sessions) async {
    final prefs = await _prefs;
    await prefs.setString(
      _sessionsKey,
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    );
  }
}
