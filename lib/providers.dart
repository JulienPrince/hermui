import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'config/constants.dart';
import 'services/hermes_service.dart';
import 'services/notifications.dart';
import 'services/session_store.dart';

const _uuid = Uuid();

class _QueuedMessage {
  const _QueuedMessage(this.text, this.images);
  final String text;
  final List<ImageAttachment> images;
}

/// Preset de personnalité — label affiché + overlay system prompt envoyé
/// dans le champ `instructions` (Hermes Agent layer ça au-dessus du SOUL.md
/// serveur, sans casser les outils ni la mémoire). `instruction == null` →
/// pas d'overlay (= personnalité serveur par défaut).
class PersonalityPreset {
  const PersonalityPreset({
    required this.id,
    required this.label,
    required this.icon,
    required this.instruction,
  });

  final String id;
  final String label;
  final String icon;
  final String? instruction;

  static const defaultPreset = PersonalityPreset(
    id: 'default',
    label: 'Par défaut',
    icon: '✨',
    instruction: null,
  );

  static const presets = <PersonalityPreset>[
    defaultPreset,
    PersonalityPreset(
      id: 'concise',
      label: 'Concis',
      icon: '⚡',
      instruction:
          'Réponds de façon concise et directe. Pas de préambule, pas de '
          'résumé final. Va droit au point en 1-3 phrases sauf si la question '
          'demande explicitement un développement.',
    ),
    PersonalityPreset(
      id: 'technique',
      label: 'Technique',
      icon: '🔧',
      instruction:
          'Réponds en technicien expert. Utilise la terminologie précise du '
          'domaine, cite les détails d\'implémentation, mentionne les '
          'trade-offs et les pièges. Bloc de code quand pertinent.',
    ),
    PersonalityPreset(
      id: 'prof',
      label: 'Prof',
      icon: '🎓',
      instruction:
          'Explique pédagogiquement avec une analogie, un exemple concret, '
          'puis une synthèse. Décompose les concepts complexes en étapes '
          'simples. Anticipe les confusions courantes.',
    ),
    PersonalityPreset(
      id: 'chill',
      label: 'Détendu',
      icon: '🌴',
      instruction:
          'Adopte un ton décontracté, conversationnel. Pas de formalisme. '
          'Vouvoiement banni, tu directement.',
    ),
  ];

  static PersonalityPreset byId(String? id) {
    if (id == null) return defaultPreset;
    return presets.firstWhere(
      (p) => p.id == id,
      orElse: () => defaultPreset,
    );
  }
}

final hermesServiceProvider = Provider<HermesService>((ref) => HermesService());

/// Capabilities du backend — fetched une fois quand on est configuré, cachée
/// pour la durée de l'app. Invalidé au logout (via clear settings).
///
/// Null = pas encore tenté ou serveur ne supporte pas `/v1/capabilities`.
/// Les features non listées sont considérées présentes par défaut (back-compat
/// avec les Hermes anciens qui n'exposaient pas l'endpoint).
final capabilitiesProvider = FutureProvider<Capabilities?>((ref) async {
  final settings = ref.watch(settingsProvider);
  if (!settings.isConfigured) return null;
  return ref.read(hermesServiceProvider).getCapabilities();
});

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

/// Liste des sessions locales — ré-évaluée chaque fois qu'on save / delete.
final sessionsProvider =
    AsyncNotifierProvider<SessionsController, List<LocalSession>>(
  SessionsController.new,
);

class SessionsController extends AsyncNotifier<List<LocalSession>> {
  @override
  Future<List<LocalSession>> build() async {
    return ref.watch(sessionStoreProvider).list();
  }

  Future<void> upsert(LocalSession session) async {
    await ref.read(sessionStoreProvider).upsert(session);
    ref.invalidateSelf();
  }

  Future<void> delete(String sessionId) async {
    await ref.read(sessionStoreProvider).delete(sessionId);
    ref.invalidateSelf();
  }
}

