import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/hermes_service.dart';
import '../services/notifications.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import '../widgets/sparkline.dart';
import '../widgets/status_dot.dart';
import 'job_form_sheet.dart';

class JobsScreen extends ConsumerWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(jobsProvider);
    final jobs = async.value ?? const <JobSummary>[];
    final activeCount = jobs
        .where((j) => statusKindFrom(j.status) == JobStatusKind.active)
        .length;

    return Scaffold(
      backgroundColor: HermesTokens.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              active: activeCount,
              total: jobs.length,
              onAdd: () => JobFormSheet.show(context),
            ),
            Expanded(
              child: RefreshIndicator(
                color: HermesTokens.accent,
                onRefresh: () async => ref.invalidate(jobsProvider),
                child: async.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _ErrorView(message: e.toString()),
                  data: (items) {
                    if (items.isEmpty) {
                      return _EmptyView(
                        onCreate: () => JobFormSheet.show(context),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _JobRow(job: items[i]),
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
  const _Header({
    required this.active,
    required this.total,
    required this.onAdd,
  });
  final int active;
  final int total;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      decoration: const Border(
        bottom: BorderSide(color: HermesTokens.border),
      ).toBoxDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Jobs', style: HermesText.title()),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const StatusDot(kind: JobStatusKind.active, size: 5),
                    const SizedBox(width: 4),
                    Text(
                      '$active actifs',
                      style: HermesText.caption(color: HermesTokens.textMuted)
                          .copyWith(fontSize: 11.5),
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
                      '$total au total',
                      style: HermesText.caption(color: HermesTokens.textMuted)
                          .copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: HermesTokens.accent,
                borderRadius: BorderRadius.circular(HermesTokens.rSm),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.add_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobRow extends ConsumerWidget {
  const _JobRow({required this.job});
  final JobSummary job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = statusKindFrom(job.status);
    final accent = switch (kind) {
      JobStatusKind.active => HermesTokens.success,
      JobStatusKind.paused => HermesTokens.warn,
      JobStatusKind.failed => HermesTokens.error,
      JobStatusKind.running => HermesTokens.accent,
      _ => HermesTokens.textFaint,
    };
    final bars = sparkBarsForJob(jobId: job.id, status: job.status);

    return InkWell(
      onTap: () => _showDetails(context, ref, job),
      child: Container(
        decoration: const Border(
          bottom: BorderSide(color: HermesTokens.border),
        ).toBoxDecoration(),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              job.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HermesText.body().copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Sparkline(bars: bars),
                        ],
                      ),
                      if (job.prompt?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          job.prompt!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HermesText.bodySm(color: HermesTokens.textDim),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (job.schedule != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: HermesTokens.surface2,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                job.schedule!,
                                style: HermesText.mono(
                                  size: 11,
                                  color: HermesTokens.textDim,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (job.nextRun != null)
                            Flexible(
                              child: Text(
                                _next(job.nextRun!),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HermesText.caption(
                                  color: HermesTokens.textMuted,
                                ).copyWith(fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                      if (kind == JobStatusKind.failed &&
                          job.lastResult?.isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 11,
                              color: HermesTokens.error,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                job.lastResult!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HermesText.caption(
                                  color: HermesTokens.error,
                                ).copyWith(fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, WidgetRef ref, JobSummary job) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HermesTokens.surface1,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _JobDetailsSheet(job: job),
    );
  }
}

class _JobDetailsSheet extends ConsumerStatefulWidget {
  const _JobDetailsSheet({required this.job});
  final JobSummary job;

  @override
  ConsumerState<_JobDetailsSheet> createState() => _JobDetailsSheetState();
}

class _JobDetailsSheetState extends ConsumerState<_JobDetailsSheet> {
  bool _busy = false;
  JobSummary? _local;

  /// Source de vérité du sheet : la version locale modifiée par les actions
  /// (pause/resume/run), sinon le job tel que passé depuis la liste.
  JobSummary get _job => _local ?? widget.job;

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            error ? HermesTokens.errorSoft : HermesTokens.surface2,
        content: Text(
          msg,
          style: HermesText.bodySm(
            color: error ? HermesTokens.error : HermesTokens.text,
          ),
        ),
      ),
    );
  }

  Future<void> _action(
    Future<JobSummary> Function(HermesService s) op,
    String success,
  ) async {
    setState(() => _busy = true);
    try {
      final updated = await op(ref.read(hermesServiceProvider));
      ref.read(jobsProvider.notifier).replace(updated);
      if (mounted) {
        setState(() => _local = updated);
        _showSnack(success);
      }
    } catch (e) {
      _showSnack(e is HermesException ? e.message : '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Trigger manuel — on a la version d'avant et d'après, donc on déclenche
  /// la notif ici directement (le polling ne verra pas la différence puisqu'on
  /// remplace l'état avec la version post-run).
  Future<void> _trigger() async {
    final before = _job;
    setState(() => _busy = true);
    try {
      final updated =
          await ref.read(hermesServiceProvider).triggerJob(before.id);
      ref.read(jobsProvider.notifier).replace(updated);
      if (mounted) setState(() => _local = updated);

      final body = updated.lastResult ?? updated.status ?? 'Run terminé';
      final isError = (updated.status?.toLowerCase() == 'failed') ||
          body.toLowerCase().contains('error');
      await NotificationsService.instance.notify(
        title: updated.name,
        body: body,
        emoji: isError ? '❌' : '✅',
      );

      if (mounted) {
        _showSnack('Déclenché : ${updated.name}');
      }
    } catch (e) {
      _showSnack(e is HermesException ? e.message : '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _togglePause() async {
    final paused = statusKindFrom(_job.status) == JobStatusKind.paused;
    await _action(
      paused ? (s) => s.resumeJob(_job.id) : (s) => s.pauseJob(_job.id),
      paused ? 'Job repris' : 'Job mis en pause',
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: HermesTokens.surface1,
        title: Text('Supprimer ce job ?', style: HermesText.section()),
        content: Text(
          "L'opération est définitive côté serveur.",
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
            child: Text(
              'Supprimer',
              style: HermesText.body(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(hermesServiceProvider).deleteJob(_job.id);
      ref.read(jobsProvider.notifier).remove(_job.id);
      if (mounted) {
        _showSnack('Job supprimé');
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showSnack(e is HermesException ? e.message : '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    Navigator.of(context).pop();
    await JobFormSheet.show(context, initial: _job);
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    final kind = statusKindFrom(job.status);
    final paused = kind == JobStatusKind.paused;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.name, style: HermesText.section()),
                      const SizedBox(height: 4),
                      Text(
                        job.id,
                        style: HermesText.mono(
                          size: 11,
                          color: HermesTokens.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(kind: kind),
              ],
            ),
            const SizedBox(height: HermesTokens.s5),
            if (job.prompt?.isNotEmpty == true) ...[
              _SectionLabel('Prompt'),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HermesTokens.surface,
                  border: Border.all(color: HermesTokens.border),
                  borderRadius: BorderRadius.circular(HermesTokens.rMd),
                ),
                child: SelectableText(
                  job.prompt!,
                  style: HermesText.bodySm(color: HermesTokens.text),
                ),
              ),
              const SizedBox(height: HermesTokens.s4),
            ],
            Row(
              children: [
                Expanded(
                  child: _DetailField(
                    label: 'Schedule',
                    value: job.schedule ?? '—',
                    monospace: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DetailField(
                    label: 'Prochain',
                    value: job.nextRun != null ? _next(job.nextRun!) : '—',
                  ),
                ),
              ],
            ),
            if (job.lastRun != null || job.lastResult != null) ...[
              const SizedBox(height: 8),
              _DetailField(
                label: 'Dernier run',
                value: [
                  if (job.lastRun != null) _next(job.lastRun!),
                  if (job.lastResult?.isNotEmpty == true) job.lastResult!,
                ].join(' · '),
              ),
            ],
            const SizedBox(height: HermesTokens.s5),
            Row(
              children: [
                Expanded(
                  child: _Action(
                    icon: Icons.play_arrow_rounded,
                    label: 'Lancer',
                    onTap: _busy ? null : _trigger,
                    primary: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Action(
                    icon: paused
                        ? Icons.play_circle_outline_rounded
                        : Icons.pause_rounded,
                    label: paused ? 'Reprendre' : 'Pause',
                    onTap: _busy ? null : _togglePause,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _Action(
                    icon: Icons.edit_outlined,
                    label: 'Éditer',
                    onTap: _busy ? null : _edit,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Action(
                    icon: Icons.delete_outline_rounded,
                    label: 'Supprimer',
                    onTap: _busy ? null : _delete,
                    destructive: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.kind});
  final JobStatusKind kind;

  @override
  Widget build(BuildContext context) {
    final (label, color, soft) = switch (kind) {
      JobStatusKind.active => ('actif', HermesTokens.success, HermesTokens.successSoft),
      JobStatusKind.failed => ('échec', HermesTokens.error, HermesTokens.errorSoft),
      JobStatusKind.paused => ('pause', HermesTokens.warn, HermesTokens.warnSoft),
      JobStatusKind.running =>
        ('en cours', HermesTokens.accent, HermesTokens.accentSoft),
      JobStatusKind.idle => ('—', HermesTokens.textFaint, HermesTokens.surface2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(HermesTokens.rFull),
      ),
      child: Text(
        label.toUpperCase(),
        style: HermesText.eyebrow(color: color),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: HermesText.eyebrow(color: HermesTokens.textMuted),
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.label,
    required this.value,
    this.monospace = false,
  });
  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: HermesTokens.surface,
        border: Border.all(color: HermesTokens.border),
        borderRadius: BorderRadius.circular(HermesTokens.rSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: HermesText.eyebrow(color: HermesTokens.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: monospace
                ? HermesText.mono(size: 12)
                : HermesText.bodySm(color: HermesTokens.text),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final bg = primary
        ? HermesTokens.accent
        : destructive
            ? HermesTokens.errorSoft
            : HermesTokens.surface2;
    final fg = primary
        ? Colors.white
        : destructive
            ? HermesTokens.error
            : HermesTokens.text;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(HermesTokens.rMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(HermesTokens.rMd),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: HermesText.body(color: fg).copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 80),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: HermesTokens.surface1,
                  border: Border.all(color: HermesTokens.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: HermesTokens.textMuted,
                ),
              ),
              const SizedBox(height: HermesTokens.s4),
              Text('Aucun job configuré', style: HermesText.title()),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  "Crée un cron pour qu'Hermes fasse le boulot pendant que tu fais autre chose.",
                  textAlign: TextAlign.center,
                  style: HermesText.bodySm(color: HermesTokens.textMuted),
                ),
              ),
              const SizedBox(height: HermesTokens.s5),
              SizedBox(
                width: 220,
                height: 44,
                child: FilledButton(
                  onPressed: onCreate,
                  style: FilledButton.styleFrom(
                    backgroundColor: HermesTokens.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(HermesTokens.rMd),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Créer le premier job',
                        style: HermesText.body(color: Colors.white).copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
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

String _next(DateTime when) {
  final diff = when.difference(DateTime.now());
  if (diff.isNegative) {
    final past = -diff.inMinutes;
    if (past < 1) return "à l'instant";
    if (past < 60) return 'il y a $past min';
    if (past < 1440) return 'il y a ${past ~/ 60} h';
    return 'il y a ${past ~/ 1440} j';
  }
  if (diff.inMinutes < 1) return "à l'instant";
  if (diff.inMinutes < 60) return 'dans ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'dans ${diff.inHours} h';
  return 'dans ${diff.inDays} j';
}

extension on Border {
  BoxDecoration toBoxDecoration() => BoxDecoration(border: this);
}
