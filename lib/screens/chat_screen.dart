import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/hermes_service.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import '../widgets/composer.dart';
import '../widgets/hermes_logo.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([List<ImageAttachment> images = const []]) async {
    final text = _input.text;
    if (text.trim().isEmpty && images.isEmpty) return;
    _input.clear();
    await ref
        .read(chatControllerProvider.notifier)
        .send(text, images: images);
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);

    return Scaffold(
      backgroundColor: HermesTokens.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _ChatHeader(),
            Expanded(
              child: chat.turns.isEmpty
                  ? (chat.sessionId != null
                      ? const _ResumedEmpty()
                      : _ChatEmpty(onSuggest: (text) {
                          _input.text = text;
                          _send();
                        }))
                  : Builder(
                      builder: (_) {
                        // ListView reverse:true → items rendus de bas en haut.
                        // Index 0 = dernier message (visible en bas), nouveau
                        // delta s'ancre naturellement au bas sans race
                        // condition avec le décodage async des images.
                        int? lastAssistantIdx;
                        for (var i = 0; i < chat.turns.length; i++) {
                          if (chat.turns[i].role == 'assistant') {
                            lastAssistantIdx = i;
                          }
                        }
                        final n = chat.turns.length;
                        return ListView.builder(
                          controller: _scroll,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: n,
                          itemBuilder: (_, idx) {
                            final i = n - 1 - idx;
                            final t = chat.turns[i];
                            if (t.role == 'user') {
                              return UserMessageBubble(
                                content: t.content,
                                images: t.images,
                              );
                            }
                            if (t.role == 'tool') {
                              return ToolMessageBubble(
                                tool: t.toolName ?? 'tool',
                                preview: t.content,
                              );
                            }
                            final canRetry = !chat.sending &&
                                !t.streaming &&
                                t.content.isNotEmpty &&
                                i == lastAssistantIdx;
                            return AssistantMessageBubble(
                              content: t.content,
                              streaming: t.streaming,
                              showActions: !t.streaming && t.content.isNotEmpty,
                              usage: t.usage,
                              onRetry: canRetry
                                  ? () => ref
                                      .read(chatControllerProvider.notifier)
                                      .regenerate()
                                  : null,
                            );
                          },
                        );
                      },
                    ),
            ),
            if (chat.error != null) _ErrorBanner(message: chat.error!),
            if (chat.sending && chat.runId != null)
              _StopButton(
                onStop: () =>
                    ref.read(chatControllerProvider.notifier).stop(),
              ),
            Composer(
              controller: _input,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends ConsumerWidget {
  const _ChatHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final chat = ref.watch(chatControllerProvider);
    final hasMessages = chat.turns.isNotEmpty;
    final hasSession = chat.sessionId != null;

    final title = chat.title?.isNotEmpty == true
        ? chat.title!
        : (hasMessages
            ? _firstUserText(chat.turns) ?? 'Conversation'
            : 'Nouveau fil');

    final subtitle = hasSession
        ? 'reprise · ${chat.sessionId}'
        : (settings.isConfigured ? 'connecté' : 'hors ligne');
    final subtitleDot = hasSession
        ? HermesTokens.accent
        : (settings.isConfigured
            ? HermesTokens.success
            : HermesTokens.textFaint);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      decoration: const Border(
        bottom: BorderSide(color: HermesTokens.border),
      ).toBoxDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HermesText.section(),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: subtitleDot,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: hasSession
                            ? HermesText.mono(
                                size: 11,
                                color: HermesTokens.textMuted,
                              )
                            : HermesText.caption(
                                color: HermesTokens.textMuted,
                              ).copyWith(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _PersonalityChip(personality: chat.personality, ref: ref),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Nouveau fil',
            onPressed: (hasMessages || hasSession)
                ? () => ref.read(chatControllerProvider.notifier).clear()
                : null,
            icon: const Icon(
              Icons.add_rounded,
              size: 18,
              color: HermesTokens.textDim,
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          _ActionsMenu(
            ref: ref,
            chat: chat,
            onAccount: () => _showAccountSheet(context, ref),
          ),
        ],
      ),
    );
  }

  String? _firstUserText(List<ChatTurn> turns) {
    for (final t in turns) {
      if (t.role == 'user') {
        return t.content.length > 36
            ? '${t.content.substring(0, 36)}…'
            : t.content;
      }
    }
    return null;
  }

  void _showAccountSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HermesTokens.surface1,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.85,
        child: _AccountSheet(),
      ),
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({
    required this.ref,
    required this.chat,
    required this.onAccount,
  });

  final WidgetRef ref;
  final ChatState chat;
  final VoidCallback onAccount;

  bool get _hasMessages => chat.turns.isNotEmpty;
  bool get _hasLastUser =>
      chat.turns.any((t) => t.role == 'user' && !t.streaming);
  bool get _canRetry =>
      !chat.sending &&
      _hasMessages &&
      chat.turns.any((t) => t.role == 'assistant' && !t.streaming);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      icon: const Icon(
        Icons.more_horiz_rounded,
        size: 18,
        color: HermesTokens.textDim,
      ),
      color: HermesTokens.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HermesTokens.rMd),
        side: const BorderSide(color: HermesTokens.border),
      ),
      onSelected: (v) async {
        final ctl = ref.read(chatControllerProvider.notifier);
        switch (v) {
          case 'rename':
            final newTitle = await _promptTitle(context, chat.title);
            if (newTitle != null) await ctl.setTitle(newTitle);
            break;
          case 'retry':
            await ctl.regenerate();
            break;
          case 'undo':
            await ctl.undoLast();
            break;
          case 'account':
            onAccount();
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'rename',
          enabled: _hasMessages,
          child: const _MenuRow(
            icon: Icons.edit_rounded,
            label: 'Renommer le fil',
          ),
        ),
        PopupMenuItem<String>(
          value: 'retry',
          enabled: _canRetry,
          child: const _MenuRow(
            icon: Icons.refresh_rounded,
            label: 'Régénérer la dernière réponse',
          ),
        ),
        PopupMenuItem<String>(
          value: 'undo',
          enabled: !chat.sending && _hasLastUser,
          child: const _MenuRow(
            icon: Icons.undo_rounded,
            label: 'Annuler le dernier échange',
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'account',
          child: _MenuRow(
            icon: Icons.account_circle_outlined,
            label: 'Compte & déconnexion',
          ),
        ),
      ],
    );
  }

  Future<String?> _promptTitle(BuildContext context, String? current) {
    final ctl = TextEditingController(text: current ?? '');
    return showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: HermesTokens.surface1,
        title: Text('Renommer le fil', style: HermesText.section()),
        content: TextField(
          controller: ctl,
          autofocus: true,
          cursorColor: HermesTokens.accent,
          style: HermesText.body(),
          decoration: InputDecoration(
            hintText: 'Nouveau titre',
            hintStyle: HermesText.body(color: HermesTokens.textMuted),
            filled: true,
            fillColor: HermesTokens.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HermesTokens.rMd),
              borderSide: const BorderSide(color: HermesTokens.border),
            ),
          ),
          onSubmitted: (v) => Navigator.of(dialogCtx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(ctl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: HermesTokens.textMuted),
        const SizedBox(width: 12),
        Text(label, style: HermesText.body()),
      ],
    );
  }
}