/// État settings — chargé une fois depuis secure storage.
class Settings {
  final String? apiKey;
  final String baseUrl;
  final bool ready;

  const Settings({this.apiKey, required this.baseUrl, this.ready = false});

  bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;

  Settings copyWith({String? apiKey, String? baseUrl, bool? ready}) => Settings(
        apiKey: apiKey ?? this.apiKey,
        baseUrl: baseUrl ?? this.baseUrl,
        ready: ready ?? this.ready,
      );
}

class SettingsController extends StateNotifier<Settings> {
  SettingsController(this._service)
      : super(const Settings(baseUrl: AppConstants.defaultBaseUrl)) {
    load();
  }

  final HermesService _service;

  Future<void> load() async {
    final key = await _service.getApiKey();
    final url = await _service.getBaseUrl();
    state = Settings(apiKey: key, baseUrl: url, ready: true);
  }

  Future<void> save({required String apiKey, required String baseUrl}) async {
    await _service.saveSettings(apiKey: apiKey, baseUrl: baseUrl);
    state = Settings(apiKey: apiKey, baseUrl: baseUrl, ready: true);
  }

  Future<void> clear() async {
    await _service.clearSettings();
    state = const Settings(
      baseUrl: AppConstants.defaultBaseUrl,
      ready: true,
    );
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsController, Settings>((ref) {
  return SettingsController(ref.watch(hermesServiceProvider));
});

/// Liste des jobs — toujours en vie (pas autoDispose) pour que le polling
/// intelligent continue même quand l'utilisateur n'est pas sur l'onglet Jobs.
///
/// Polling :
/// - Timer one-shot jusqu'à `next_run_at` du job le plus proche
/// - Une fois proche, polling toutes les 5 s
/// - Polling stoppe dès que `last_run_at` change sur un job
/// - Recalcule et reprogramme à chaque transition
class JobsController extends AsyncNotifier<List<JobSummary>> {
  Timer? _timer;

  // Garde-fous : on ne dort jamais plus de [_maxWait] ni ne poll plus de
  // [_maxIntensive]. Si `next_run_at` est dans le passé sans avancer, on
  // bascule sur un refresh distant au lieu de marteler.
  static const _maxWait = Duration(minutes: 30);
  static const _intensiveLead = Duration(seconds: 30);
  static const _intensivePeriod = Duration(seconds: 5);
  static const _maxIntensive = Duration(seconds: 60);
  static const _stalePastTolerance = Duration(minutes: 1);

  @override
  Future<List<JobSummary>> build() async {
    ref.onDispose(_cancelTimer);
    final jobs = await ref.read(hermesServiceProvider).listJobs();
    _scheduleNextPoll(jobs);
    return jobs;
  }

  void replace(JobSummary updated) {
    final current = state.valueOrNull;
    if (current == null) return;
    final next = [
      for (final j in current) j.id == updated.id ? updated : j,
    ];
    state = AsyncData(next);
    _scheduleNextPoll(next);
  }

  void remove(String id) {
    final current = state.valueOrNull;
    if (current == null) return;
    final next = current.where((j) => j.id != id).toList();
    state = AsyncData(next);
    _scheduleNextPoll(next);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(hermesServiceProvider).listJobs(),
    );
    state = result;
    _scheduleNextPoll(result.valueOrNull ?? const []);
  }

  // ---- Polling logic ----

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Trouve le `next_run_at` minimum parmi les jobs non-paused.
  DateTime? _earliestNextRun(List<JobSummary> jobs, DateTime now) {
    DateTime? earliest;
    for (final j in jobs) {
      if (j.enabled == false) continue;
      final nr = j.nextRun;
      if (nr == null) continue;
      // Si déjà passé, on considère comme imminent.
      if (earliest == null || nr.isBefore(earliest)) {
        earliest = nr;
      }
    }
    return earliest;
  }

  void _scheduleNextPoll(List<JobSummary> jobs) {
    _cancelTimer();
    final now = DateTime.now();
    final earliest = _earliestNextRun(jobs, now);
    if (earliest == null) return;

    final delay = earliest.difference(now);

    // Si l'échéance est passée depuis plus d'1 min, le serveur n'a pas avancé
    // le schedule (typiquement parce que le job tourne via la Runs API et ne
    // touche pas next_run_at). On évite le polling intensif perpétuel et on
    // se contente d'un refresh dans 60 s au cas où.
    if (delay.isNegative && delay.abs() > _stalePastTolerance) {
      _timer = Timer(const Duration(seconds: 60), refresh);
      return;
    }

    if (delay <= _intensiveLead) {
      _startIntensivePoll();
      return;
    }

    final target = delay - _intensiveLead;
    final waitFor = target > _maxWait ? _maxWait : target;
    _timer = Timer(waitFor, refresh);
  }

  void _startIntensivePoll() {
    final startedAt = DateTime.now();
    // Snapshot multi-champs : on s'arrête au moindre changement utile, pas
    // seulement quand last_run_at est mis à jour (Hermes n'écrit pas toujours
    // ce champ).
    final snapshot = <String, _JobSig>{
      for (final j in state.valueOrNull ?? const [])
        j.id: _JobSig.from(j),
    };

    _timer = Timer.periodic(_intensivePeriod, (_) async {
      if (DateTime.now().difference(startedAt) > _maxIntensive) {
        _cancelTimer();
        await refresh();
        return;
      }

      try {
        final fresh = await ref.read(hermesServiceProvider).listJobs();
        state = AsyncData(fresh);

        // On notifie pour chaque job existant qui a changé. Les jobs
        // nouveaux (pas dans le snapshot) ne déclenchent pas de notif —
        // c'est probablement une création utilisateur.
        for (final j in fresh) {
          final old = snapshot[j.id];
          if (old == null) continue;
          final newSig = _JobSig.from(j);
          if (newSig != old) {
            _notifyJobChanged(j, old, newSig);
          }
        }

        final changed = fresh.any((j) {
          final old = snapshot[j.id];
          return old != null && _JobSig.from(j) != old;
        });
        if (changed) {
          _cancelTimer();
          _scheduleNextPoll(fresh);
        }
      } catch (_) {
        // Erreur transitoire — on continue.
      }
    });
  }

  void _notifyJobChanged(JobSummary job, _JobSig before, _JobSig after) {
    // Échec → erreur visible
    if (after.lastResult != before.lastResult &&
        after.lastResult != null &&
        after.lastResult!.isNotEmpty) {
      final isError = after.status?.toLowerCase() == 'failed' ||
          after.lastResult!.toLowerCase().contains('error');
      NotificationsService.instance.notify(
        title: job.name,
        body: after.lastResult,
        emoji: isError ? '❌' : '✅',
      );
      return;
    }
    // last_run_at avancé sans message d'erreur → run terminé OK
    if (after.lastRun != before.lastRun && after.lastRun != null) {
      NotificationsService.instance.notify(
        title: job.name,
        body: 'Run terminé',
        emoji: '✅',
      );
      return;
    }
    // Statut a bougé (paused / scheduled / running) → on signale plus
    // discrètement.
    if (after.status != before.status && after.status != null) {
      NotificationsService.instance.notify(
        title: job.name,
        body: 'Statut : ${after.status}',
        emoji: '🔄',
      );
    }
  }
}

/// Signature comparable d'un job pour détecter qu'il s'est passé quelque chose
/// (run terminé, schedule décalé, statut changé) sans avoir à comparer le Map
/// brut entier.
class _JobSig {
  const _JobSig({
    required this.lastRun,
    required this.nextRun,
    required this.status,
    required this.lastResult,
  });

