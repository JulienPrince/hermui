import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/constants.dart';
import '../providers.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import '../widgets/hermes_logo.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _keyController = TextEditingController();
  late final TextEditingController _urlController;
  final _keyFocus = FocusNode();
  final _urlFocus = FocusNode();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current = ref.read(settingsProvider);
    final initial = current.baseUrl.isNotEmpty
        ? current.baseUrl
        : AppConstants.defaultBaseUrl;
    _urlController = TextEditingController(text: initial);
    if (current.apiKey != null) _keyController.text = current.apiKey!;
    _keyFocus.addListener(() => setState(() {}));
    _urlFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _keyController.dispose();
    _urlController.dispose();
    _keyFocus.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _keyController.text.trim();
    final url = _urlController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'La clé Bearer est requise.');
      return;
    }
    if (url.isEmpty) {
      setState(() => _error = "L'adresse est requise.");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(settingsProvider.notifier)
          .save(apiKey: key, baseUrl: url);
    } catch (e) {
      if (mounted) {
        setState(() => _error = "Échec de l'enregistrement : $e");
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HermesTokens.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.vertical -
                  40,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo + nom
                  Row(
                    children: [
                      const HermesLogo(size: 28),
                      const SizedBox(width: 10),
                      Text(
                        'hermui',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: HermesTokens.text,
                          letterSpacing: -0.15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: HermesTokens.s8),
                  Text('Connecte ton agent.', style: HermesText.display()),
                  const SizedBox(height: HermesTokens.s2),
                  Text(
                    'Hermes vit sur ton serveur. Donne-lui une adresse et une clé.',
                    style: HermesText.body(color: HermesTokens.textDim),
                  ),
                  const SizedBox(height: HermesTokens.s6),
                  _Field(
                    label: 'Adresse',
                    icon: Icons.public_rounded,
                    controller: _urlController,
                    focusNode: _urlFocus,
                    monospace: true,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: HermesTokens.s4),
                  _Field(
                    label: 'Clé Bearer',
                    icon: Icons.key_rounded,
                    controller: _keyController,
                    focusNode: _keyFocus,
                    obscure: true,
                    monospace: true,
                  ),
                  const SizedBox(height: HermesTokens.s2),
                  Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 12,
                        color: HermesTokens.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Stockée dans le keychain de l'appareil.",
                        style: HermesText.caption(color: HermesTokens.textMuted),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: HermesTokens.s4),
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
                  _PrimaryButton(
                    label: 'Se connecter',
                    busy: _saving,
                    onTap: _save,
                  ),
                  const Spacer(),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: HermesTokens.success,
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: const [
                              BoxShadow(
                                color: HermesTokens.success,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Endpoint joignable',
                          style: HermesText.caption(
                            color: HermesTokens.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.icon,
    required this.controller,
    required this.focusNode,
    this.obscure = false,
    this.monospace = false,
    this.keyboardType,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool obscure;
  final bool monospace;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: HermesText.caption(color: HermesTokens.textDim),
          ),
        ),
        AnimatedContainer(
          duration: HermesTokens.fast,
          decoration: BoxDecoration(
            color: HermesTokens.surface1,
            borderRadius: BorderRadius.circular(HermesTokens.rMd),
            border: Border.all(
              color: focused ? HermesTokens.borderFocus : HermesTokens.border,
              width: focused ? 1.5 : 1,
            ),
            boxShadow: focused
                ? const [
                    BoxShadow(
                      color: HermesTokens.accentSoft,
                      blurRadius: 0,
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: focused ? HermesTokens.accent : HermesTokens.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  obscureText: obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: keyboardType,
                  cursorColor: HermesTokens.accent,
                  cursorWidth: 1.5,
                  style: monospace
                      ? HermesText.mono(size: 14)
                      : HermesText.body(),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
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

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: busy ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: HermesTokens.accent,
          disabledBackgroundColor: HermesTokens.accent.withValues(alpha: 0.6),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HermesTokens.rMd),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: HermesText.section(color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ],
              ),
      ),
    );
  }
}
