import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../services/hermes_service.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'code_block.dart';
import 'copy_button.dart';

enum CursorStyle { block, token, shimmer }

/// Bulle "tool progress" — italique gris, icône terminal, preview tronqué.
class ToolMessageBubble extends StatelessWidget {
  const ToolMessageBubble({
    super.key,
    required this.tool,
    required this.preview,
  });

  final String tool;
  final String preview;

  IconData get _icon {
    switch (tool.toLowerCase()) {
      case 'terminal':
      case 'shell':
      case 'bash':
        return Icons.terminal_rounded;
      case 'python':
      case 'code':
        return Icons.code_rounded;
      case 'http':
      case 'fetch':
      case 'web':
        return Icons.public_rounded;
      case 'file':
      case 'read':
      case 'write':
        return Icons.description_outlined;
      default:
        return Icons.bolt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HermesTokens.s4 + 26,
        4,
        HermesTokens.s4,
        4,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: HermesTokens.surface,
          border: Border.all(color: HermesTokens.border),
          borderRadius: BorderRadius.circular(HermesTokens.rSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 12, color: HermesTokens.textMuted),
            const SizedBox(width: 6),
            Text(
              tool,
              style: HermesText.mono(
                size: 11,
                color: HermesTokens.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 2,
              height: 2,
              decoration: const BoxDecoration(
                color: HermesTokens.textFaint,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HermesText.mono(
                  size: 11.5,
                  color: HermesTokens.textDim,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bulle utilisateur — alignée à droite, surface2, coin bas-droit aplati.
class UserMessageBubble extends StatelessWidget {
  const UserMessageBubble({
    super.key,
    required this.content,
    this.images = const [],
  });

  final String content;
  final List<ImageAttachment> images;

  @override
  Widget build(BuildContext context) {
    final hasContent = content.isNotEmpty;
    final hasImages = images.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HermesTokens.s4,
        6,
        HermesTokens.s4,
        6,
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasImages) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    for (final img in images) _UserImage(attachment: img),
                  ],
                ),
                if (hasContent) const SizedBox(height: 6),
              ],
              if (hasContent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: HermesTokens.surface2,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: SelectableText(content, style: HermesText.body()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserImage extends StatelessWidget {
  const _UserImage({required this.attachment});
  final ImageAttachment attachment;

  Uint8List? _decode() {
    final url = attachment.dataUrl;
    final i = url.indexOf(',');
    if (i < 0) return null;
    try {
      return base64Decode(url.substring(i + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _decode();
    if (bytes == null) {
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(HermesTokens.rMd),
      child: Image.memory(
        bytes,
        width: 180,
        fit: BoxFit.cover,
      ),
    );
  }
}

/// Bulle assistant — header H + nom + corps + actions optionnelles.
/// Streaming → curseur animé selon [cursorStyle].
class AssistantMessageBubble extends StatelessWidget {
  const AssistantMessageBubble({
    super.key,
    required this.content,
    this.streaming = false,
    this.cursorStyle = CursorStyle.block,
    this.showActions = false,
    this.usage,
    this.onRetry,
    this.children,
  });

  final String content;
  final bool streaming;
  final CursorStyle cursorStyle;
  final bool showActions;
  final TokenUsage? usage;
  final VoidCallback? onRetry;

  /// Bloc additionnel (CodeBlock, listes…) inséré sous le texte.
  final Widget? children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HermesTokens.s4,
        6,
        HermesTokens.s4,
        6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: HermesTokens.accent,
                  borderRadius: BorderRadius.circular(5),
                ),
                alignment: Alignment.center,
                child: Text(
                  'H',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: HermesTokens.s2),
              Text(
                'hermui',
                style: HermesText.caption(color: HermesTokens.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StreamingText(
                  content: content,
                  streaming: streaming,
                  cursorStyle: cursorStyle,
                ),
                ?children,
              ],
            ),
          ),
          if (showActions) ...[
            const SizedBox(height: HermesTokens.s2),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Row(
                children: [
                  CopyButton(text: content),
                  if (onRetry != null) ...[
                    const SizedBox(width: 4),
                    _ActionButton(
                      icon: Icons.refresh_rounded,
                      onTap: onRetry!,
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (usage != null && !streaming) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                '${_fmtTokens(usage!.inputTokens)} in · ${_fmtTokens(usage!.outputTokens)} out',
                style: HermesText.mono(
                  size: 10,
                  color: HermesTokens.textFaint,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Formatte un compte de tokens en suffixe `k` au-delà de 1000.
/// `999` → "999", `1234` → "1.2k", `12345` → "12k", `123456` → "123k".
String _fmtTokens(int n) {
  if (n < 1000) return n.toString();
  if (n < 10000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '${(n / 1000).round()}k';
}

class _StreamingText extends StatelessWidget {
  const _StreamingText({
    required this.content,
    required this.streaming,
    required this.cursorStyle,
  });

  final String content;
  final bool streaming;
  final CursorStyle cursorStyle;

  @override
  Widget build(BuildContext context) {
    final base = HermesText.body().copyWith(height: 1.55);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (content.isNotEmpty)
          GptMarkdown(
            content,
            style: base,
            textAlign: TextAlign.left,
            codeBuilder: (ctx, name, code, closed) => CodeBlock(
              code: code,
              lang: name.isEmpty ? 'text' : name,
            ),
            highlightBuilder: (ctx, text, style) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: HermesTokens.surface2,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                text,
                style: HermesText.mono(size: 12.5, color: HermesTokens.text),
              ),
            ),
            linkBuilder: (ctx, label, url, style) => InkWell(
              onTap: () {},
              child: Text(
                label.toPlainText(),
                style: style.copyWith(
                  color: HermesTokens.accent,
                  decoration: TextDecoration.underline,
                  decorationColor: HermesTokens.accent.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        if (streaming)
          Padding(
            padding: EdgeInsets.only(top: content.isEmpty ? 0 : 4),
            child: _Cursor(style: cursorStyle),
          ),
      ],
    );
  }
}

class _Cursor extends StatefulWidget {
  const _Cursor({required this.style});
  final CursorStyle style;

  @override
  State<_Cursor> createState() => _CursorState();
}

class _CursorState extends State<_Cursor> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.style == CursorStyle.token
          ? const Duration(milliseconds: 800)
          : const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isToken = widget.style == CursorStyle.token;
    final width = isToken ? 6.0 : 8.0;
    final height = isToken ? 14.0 : 16.0;
    final color = isToken
        ? HermesTokens.text.withValues(alpha: 0.6)
        : HermesTokens.accent;

    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: FadeTransition(
        opacity: Tween(begin: 0.25, end: 1.0).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
        ),
        child: Container(width: width, height: height, color: color),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        child: Icon(icon, size: 13, color: HermesTokens.textMuted),
      ),
    );
  }
}
