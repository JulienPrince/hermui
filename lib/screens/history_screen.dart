import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../router.dart';
import '../services/session_store.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _queryController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _queryController.addListener(() {
      setState(() => _query = _queryController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sessionsProvider);
    final allItems = async.value ?? const <LocalSession>[];
    final filtered = _query.isEmpty ? allItems : _fuzzyFilter(allItems, _query);
    final searching = _query.isNotEmpty;

    return Scaffold(
      backgroundColor: HermesTokens.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(count: allItems.length),
            _SearchBar(controller: _queryController),
            Expanded(
              child: RefreshIndicator(
                color: HermesTokens.accent,
                onRefresh: () async => ref.invalidate(sessionsProvider),
                child: async.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _ErrorView(message: e.toString()),
                  data: (_) {
                    if (allItems.isEmpty) return const _EmptyView();
                    if (filtered.isEmpty) {
                      return _NoMatchView(query: _query);
                    }
                    // En recherche : liste à plat, triée par score (déjà fait
                    // par _fuzzyFilter). En navigation : groupée par jour.
                    if (searching) {
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                        children: [
                          for (final s in filtered) _SessionCard(session: s),
                        ],
                      );
                    }
                    final groups = _groupByDay(filtered);
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                      children: [
                        for (final g in groups) ...[
                          _GroupHeader(label: g.label),
                          for (final s in g.items)
                            _SessionCard(session: s),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      decoration: const Border(
        bottom: BorderSide(color: HermesTokens.border),
      ).toBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Historique', style: HermesText.title()),
          const SizedBox(height: 2),
          Text(
            count == 0
                ? 'aucune session'
                : '$count session${count > 1 ? 's' : ''}',
            style: HermesText.caption(color: HermesTokens.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.controller});
  final TextEditingController controller;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: AnimatedContainer(
        duration: HermesTokens.fast,
        decoration: BoxDecoration(
          color: HermesTokens.surface1,
          border: Border.all(
            color: _focused ? HermesTokens.borderFocus : HermesTokens.border,
            width: _focused ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(HermesTokens.rMd),
          boxShadow: _focused
              ? const [
                  BoxShadow(
                    color: HermesTokens.accentSoft,
                    blurRadius: 0,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 14,
              color: _focused ? HermesTokens.accent : HermesTokens.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                cursorColor: HermesTokens.accent,
                cursorWidth: 1.5,
                style: HermesText.bodySm(),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  hintText: "Rechercher dans l'historique",
                  hintStyle: HermesText.bodySm(color: HermesTokens.textMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            if (hasText)
              GestureDetector(
                onTap: () => widget.controller.clear(),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: HermesTokens.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoMatchView extends StatelessWidget {
  const _NoMatchView({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 80),
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Aucun résultat pour « $query »',
              textAlign: TextAlign.center,
              style: HermesText.bodySm(color: HermesTokens.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: HermesText.eyebrow(color: HermesTokens.textMuted),
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session});
  final LocalSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Dismissible(
        key: ValueKey(session.sessionId),
        direction: DismissDirection.endToStart,
        background: _DismissBackground(),
        confirmDismiss: (_) => _confirmDelete(context),
        onDismissed: (_) {
          ref.read(sessionsProvider.notifier).delete(session.sessionId);
        },
        child: InkWell(
          onTap: () {
            ref.read(chatControllerProvider.notifier).loadSession(session);
            context.go(AppRoutes.chat);
          },
          borderRadius: BorderRadius.circular(HermesTokens.rMd),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: HermesTokens.surface1,
              border: Border.all(color: HermesTokens.border),
              borderRadius: BorderRadius.circular(HermesTokens.rMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HermesText.body().copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (session.preview?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    session.preview!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HermesText.bodySm(color: HermesTokens.textDim),
                  ),
                ],
                const SizedBox(height: HermesTokens.s2),
                Row(
                  children: [
                    Text(
                      _relativeFr(session.updatedAt),
                      style: HermesText.caption(color: HermesTokens.textMuted)
                          .copyWith(fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 2,
                      height: 2,
                      decoration: const BoxDecoration(
                        color: HermesTokens.textFaint,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      session.sessionId,
                      style: HermesText.mono(
                        size: 10,
                        color: HermesTokens.textFaint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: HermesTokens.surface1,
        title: Text('Supprimer cette session ?', style: HermesText.section()),
        content: Text(
          "L'historique local sera effacé. Hermes garde sa mémoire serveur.",
          style: HermesText.bodySm(color: HermesTokens.textDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Annuler',
              style: HermesText.body(color: HermesTokens.textDim),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HermesTokens.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text('Supprimer', style: HermesText.body(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _DismissBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HermesTokens.errorSoft,
        borderRadius: BorderRadius.circular(HermesTokens.rMd),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 18),
      child: const Icon(
        Icons.delete_outline_rounded,
        color: HermesTokens.error,
        size: 18,
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 80),
      children: [
        Center(
          child: Column(
            children: [
              Icon(
                Icons.history_rounded,
                size: 32,
                color: HermesTokens.textFaint,
              ),
              const SizedBox(height: 12),
              Text(
                'Aucune session pour le moment',
                style: HermesText.bodySm(color: HermesTokens.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                'Démarre une conversation dans Chat —\nelle apparaîtra ici.',
                textAlign: TextAlign.center,
                style: HermesText.caption(color: HermesTokens.textFaint),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: HermesText.bodySm(color: HermesTokens.error),
        ),
      ],
    );
  }
}

class _Group {
  _Group(this.label, this.items);
  final String label;
  final List<LocalSession> items;
}

List<_Group> _groupByDay(List<LocalSession> items) {
  final today = <LocalSession>[];
  final yesterday = <LocalSession>[];
  final earlier = <LocalSession>[];
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfYesterday = startOfToday.subtract(const Duration(days: 1));

  for (final item in items) {
    final date = item.updatedAt.toLocal();
    if (date.isAfter(startOfToday) || date.isAtSameMomentAs(startOfToday)) {
      today.add(item);
    } else if (date.isAfter(startOfYesterday)) {
      yesterday.add(item);
    } else {
      earlier.add(item);
    }
  }

  return [
    if (today.isNotEmpty) _Group("Aujourd'hui", today),
    if (yesterday.isNotEmpty) _Group('Hier', yesterday),
    if (earlier.isNotEmpty) _Group('Plus tôt', earlier),
  ];
}

/// Filtre tolérant aux fautes : score Levenshtein-based (fuzzywuzzy).
/// Seuil 55/100 — assez large pour rattraper "helo" → "hello", "histor" →
/// "historique", etc. sans devenir bruyant.
List<LocalSession> _fuzzyFilter(List<LocalSession> items, String query) {
  const threshold = 55;
  final scored = <({LocalSession session, int score})>[];
  for (final s in items) {
    final hay = '${s.title} ${s.preview ?? ''}'.toLowerCase();
    final exact = hay.contains(query);
    // partialRatio gère bien les sous-chaînes ("helo" dans "hello world").
    final partial = partialRatio(query, hay);
    final tokens = tokenSetRatio(query, hay);
    final score = exact ? 100 : (partial > tokens ? partial : tokens);
    if (score >= threshold) scored.add((session: s, score: score));
  }
  scored.sort((a, b) => b.score.compareTo(a.score));
  return scored.map((r) => r.session).toList();
}

String _relativeFr(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return "à l'instant";
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'hier';
  if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
  final months = const [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  return '${when.day} ${months[when.month - 1]}';
}

extension on Border {
  BoxDecoration toBoxDecoration() => BoxDecoration(border: this);
}
