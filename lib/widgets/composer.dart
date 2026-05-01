import 'package:flutter/material.dart';

import '../theme/text_styles.dart';
import '../theme/tokens.dart';

/// Champ de saisie en bas du chat — conforme au design `Composer` du brief.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.onSend,
    this.placeholder = 'Demande à hermui…',
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final String placeholder;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocus);
    widget.controller.addListener(_handleText);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocus);
    widget.controller.removeListener(_handleText);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocus() => setState(() => _focused = _focusNode.hasFocus);
  void _handleText() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        HermesTokens.s4,
        HermesTokens.s3,
        HermesTokens.s4,
        HermesTokens.s4 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, HermesTokens.surface],
          stops: [0.0, 0.7],
        ),
      ),
      child: AnimatedContainer(
        duration: HermesTokens.fast,
        decoration: BoxDecoration(
          color: HermesTokens.surface1,
          borderRadius: BorderRadius.circular(HermesTokens.rLg),
          border: Border.all(
            color: _focused ? HermesTokens.borderFocus : HermesTokens.border,
            width: _focused ? 1.5 : 1,
          ),
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
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 5,
                cursorColor: HermesTokens.accent,
                cursorWidth: 1.5,
                style: HermesText.body(),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => widget.onSend(),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  hintText: widget.placeholder,
                  hintStyle: HermesText.body(color: HermesTokens.textMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: HermesTokens.s2),
            _SendButton(
              active: hasText,
              focused: _focused,
              onTap: widget.onSend,
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.active,
    required this.focused,
    required this.onTap,
  });

  /// Le bouton est tappable dès qu'il y a du texte — même pendant un run en
  /// cours, le tap empile le message en queue (cf. ChatController.send).
  final bool active;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = active || focused;
    return GestureDetector(
      onTap: active ? onTap : null,
      child: AnimatedContainer(
        duration: HermesTokens.fast,
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: highlighted ? HermesTokens.accent : HermesTokens.surface2,
          borderRadius: BorderRadius.circular(HermesTokens.rMd),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.arrow_upward_rounded,
          size: 18,
          color: highlighted ? Colors.white : HermesTokens.textMuted,
        ),
      ),
    );
  }
}
