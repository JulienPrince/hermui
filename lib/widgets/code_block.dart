import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';

import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'copy_button.dart';

/// Bloc de code mono — header avec langage + bouton copier + syntax highlight.
class CodeBlock extends StatelessWidget {
  const CodeBlock({super.key, required this.code, this.lang = 'text'});

  final String code;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final resolvedLang = _normalizeLang(lang);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: HermesTokens.bg,
        border: Border.all(color: HermesTokens.border),
        borderRadius: BorderRadius.circular(HermesTokens.rMd),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            decoration: const Border(
              bottom: BorderSide(color: HermesTokens.border),
            ).toBoxDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    resolvedLang,
                    style: HermesText.mono(
                      size: 11,
                      color: HermesTokens.textMuted,
                    ),
                  ),
                ),
                CopyButton(text: code, size: 24, iconSize: 12),
              ],
            ),
          ),
          // Wrap par défaut pour ne pas avoir de scroll horizontal qui
          // capture les gestes verticaux dans la liste de chat.
          HighlightView(
            code,
            language: resolvedLang,
            theme: _hermesIdeTheme,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            textStyle: HermesText.mono(size: 12.5),
          ),
        ],
      ),
    );
  }

  String _normalizeLang(String raw) {
    final lc = raw.toLowerCase().trim();
    if (lc.isEmpty) return 'plaintext';
    return switch (lc) {
      'sh' || 'shell' || 'zsh' => 'bash',
      'js' => 'javascript',
      'ts' => 'typescript',
      'py' => 'python',
      'yml' => 'yaml',
      'rb' => 'ruby',
      'kt' => 'kotlin',
      'rs' => 'rust',
      'go' || 'golang' => 'go',
      _ => lc,
    };
  }
}

/// Theme dérivé d'atom-one-dark, accordé à la palette Hermes (indigo + base
/// Hermes au lieu d'éditeur clair). Conserve les rôles standard de highlight.js.
final Map<String, TextStyle> _hermesIdeTheme = {
  ...atomOneDarkTheme,
  // Override de la racine pour que le fond soit transparent (le container
  // CodeBlock fournit déjà HermesTokens.bg).
  'root': const TextStyle(
    backgroundColor: Colors.transparent,
    color: HermesTokens.text,
  ),
  // Mots-clés en indigo
  'keyword': const TextStyle(
    color: HermesTokens.accent,
    fontWeight: FontWeight.w600,
  ),
  'built_in': const TextStyle(color: Color(0xFFB392F0)),
  // Strings en vert sobre
  'string': const TextStyle(color: HermesTokens.success),
  // Nombres / litéraux
  'number': const TextStyle(color: Color(0xFFFF9F58)),
  'literal': const TextStyle(color: Color(0xFFFF9F58)),
  // Commentaires
  'comment': const TextStyle(
    color: HermesTokens.textFaint,
    fontStyle: FontStyle.italic,
  ),
  'doctag': const TextStyle(color: HermesTokens.textFaint),
  // Fonctions / titres
  'title': const TextStyle(color: Color(0xFF7EC8FF)),
  'function': const TextStyle(color: Color(0xFF7EC8FF)),
  'name': const TextStyle(color: Color(0xFF7EC8FF)),
  // Variables
  'variable': const TextStyle(color: HermesTokens.text),
  'attr': const TextStyle(color: Color(0xFFFFB454)),
  // Tags HTML / XML
  'tag': const TextStyle(color: HermesTokens.error),
  'attribute': const TextStyle(color: Color(0xFFFFB454)),
  // Operators / punctuation
  'symbol': const TextStyle(color: HermesTokens.warn),
  'meta': const TextStyle(color: HermesTokens.textMuted),
  // Misc
  'params': const TextStyle(color: HermesTokens.text),
  'class': const TextStyle(color: Color(0xFFB392F0)),
  'type': const TextStyle(color: Color(0xFFB392F0)),
  'regexp': const TextStyle(color: HermesTokens.warn),
};

extension on Border {
  BoxDecoration toBoxDecoration() => BoxDecoration(border: this);
}
