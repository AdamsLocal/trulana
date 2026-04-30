import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/core/ui/ui.dart';
import 'package:trulana/features/dashboard/dashboard_view.dart';
import 'package:trulana/features/shell/views/context_vault_view.dart';
import 'package:trulana/features/shell/views/preferences_view.dart';
import 'package:trulana/features/shell/views/agents_view.dart';
import 'package:trulana/features/shell/views/audit_log_view.dart';
import 'package:trulana/features/shell/views/settings_view.dart';

/// Provider tracking which sidebar item is selected.
final selectedNavProvider = StateProvider<int>((ref) => 0);

/// macOS desktop app shell with persistent sidebar navigation.
///
/// Mirrors the desktop HTML mockup: a fixed sidebar on the left with
/// navigation items, and a content area on the right that swaps views.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    _NavItem(icon: Icons.hexagon_outlined, label: 'Context Vault'),
    _NavItem(icon: Icons.tune_rounded, label: 'Preferences'),
    _NavItem(icon: Icons.hub_outlined, label: 'Agents'),
    _NavItem(icon: Icons.receipt_long_rounded, label: 'Audit Log'),
  ];

  static const List<_NavItem> _systemItems = [
    _NavItem(icon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int selected = ref.watch(selectedNavProvider);

    return Scaffold(
      backgroundColor: TrulanaColors.background,
      body: Row(
        children: [
          // — Sidebar
          _Sidebar(
            navItems: _navItems,
            systemItems: _systemItems,
            selected: selected,
            onSelect: (int index) {
              ref.read(selectedNavProvider.notifier).state = index;
            },
          ),

          // — Content area
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildView(selected),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildView(int index) {
    return switch (index) {
      0 => const DashboardView(key: ValueKey('dashboard')),
      1 => const ContextVaultView(key: ValueKey('vault')),
      2 => const PreferencesView(key: ValueKey('prefs')),
      3 => const AgentsView(key: ValueKey('agents')),
      4 => const AuditLogView(key: ValueKey('audit')),
      5 => const SettingsView(key: ValueKey('settings')),
      _ => const DashboardView(key: ValueKey('dashboard')),
    };
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}

/// Fixed sidebar with brand header, nav items, and server status footer.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.navItems,
    required this.systemItems,
    required this.selected,
    required this.onSelect,
  });

  final List<_NavItem> navItems;
  final List<_NavItem> systemItems;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: Color(0xFF0B0B14),
        border: Border(
          right: BorderSide(color: TrulanaColors.surfaceLight),
        ),
      ),
      child: Column(
        children: [
          // — Brand header
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF14142A)),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(
                    'assets/images/trulana-icon.png',
                    width: 36,
                    height: 36,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trulana',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: TrulanaColors.textPrimary,
                        letterSpacing: 0.04,
                      ),
                    ),
                    Text(
                      'v1.2.1',
                      style: TrulanaTheme.monoStyle.copyWith(
                        fontSize: 9,
                        color: TrulanaColors.textTertiary,
                        letterSpacing: 0.04,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // — Navigation items
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...List.generate(navItems.length, (int i) {
                    return _NavButton(
                      item: navItems[i],
                      isActive: selected == i,
                      onTap: () => onSelect(i),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 16, 10, 6),
                    child: Text(
                      'SYSTEM',
                      style: TrulanaTheme.monoStyle.copyWith(
                        fontSize: 9,
                        letterSpacing: 1.0,
                        color: TrulanaColors.textTertiary,
                      ),
                    ),
                  ),
                  ...List.generate(systemItems.length, (int i) {
                    final int globalIndex = navItems.length + i;
                    return _NavButton(
                      item: systemItems[i],
                      isActive: selected == globalIndex,
                      onTap: () => onSelect(globalIndex),
                    );
                  }),
                  const Spacer(),
                ],
              ),
            ),
          ),

          // — Server status footer
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF14142A)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const PulseIndicator(
                      size: 7,
                      color: TrulanaColors.successGreen,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Server running on ',
                      style: TextStyle(
                        fontSize: 11,
                        color: TrulanaColors.textTertiary,
                      ),
                    ),
                    Text(
                      ':8432',
                      style: TrulanaTheme.monoStyle.copyWith(
                        fontSize: 11,
                        color: const Color(0xFF2A8A84),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'built with \u{1F480} energy by Gurley - AdamsLocal',
                  style: TextStyle(
                    fontSize: 9,
                    color: TrulanaColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual sidebar navigation button.
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isActive
                  ? TrulanaColors.primaryCyan.withValues(alpha: 0.08)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: isActive
                      ? TrulanaColors.primaryCyan
                      : TrulanaColors.textTertiary,
                ),
                const SizedBox(width: 10),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: isActive
                        ? TrulanaColors.primaryCyan
                        : TrulanaColors.textSecondary,
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
