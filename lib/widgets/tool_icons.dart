import 'package:flutter/material.dart';

/// Map d'un nom d'outil Hermes (`hermes.tool.progress` event ou
/// `function_call` Responses) vers une icône Material visuellement parlante.
///
/// Source : [[../../Docs/hermes-api-extras#mapping-tool-name-→-icon-pour-toolmessagebubble]]
/// (vault hermes-app). Mapping issu du scan complet de
/// `reference/tools-reference.md` côté Hermes Agent.
IconData iconForTool(String? rawName) {
  final name = (rawName ?? '').toLowerCase().trim();
  if (name.isEmpty) return Icons.build_rounded;

  // Familles à préfixe — match avant les exacts pour gérer les variantes
  // `browser_navigate`, `browser_click`, `ha_get_state`, etc.
  if (name.startsWith('browser')) return Icons.public_rounded;
  if (name.startsWith('ha_')) return Icons.home_rounded;
  if (name.startsWith('spotify')) return Icons.music_note_rounded;
  if (name.startsWith('feishu') || name.startsWith('yb_')) {
    return Icons.chat_bubble_rounded;
  }
  if (name.startsWith('discord')) return Icons.forum_rounded;

  switch (name) {
    case 'terminal':
    case 'shell':
    case 'bash':
    case 'process':
      return Icons.terminal_rounded;
    case 'read_file':
    case 'read':
    case 'cat':
      return Icons.description_outlined;
    case 'write_file':
    case 'write':
      return Icons.edit_note_rounded;
    case 'patch':
    case 'edit_file':
    case 'apply_patch':
      return Icons.difference_rounded;
    case 'search_files':
    case 'find':
    case 'grep':
      return Icons.search_rounded;
    case 'web_search':
    case 'search':
      return Icons.travel_explore_rounded;
    case 'web_extract':
    case 'fetch':
    case 'http':
      return Icons.article_outlined;
    case 'vision_analyze':
    case 'vision':
      return Icons.visibility_outlined;
    case 'image_generate':
    case 'generate_image':
      return Icons.image_outlined;
    case 'text_to_speech':
    case 'tts':
      return Icons.record_voice_over_rounded;
    case 'memory':
      return Icons.psychology_rounded;
    case 'session_search':
    case 'sessions':
      return Icons.history_rounded;
    case 'skill_view':
    case 'skills_list':
    case 'skill_manage':
    case 'skill':
      return Icons.auto_awesome_rounded;
    case 'cronjob':
    case 'cron':
      return Icons.schedule_rounded;
    case 'clarify':
      return Icons.help_outline_rounded;
    case 'todo':
    case 'todos':
      return Icons.checklist_rounded;
    case 'delegate_task':
    case 'delegate':
      return Icons.account_tree_rounded;
    case 'execute_code':
    case 'code':
    case 'python':
      return Icons.code_rounded;
    case 'send_message':
    case 'message':
      return Icons.send_rounded;
    case 'mixture_of_agents':
      return Icons.hub_rounded;
    default:
      // Outils MCP & inconnus — un namespace `_` indique une intégration
      // externe.
      if (name.contains('_')) return Icons.extension_rounded;
      return Icons.build_rounded;
  }
}