class _PersonalityChip extends StatelessWidget {
  const _PersonalityChip({required this.personality, required this.ref});

  final PersonalityPreset personality;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final isDefault = personality.id == 'default';
    return GestureDetector(
      onTap: () => _showSheet(context),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDefault ? HermesTokens.surface2 : HermesTokens.accentSoft,
          border: Border.all(
            color: isDefault ? HermesTokens.border : HermesTokens.accent,
          ),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(personality.icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Text(
              personality.label,
              style: HermesText.caption(
                color: isDefault ? HermesTokens.textDim : HermesTokens.accent,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: isDefault ? HermesTokens.textFaint : HermesTokens.accent,
            ),
          ],
        ),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HermesTokens.surface1,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Personnalité', style: HermesText.section()),
              const SizedBox(height: 4),
              Text(
                "Ajoute un overlay au system prompt côté serveur — l'agent "
                "garde mémoire et outils, le ton/format change.",
                style: HermesText.caption(color: HermesTokens.textMuted),
              ),
              const SizedBox(height: 12),
              for (final p in PersonalityPreset.presets)
                _PresetTile(
                  preset: p,
                  selected: p.id == personality.id,
                  onTap: () {
                    ref
                        .read(chatControllerProvider.notifier)
                        .setPersonality(p.id);
                    Navigator.of(sheetCtx).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final PersonalityPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HermesTokens.rMd),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: selected ? HermesTokens.accentSoft : HermesTokens.surface,
          border: Border.all(
            color: selected ? HermesTokens.accent : HermesTokens.border,
          ),
          borderRadius: BorderRadius.circular(HermesTokens.rMd),
        ),
        child: Row(
          children: [
            Text(preset.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    preset.label,
                    style: HermesText.body().copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? HermesTokens.accent
                          : HermesTokens.text,
                    ),
                  ),
                  if (preset.instruction != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      preset.instruction!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HermesText.caption(
                        color: HermesTokens.textMuted,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 2),
                    Text(
                      'Aucun overlay — utilise le SOUL.md serveur',
                      style: HermesText.caption(
                        color: HermesTokens.textFaint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.check_rounded,
                size: 18,
                color: HermesTokens.accent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet();

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  bool _eraseSessions = false;
  bool _busy = false;

  Capabilities? _capabilities;
  List<String>? _models;
  HealthSnapshot? _health;
  Timer? _healthTimer;
  bool _firstLoad = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll();
      _healthTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _refreshHealth(),
      );
    });
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    final svc = ref.read(hermesServiceProvider);
    final results = await Future.wait([
      svc.getCapabilities(),
      svc.listModels(),
      svc.healthDetailed(),
    ]);
    if (!mounted) return;
    setState(() {
      _capabilities = results[0] as Capabilities?;
      _models = results[1] as List<String>;
      _health = results[2] as HealthSnapshot;
      _firstLoad = false;
    });
  }

  Future<void> _refreshHealth() async {
    final svc = ref.read(hermesServiceProvider);
    final h = await svc.healthDetailed();
    if (!mounted) return;
    setState(() => _health = h);
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    _healthTimer?.cancel();
    final settingsCtl = ref.read(settingsProvider.notifier);
    final chatCtl = ref.read(chatControllerProvider.notifier);
    final store = ref.read(sessionStoreProvider);
    await chatCtl.reset();
    if (_eraseSessions) {
      await store.clear();
      ref.invalidate(sessionsProvider);
    }
    await settingsCtl.clear();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final masked = _maskKey(settings.apiKey);
    final modelName = (_models != null && _models!.isNotEmpty)
        ? _models!.first
        : null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Compte', style: HermesText.section()),
            const SizedBox(height: HermesTokens.s4),

            // ── Server ────────────────────────────────
            _SectionLabel('Serveur'),
            const SizedBox(height: 8),
            _HealthRow(
              health: _health,
              loading: _firstLoad && _health == null,
              onRefresh: _refreshHealth,
            ),
            const SizedBox(height: 8),
            _Row(
              icon: Icons.public_rounded,
              label: 'URL',
              value: settings.baseUrl.isEmpty ? '—' : settings.baseUrl,
            ),
            const SizedBox(height: 8),
            _Row(
              icon: Icons.dns_rounded,
              label: 'Plateforme',
              value: _capabilities == null
                  ? (_firstLoad ? '…' : 'inconnue')
                  : (_capabilities!.version != null
                      ? '${_capabilities!.platform} v${_capabilities!.version}'
                      : _capabilities!.platform),
            ),
            const SizedBox(height: HermesTokens.s4),

            // ── Agent ─────────────────────────────────
            _SectionLabel('Agent'),
            const SizedBox(height: 8),
            _Row(
              icon: Icons.smart_toy_rounded,
              label: 'Profil',
              value: modelName ?? (_firstLoad ? '…' : 'inconnu'),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                "Profil Hermes (config.yaml côté serveur). Le LLM réel "
                "(Gemini, GPT…) n'est pas exposé via l'API.",
                style: HermesText.caption(color: HermesTokens.textFaint),
              ),
            ),
            if (_capabilities != null && _capabilities!.features.isNotEmpty) ...[
              const SizedBox(height: 10),
              _CapabilityChips(features: _capabilities!.features),
            ],
            const SizedBox(height: HermesTokens.s4),

            // ── Auth ──────────────────────────────────
            _SectionLabel('Auth'),
            const SizedBox(height: 8),
            _Row(
              icon: Icons.key_rounded,
              label: 'Bearer',
              value: masked,
            ),
            const SizedBox(height: HermesTokens.s5),

            // ── Actions ───────────────────────────────
            InkWell(
              onTap: () => setState(() => _eraseSessions = !_eraseSessions),
              borderRadius: BorderRadius.circular(HermesTokens.rSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _eraseSessions
                            ? HermesTokens.accent
                            : Colors.transparent,
                        border: Border.all(
                          color: _eraseSessions
                              ? HermesTokens.accent
                              : HermesTokens.borderStrong,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: _eraseSessions
                          ? const Icon(
                              Icons.check_rounded,
                              size: 12,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Effacer aussi l'historique local",
                        style: HermesText.bodySm(color: HermesTokens.textDim),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: HermesTokens.s4),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: _busy ? null : _logout,
                style: FilledButton.styleFrom(
                  backgroundColor: HermesTokens.errorSoft,
                  foregroundColor: HermesTokens.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(HermesTokens.rMd),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: HermesTokens.error,
                        ),
                      )
                    : Text(
                        'Déconnecter',
                        style: HermesText.body(color: HermesTokens.error)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Le token sera retiré du keychain — l'écran Setup s'affichera.",
              style: HermesText.caption(color: HermesTokens.textFaint),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _maskKey(String? key) {
    if (key == null || key.isEmpty) return '—';
    if (key.length <= 8) return '••••${key.substring(key.length - 2)}';
    return '${key.substring(0, 4)}••••${key.substring(key.length - 4)}';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: HermesText.caption(color: HermesTokens.textFaint).copyWith(
        fontSize: 10,
        letterSpacing: 1.0,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.health,
    required this.loading,
    required this.onRefresh,
  });

  final HealthSnapshot? health;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final reachable = health?.reachable ?? false;
    final dotColor = loading
        ? HermesTokens.textFaint
        : (reachable ? HermesTokens.success : HermesTokens.error);
    final label = loading
        ? 'Vérification…'
        : (reachable ? 'En ligne' : 'Injoignable');

    final stats = <String>[];
    if (health?.latency != null) {
      stats.add('${health!.latency!.inMilliseconds} ms');
    }
    if (health?.activeSessions != null) {
      stats.add('${health!.activeSessions} sessions');
    }
    if (health?.runningAgents != null) {
      stats.add('${health!.runningAgents} agents');
    }
    if (health?.memMb != null) {
      stats.add('${health!.memMb!.toStringAsFixed(0)} MB');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: HermesTokens.surface,
        border: Border.all(color: HermesTokens.border),
        borderRadius: BorderRadius.circular(HermesTokens.rMd),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: HermesText.body().copyWith(fontWeight: FontWeight.w600),
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                stats.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: HermesText.mono(
                  size: 11,
                  color: HermesTokens.textMuted,
                ),
              ),
            ),
          ] else
            const Spacer(),
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: onRefresh,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 16,
              color: HermesTokens.textMuted,
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _CapabilityChips extends StatelessWidget {
  const _CapabilityChips({required this.features});
  final Map<String, bool> features;

  @override
  Widget build(BuildContext context) {
    final entries = features.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in entries)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: e.value
                  ? HermesTokens.accentSoft
                  : HermesTokens.surface2,
              border: Border.all(
                color: e.value
                    ? HermesTokens.accent
                    : HermesTokens.border,
              ),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              e.key.replaceAll('_', ' '),
              style: HermesText.mono(
                size: 10,
                color: e.value
                    ? HermesTokens.accent
                    : HermesTokens.textFaint,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: HermesTokens.surface,
        border: Border.all(color: HermesTokens.border),
        borderRadius: BorderRadius.circular(HermesTokens.rMd),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: HermesTokens.textMuted),
          const SizedBox(width: 10),
          Text(
            label,
            style: HermesText.caption(color: HermesTokens.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: HermesText.mono(size: 12, color: HermesTokens.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatEmpty extends StatelessWidget {
  const _ChatEmpty({required this.onSuggest});

  final void Function(String) onSuggest;

  static const _suggestions = <_Suggestion>[
    _Suggestion(
      icon: Icons.inbox_outlined,
      label: 'Résumer mes Teams non lus',
    ),
    _Suggestion(
      icon: Icons.terminal_rounded,
      label: 'Lancer une session Claude Code',
    ),
    _Suggestion(
      icon: Icons.description_outlined,
      label: 'Indexer la note du jour',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: HermesTokens.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HermesLogoOutline(size: 44),
            const SizedBox(height: HermesTokens.s4),
            Text('hermui écoute.', style: HermesText.title()),
            const SizedBox(height: 6),
            Text(
              'Demande quelque chose, ou prends un raccourci.',
              style: HermesText.bodySm(color: HermesTokens.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HermesTokens.s5),
            for (final s in _suggestions) ...[
              _SuggestionTile(
                suggestion: s,
                onTap: () => onSuggest(s.label),
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _Suggestion {
  const _Suggestion({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.suggestion, required this.onTap});

  final _Suggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HermesTokens.rMd),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: HermesTokens.surface1,
          border: Border.all(color: HermesTokens.border),
          borderRadius: BorderRadius.circular(HermesTokens.rMd),
        ),
        child: Row(
          children: [
            Icon(suggestion.icon, size: 16, color: HermesTokens.textDim),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                suggestion.label,
                style: HermesText.body().copyWith(fontSize: 14),
              ),
            ),
            const Text(
              '↗',
              style: TextStyle(color: HermesTokens.textFaint, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumedEmpty extends StatelessWidget {
  const _ResumedEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: HermesTokens.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: HermesTokens.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: HermesTokens.accent,
              ),
            ),
            const SizedBox(height: HermesTokens.s4),
            Text('Session reprise.', style: HermesText.title()),
            const SizedBox(height: 6),
            Text(
              "hermui garde le contexte côté serveur — continue où tu t'étais arrêté.",
              style: HermesText.bodySm(color: HermesTokens.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({required this.onStop});
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Center(
        child: GestureDetector(
          onTap: onStop,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: HermesTokens.errorSoft,
              border: Border.all(color: HermesTokens.error.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(HermesTokens.rFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: HermesTokens.error,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Arrêter',
                  style: HermesText.caption(color: HermesTokens.error)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HermesTokens.errorSoft,
        border: Border.all(color: HermesTokens.error.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(HermesTokens.rMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 16,
            color: HermesTokens.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: HermesText.bodySm(color: HermesTokens.textDim),
            ),
          ),
        ],
      ),
    );
  }
}

extension on Border {
  BoxDecoration toBoxDecoration() => BoxDecoration(border: this);
}
