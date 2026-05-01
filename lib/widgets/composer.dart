import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/hermes_service.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';

/// Représente une image attachée en mémoire dans le composer — conserve les
/// bytes pour l'affichage de la thumbnail et le data URL pour l'envoi.
class _AttachedImage {
  const _AttachedImage({required this.bytes, required this.attachment});
  final Uint8List bytes;
  final ImageAttachment attachment;
}

/// Champ de saisie en bas du chat — conforme au design `Composer` du brief.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.onSend,
    this.placeholder = 'Demande à hermui…',
  });

  final TextEditingController controller;

  /// Appelé avec la liste des images attachées (souvent vide). Le composer se
  /// charge de vider ses thumbnails après l'envoi.
  final void Function(List<ImageAttachment> images) onSend;
  final String placeholder;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _focusNode = FocusNode();
  final _picker = ImagePicker();
  final List<_AttachedImage> _images = [];
  bool _focused = false;
  bool _picking = false;

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

  Future<void> _pickFromSource(ImageSource source) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final mime = _guessMime(picked.name, picked.mimeType);
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      if (!mounted) return;
      setState(() {
        _images.add(_AttachedImage(
          bytes: bytes,
          attachment: ImageAttachment(dataUrl: dataUrl, mimeType: mime),
        ));
      });
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  String _guessMime(String name, String? declared) {
    if (declared != null && declared.isNotEmpty) return declared;
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  void _showAttachSheet() {
    if (_picking) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HermesTokens.surface1,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: HermesTokens.text,
                ),
                title: Text(
                  'Choisir depuis la galerie',
                  style: HermesText.body(),
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _pickFromSource(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_outlined,
                  color: HermesTokens.text,
                ),
                title: Text('Prendre une photo', style: HermesText.body()),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _pickFromSource(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  void _send() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (!hasText && _images.isEmpty) return;
    final imgs = [for (final i in _images) i.attachment];
    widget.onSend(imgs);
    setState(() => _images.clear());
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.trim().isNotEmpty;
    final hasImages = _images.isNotEmpty;
    final canSend = hasText || hasImages;

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
        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasImages)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
                child: SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => _Thumb(
                      bytes: _images[i].bytes,
                      onRemove: () => _removeImage(i),
                    ),
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _AttachButton(
                  busy: _picking,
                  onTap: _showAttachSheet,
                ),
                const SizedBox(width: 4),
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
                    onSubmitted: (_) => _send(),
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
                  active: canSend,
                  focused: _focused,
                  onTap: _send,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachButton extends StatelessWidget {
  const _AttachButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: busy
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: HermesTokens.textMuted,
                ),
              )
            : const Icon(
                Icons.add_photo_alternate_outlined,
                size: 20,
                color: HermesTokens.textMuted,
              ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.bytes, required this.onRemove});
  final Uint8List bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(HermesTokens.rSm),
          child: Image.memory(
            bytes,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          right: -4,
          top: -4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: HermesTokens.surface,
                border: Border.all(color: HermesTokens.border),
                borderRadius: BorderRadius.circular(99),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.close_rounded,
                size: 12,
                color: HermesTokens.text,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.active,
    required this.focused,
    required this.onTap,
  });

  /// Le bouton est tappable dès qu'il y a du texte ou une image attachée —
  /// même pendant un run en cours, le tap empile le message en queue
  /// (cf. ChatController.send).
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