  static _JobSig from(JobSummary j) => _JobSig(
        lastRun: j.lastRun,
        nextRun: j.nextRun,
        status: j.status,
        lastResult: j.lastResult,
      );

  final DateTime? lastRun;
  final DateTime? nextRun;
  final String? status;
  final String? lastResult;

  @override
  bool operator ==(Object other) =>
      other is _JobSig &&
      other.lastRun == lastRun &&
      other.nextRun == nextRun &&
      other.status == status &&
      other.lastResult == lastResult;

  @override
  int get hashCode => Object.hash(lastRun, nextRun, status, lastResult);
}

final jobsProvider =
    AsyncNotifierProvider<JobsController, List<JobSummary>>(
  JobsController.new,
);

/// Un message ou un événement tool dans la conversation.
/// `role` : `user`, `assistant`, ou `tool`.
class ChatTurn {
  final String role;
  final String content;
  final bool streaming;
  final String? toolName; // si role == 'tool'
  final TokenUsage? usage; // si role == 'assistant' et run terminé
  /// Pièces jointes images du tour utilisateur — en mémoire seulement, pas
  /// persistées (les data URLs sont volumineux).
  final List<ImageAttachment> images;

  const ChatTurn({
    required this.role,
    required this.content,
    this.streaming = false,
    this.toolName,
    this.usage,
    this.images = const [],
  });

