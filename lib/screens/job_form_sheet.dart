import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/hermes_service.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';

/// Sheet de création / édition d'un job. Si [initial] est fourni → édition.
class JobFormSheet extends ConsumerStatefulWidget {
  const JobFormSheet({super.key, this.initial});

  final JobSummary? initial;

  static Future<bool?> show(BuildContext context, {JobSummary? initial}) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: HermesTokens.surface1,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => JobFormSheet(initial: initial),
    );
  }

  @override
  ConsumerState<JobFormSheet> createState() => _JobFormSheetState();
}

class _JobFormSheetState extends ConsumerState<JobFormSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name == widget.initial?.id
        ? ''
        : widget.initial?.name ?? '',
  );
  late final TextEditingController _prompt = TextEditingController(
    text: widget.initial?.prompt ?? '',
  );
  late final TextEditingController _schedule = TextEditingController(
    text: widget.initial?.schedule ?? '',
  );

  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _prompt.dispose();
    _schedule.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final prompt = _prompt.text.trim();
    final schedule = _schedule.text.trim();
    if (prompt.isEmpty) {
      setState(() => _error = 'Le prompt est requis.');
      return;
    }
    if (schedule.isEmpty) {
      setState(() => _error = 'Le schedule (cron) est requis.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(hermesServiceProvider);
      final input = JobInput(
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
        prompt: prompt,
        schedule: schedule,
      );
      if (_isEdit) {
        final updated = await service.updateJob(widget.initial!.id, input);
        ref.read(jobsProvider.notifier).replace(updated);
      } else {
        await service.createJob(input);
        // Création → on doit refetch (le nouveau job n'est pas en local).
        await ref.read(jobsProvider.notifier).refresh();
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is HermesException ? e.message : '$e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEdit ? 'Éditer le job' : 'Nouveau job',
                style: HermesText.section(),
              ),
              const SizedBox(height: HermesTokens.s4),
              _Field(
                label: 'Nom (optionnel)',
                hint: 'Teams → Vault',
                controller: _name,
              ),
              const SizedBox(height: HermesTokens.s3),
              _Field(
                label: 'Prompt',
                hint:
                    'Extrais les messages Teams du jour et enrichis le vault Obsidian',
                controller: _prompt,
                multiline: true,
              ),
              const SizedBox(height: HermesTokens.s3),
              _Field(
                label: 'Schedule',
                hint: '0 3 * * *',
                controller: _schedule,
                monospace: true,
              ),
              const SizedBox(height: 8),
              const _CronPresets(),
              if (_error != null) ...[
                const SizedBox(height: HermesTokens.s3),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: HermesTokens.errorSoft,
                    borderRadius: BorderRadius.circular(HermesTokens.rSm),
                  ),
                  child: Text(
                    _error!,
                    style: HermesText.bodySm(color: HermesTokens.error),
                  ),
                ),
              ],
              const SizedBox(height: HermesTokens.s5),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: HermesTokens.accent,
                    foregroundColor: Colors.white,
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
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEdit ? 'Enregistrer' : 'Créer le job',
                          style: HermesText.body(color: Colors.white)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatefulWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    this.multiline = false,
    this.monospace = false,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool multiline;
  final bool monospace;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            widget.label,
            style: HermesText.caption(color: HermesTokens.textDim),
          ),
        ),
        AnimatedContainer(
          duration: HermesTokens.fast,
          decoration: BoxDecoration(
            color: HermesTokens.surface,
            border: Border.all(
              color:
                  _focused ? HermesTokens.borderFocus : HermesTokens.border,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            cursorColor: HermesTokens.accent,
            cursorWidth: 1.5,
            minLines: widget.multiline ? 3 : 1,
            maxLines: widget.multiline ? 6 : 1,
            style: widget.monospace
                ? HermesText.mono(size: 13)
                : HermesText.body().copyWith(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: widget.hint,
              hintStyle: widget.monospace
                  ? HermesText.mono(size: 13, color: HermesTokens.textMuted)
                  : HermesText.body(color: HermesTokens.textMuted)
                      .copyWith(fontSize: 14),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _CronPresets extends StatelessWidget {
  const _CronPresets();

  static const _presets = <_CronPreset>[
    _CronPreset(expr: '*/15 * * * *', label: 'toutes les 15 min'),
    _CronPreset(expr: '0 * * * *', label: 'toutes les heures'),
    _CronPreset(expr: '0 3 * * *', label: 'tous les jours à 3 h'),
    _CronPreset(expr: '0 9 * * 1-5', label: 'jours ouvrés 9 h'),
    _CronPreset(expr: '0 0 * * 0', label: 'dimanche minuit'),
  ];

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in _presets) _PresetChip(preset: p),
          ],
        );
      },
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.preset});
  final _CronPreset preset;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Trouve le _FieldState parent contenant le controller "Schedule".
        final form = context.findAncestorStateOfType<_JobFormSheetState>();
        form?._schedule.text = preset.expr;
        form?._schedule.selection = TextSelection.collapsed(
          offset: preset.expr.length,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: HermesTokens.surface,
          border: Border.all(color: HermesTokens.border),
          borderRadius: BorderRadius.circular(HermesTokens.rSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              preset.expr,
              style: HermesText.mono(size: 11, color: HermesTokens.textDim),
            ),
            const SizedBox(width: 6),
            Text(
              preset.label,
              style: HermesText.caption(color: HermesTokens.textMuted)
                  .copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _CronPreset {
  const _CronPreset({required this.expr, required this.label});
  final String expr;
  final String label;
}
