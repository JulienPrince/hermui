import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/tokens.dart';

/// Bottom nav minimaliste — icônes seules, dot indigo sous l'onglet actif.
/// Conforme au design `BottomNav variant="icons-only"`.
class HermesBottomNav extends StatelessWidget {
  const HermesBottomNav({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _items = <_NavItem>[
    _NavItem(
      label: 'Chat',
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      route: AppRoutes.chat,
    ),
    _NavItem(
      label: 'Historique',
      icon: Icons.history_rounded,
      activeIcon: Icons.history_rounded,
      route: AppRoutes.history,
    ),
    _NavItem(
      label: 'Jobs',
      icon: Icons.tune_rounded,
      activeIcon: Icons.tune_rounded,
      route: AppRoutes.jobs,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final viewPaddingBottom = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      padding: EdgeInsets.only(
        top: HermesTokens.s2,
        bottom: viewPaddingBottom > 0 ? viewPaddingBottom : 12,
      ),
      decoration: const BoxDecoration(
        color: HermesTokens.surface,
        border: Border(top: BorderSide(color: HermesTokens.border)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: HermesTokens.s4),
        height: 52,
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _NavTab(
                  item: _items[i],
                  active: shell.currentIndex == i,
                  onTap: () => shell.goBranch(
                    i,
                    initialLocation: i == shell.currentIndex,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? HermesTokens.text : HermesTokens.textMuted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedDefaultTextStyle(
            duration: HermesTokens.fast,
            style: TextStyle(color: color),
            child: Icon(
              active ? item.activeIcon : item.icon,
              size: 22,
              color: color,
            ),
          ),
          if (active)
            Positioned(
              bottom: 0,
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: HermesTokens.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
}