  ChatTurn copyWith({
    String? content,
    bool? streaming,
    String? toolName,
    TokenUsage? usage,
    List<ImageAttachment>? images,
  }) =>
      ChatTurn(
        role: role,
        content: content ?? this.content,
        streaming: streaming ?? this.streaming,
        toolName: toolName ?? this.toolName,
        usage: usage ?? this.usage,
        images: images ?? this.images,
      );
}

class ChatState {
  final List<ChatTurn> turns;
  final bool sending;
  final String? error;
  final String? sessionId;
  final String? runId; // run actif en cours de streaming
  final String? title;
  final String personalityId;

  const ChatState({
    this.turns = const [],
    this.sending = false,
    this.error,
    this.sessionId,
    this.runId,
    this.title,
    this.personalityId = 'default',
  });

  PersonalityPreset get personality =>
      PersonalityPreset.byId(personalityId);

  ChatState copyWith({
    List<ChatTurn>? turns,
    bool? sending,
    Object? error = _sentinel,
    Object? sessionId = _sentinel,
    Object? runId = _sentinel,
    Object? title = _sentinel,
    String? personalityId,
  }) =>
      ChatState(
        turns: turns ?? this.turns,
        sending: sending ?? this.sending,
        error: identical(error, _sentinel) ? this.error : error as String?,
        sessionId: identical(sessionId, _sentinel)
            ? this.sessionId
            : sessionId as String?,
        runId: identical(runId, _sentinel) ? this.runId : runId as String?,
        title: identical(title, _sentinel) ? this.title : title as String?,
        personalityId: personalityId ?? this.personalityId,
      );

  static const _sentinel = Object();
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._service, this._ref) : super(const ChatState()) {
    _restore();
  }

  final HermesService _service;
  final Ref _ref;

  /// Messages saisis pendant qu'un run est en cours — drainés en série dès que
  /// le run actif termine, dans l'ordre d'ajout.
  final List<_QueuedMessage> _pendingQueue = [];

  /// Dernier `response_id` renvoyé par la Responses API — sert à chaîner via
  /// `previous_response_id` pour les runs multimodaux successifs. Reset au
  /// nouveau fil / logout.
  String? _lastResponseId;

  /// Restaure la dernière session active (turns + sessionId) après reload.
  Future<void> _restore() async {
    final store = _ref.read(sessionStoreProvider);
    final lastId = await store.getLastSessionId();
    if (lastId == null) return;
    final session = await store.findById(lastId);
    if (session == null) return;
    state = ChatState(
      sessionId: session.sessionId,
      title: session.title,
      turns: session.turns
          .map((t) => ChatTurn(role: t.role, content: t.content))
          .toList(),
    );
  }

  /// Reprend une session depuis l'historique. Charge les turns persistés.
  Future<void> loadSession(LocalSession session) async {
    state = ChatState(
      sessionId: session.sessionId,
      title: session.title,
      turns: session.turns
          .map((t) => ChatTurn(role: t.role, content: t.content))
          .toList(),
    );
    await _ref.read(sessionStoreProvider).setLastSessionId(session.sessionId);
  }

  /// Démarre une nouvelle conversation — le prochain envoi créera une session.
  Future<void> clear() async {
    _pendingQueue.clear();
    _lastResponseId = null;
    state = const ChatState();
    await _ref.read(sessionStoreProvider).setLastSessionId(null);
  }

  /// Efface tout — appelé sur logout.
  Future<void> reset() async {
    _pendingQueue.clear();
    _lastResponseId = null;
    state = const ChatState();
  }

  /// Envoie un message. Si un run est déjà en cours, le message est mis en
  /// queue et la bulle utilisateur affichée immédiatement — il sera envoyé
  /// dès que le run actif termine.
  Future<void> send(String text, {List<ImageAttachment> images = const []}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && images.isEmpty) return;

    if (state.sending) {
      _pendingQueue.add(_QueuedMessage(trimmed, images));
      state = state.copyWith(
        turns: [
          ...state.turns,
          ChatTurn(role: 'user', content: trimmed, images: images),
        ],
      );
      return;
    }

    await _runOne(trimmed, images: images, addUserTurn: true);
    while (_pendingQueue.isNotEmpty) {
      final next = _pendingQueue.removeAt(0);
      // La bulle utilisateur a déjà été ajoutée au moment du queue —
      // on n'en remet pas.
      await _runOne(next.text, images: next.images, addUserTurn: false);
    }
  }

  /// Bascule la personnalité active. Persiste pour tous les runs suivants
  /// dans la session courante. `id == "default"` retire l'overlay.
  void setPersonality(String id) {
    state = state.copyWith(personalityId: id);
  }

  /// Renomme le fil courant côté local. (Côté serveur, la Runs API n'expose
  /// pas /title — purement local pour l'instant.)
  Future<void> setTitle(String title) async {
    final cleaned = title.trim();
    if (cleaned.isEmpty) return;
    state = state.copyWith(title: cleaned);
    final id = state.sessionId;
    if (id == null) return;
    final store = _ref.read(sessionStoreProvider);
    final existing = await store.findById(id);
    if (existing == null) return;
    await store.upsert(existing.copyWith(title: cleaned));
    _ref.invalidate(sessionsProvider);
  }

  /// Annule la dernière paire (user → assistant). Pas d'aller-retour serveur :
  /// purement client-side. Persiste la session sans les turns retirés.
  Future<void> undoLast() async {
    if (state.sending) return;
    final turns = [...state.turns];
    // Tronque les tool/assistant turns qui suivent le dernier user.
    while (turns.isNotEmpty && turns.last.role != 'user') {
      turns.removeLast();
    }
    if (turns.isEmpty) return;
    // Retire aussi le dernier user.
    turns.removeLast();
    state = state.copyWith(turns: turns);
    // Persiste la session courante (ou supprime si vide).
    final id = state.sessionId;
    if (id == null) return;
    final store = _ref.read(sessionStoreProvider);
    if (turns.isEmpty) {
      await store.delete(id);
      state = state.copyWith(sessionId: null, title: null);
    } else {
      final existing = await store.findById(id);
      if (existing != null) {
        final stored = turns
            .where((t) => !t.streaming && t.content.isNotEmpty)
            .map((t) => StoredTurn(role: t.role, content: t.content))
            .toList();
        await store.upsert(existing.copyWith(turns: stored));
      }
    }
    _ref.invalidate(sessionsProvider);
  }

  /// Ré-exécute le dernier prompt utilisateur. Disponible quand aucun run
  /// n'est en cours et qu'au moins un échange a déjà eu lieu.
  Future<void> regenerate() async {
    if (state.sending) return;
    final turns = [...state.turns];
    // Tronque tout ce qui suit le dernier message utilisateur (assistant +
    // tool turns du tour précédent).
    while (turns.isNotEmpty && turns.last.role != 'user') {
      turns.removeLast();
    }
    if (turns.isEmpty) return;
    final lastUser = turns.removeLast();
    state = state.copyWith(turns: turns);
    await _runOne(
      lastUser.content,
      images: lastUser.images,
      addUserTurn: true,
    );
  }

  Future<void> _runOne(
    String trimmed, {
    required bool addUserTurn,
    List<ImageAttachment> images = const [],
  }) async {
    final tentativeTitle = state.title ??
        _previewTitle(trimmed.isEmpty ? '📎 image' : trimmed);
    final next = [...state.turns];
    if (addUserTurn) {
      next.add(ChatTurn(role: 'user', content: trimmed, images: images));
    }
    next.add(const ChatTurn(role: 'assistant', content: '', streaming: true));
    state = state.copyWith(
      turns: next,
      sending: true,
      error: null,
      title: tentativeTitle,
    );

    // UUIDv4 par tap envoi → si retry réseau, le serveur dédupe (cache 5 min).
    // Réutilisé tel quel par regenerate() sur le même tour utilisateur.
    final idempotencyKey = _uuid.v4();
    final instructions = state.personality.instruction;
    try {
      if (images.isEmpty) {
        final submission = await _service.submitRun(
          trimmed,
          sessionId: state.sessionId,
          idempotencyKey: idempotencyKey,
          instructions: instructions,
        );
        final runId = submission.runId;
        state = state.copyWith(
          runId: runId,
          sessionId: submission.sessionId ?? state.sessionId,
        );
        await for (final event in _service.streamRunEvents(runId)) {
          _handleEvent(event);
        }
      } else {
        // Path Responses API : pas de runId → bouton Stop masqué (pas de
        // /stop natif, on coupe la connexion en fermant la sub côté natif
        // si besoin un jour).
        state = state.copyWith(runId: null);
        await for (final event in _service.streamResponses(
          input: trimmed,
          images: images,
          previousResponseId: _lastResponseId,
          idempotencyKey: idempotencyKey,
          instructions: instructions,
        )) {
          _handleEvent(event);
          final rid = event['response_id'] as String?;
          if (rid != null && rid.isNotEmpty) _lastResponseId = rid;
        }
      }
      _finalizeStreaming();
    } catch (e) {
      final updated = [...state.turns];
      if (updated.isNotEmpty &&
          updated.last.streaming &&
          updated.last.content.isEmpty) {
        updated.removeLast();
      } else if (updated.isNotEmpty && updated.last.streaming) {
        updated[updated.length - 1] =
            updated.last.copyWith(streaming: false);
      }
      state = state.copyWith(
        turns: updated,
        sending: false,
        runId: null,
        error: e is HermesException ? e.message : e.toString(),
      );
      _pendingQueue.clear();
      return;
    }

    state = state.copyWith(sending: false, runId: null);
    await _persistSession(state.sessionId, tentativeTitle);
  }

  void _handleEvent(Map<String, dynamic> event) {
    // Certains events Hermes contiennent un session_id — on l'absorbe sans
    // condition pour ne pas le rater (pas tous les serveurs le mettent dans
    // la réponse HTTP de POST /v1/runs).
    final embeddedSession = event['session_id'] as String? ??
        event['sessionId'] as String? ??
        event['hermes_session_id'] as String?;
    if (embeddedSession != null &&
        embeddedSession.isNotEmpty &&
        state.sessionId != embeddedSession) {
      state = state.copyWith(sessionId: embeddedSession);
    }

    final kind = event['event'] as String? ?? '';
    switch (kind) {
      case 'message.delta':
        final delta = event['delta'] as String? ?? '';
        if (delta.isEmpty) return;
        _appendAssistantDelta(delta);
        break;

      case 'reasoning.available':
        // Pas affiché en v1 — peut être ajouté plus tard comme bloc
        // expansible.
        break;

      case 'tool.started':
      case 'hermes.tool.progress': // alias historique
        final tool = event['tool'] as String? ?? 'tool';
        final preview = event['preview'] as String? ?? '';
        _pushToolTurn(tool, preview);
        break;

      case 'tool.completed':
        // Mark tool en cours comme terminé. Pour l'instant on ne change pas
        // le rendu — le tool reste affiché en italique. Future H-100 v2 :
        // afficher la duration et l'état error/success.
        break;

      case 'run.completed':
        final usage = TokenUsage.fromJson(event['usage']);
        final output = event['output'] as String?;
        _finalizeStreaming(finalContent: output, usage: usage);
        break;

      case 'run.failed':
      case 'run.error':
        final msg = event['error'] as String? ?? 'Run en erreur';
        state = state.copyWith(error: msg);
        _finalizeStreaming();
        break;

      default:
        // Event inconnu — silence
        break;
    }
  }

  void _appendAssistantDelta(String delta) {
    final turns = [...state.turns];
    if (turns.isEmpty || turns.last.role != 'assistant' || !turns.last.streaming) {
      // Crée une nouvelle bulle assistant streaming (cas après un tool).
      turns.add(ChatTurn(role: 'assistant', content: delta, streaming: true));
    } else {
      turns[turns.length - 1] = turns.last.copyWith(
        content: turns.last.content + delta,
      );
    }
    state = state.copyWith(turns: turns);
  }

  void _pushToolTurn(String tool, String preview) {
    final turns = [...state.turns];
    // Finalise l'assistant en cours s'il existe pour que l'ordre reste lisible.
    if (turns.isNotEmpty && turns.last.streaming && turns.last.role == 'assistant') {
      turns[turns.length - 1] = turns.last.copyWith(streaming: false);
    }
    turns.add(ChatTurn(
      role: 'tool',
      content: preview,
      toolName: tool,
    ));
    state = state.copyWith(turns: turns);
  }

  void _finalizeStreaming({String? finalContent, TokenUsage? usage}) {
    final turns = [...state.turns];
    if (turns.isEmpty) return;
    // Trouve la dernière bulle assistant et la finalise.
    for (var i = turns.length - 1; i >= 0; i--) {
      if (turns[i].role == 'assistant') {
        turns[i] = turns[i].copyWith(
          content: finalContent ?? turns[i].content,
          streaming: false,
          usage: usage,
        );
        break;
      }
    }
    state = state.copyWith(turns: turns);
  }

  /// Stoppe le run en cours côté serveur.
  Future<void> stop() async {
    final runId = state.runId;
    if (runId == null) return;
    try {
      await _service.stopRun(runId);
    } catch (_) {
      // best-effort — l'event run.completed/failed clora le stream
    }
  }

  Future<void> _persistSession(String? id, String tentativeTitle) async {
    if (id == null) return;
    final lastAssistant = state.turns.lastWhere(
      (t) => t.role == 'assistant' && t.content.isNotEmpty,
      orElse: () => const ChatTurn(role: 'assistant', content: ''),
    );
    final preview = _preview(lastAssistant.content);
    final now = DateTime.now();
    final store = _ref.read(sessionStoreProvider);
    final existing = await store.findById(id);
    final turns = state.turns
        .where((t) => !t.streaming && t.content.isNotEmpty)
        .map((t) => StoredTurn(role: t.role, content: t.content))
        .toList();
    final session = existing != null
        ? existing.copyWith(
            updatedAt: now,
            preview: preview,
            turns: turns,
            title: state.title ?? existing.title,
          )
        : LocalSession(
            sessionId: id,
            title: state.title ?? tentativeTitle,
            createdAt: now,
            updatedAt: now,
            preview: preview,
            turns: turns,
          );
    await store.upsert(session);
    await store.setLastSessionId(id);
    _ref.invalidate(sessionsProvider);
  }

  String _previewTitle(String text) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= 48) return cleaned;
    return '${cleaned.substring(0, 47)}…';
  }

  String _preview(String text) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= 140) return cleaned;
    return '${cleaned.substring(0, 139)}…';
  }
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(ref.watch(hermesServiceProvider), ref);
});
