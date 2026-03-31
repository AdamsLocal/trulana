import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/database/database_helper.dart';
import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/models/models.dart';
import 'package:trulana/providers/providers.dart';

/// Settings view matching the desktop HTML mockup.
///
/// Privacy level, biometric config, server settings, and data management.
class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(userConfigProvider);

    return Column(
      children: [
        _header(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: configAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: TrulanaColors.primaryCyan,
                  strokeWidth: 2,
                ),
              ),
              error: (e, s) => Text(
                'Failed to load settings',
                style: TextStyle(color: TrulanaColors.dangerRed),
              ),
              data: (config) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingGroup(
                    title: 'Privacy',
                    children: [
                      _SettingRow(
                        label: 'Default privacy level',
                        subtitle: 'Applied to all new queries',
                        trailing: _PrivacyToggle(
                          level: config?.privacyLevel ?? PrivacyLevel.strict,
                          onChanged: (level) {
                            ref
                                .read(userConfigProvider.notifier)
                                .updatePrivacyLevel(level);
                          },
                        ),
                      ),
                      _SettingRow(
                        label: 'Require Touch ID on launch',
                        subtitle: 'Biometric gate every session',
                        trailing: const _ToggleSwitch(isOn: true),
                      ),
                    ],
                  ),
                  _SettingGroup(
                    title: 'Server',
                    children: [
                      _SettingRow(
                        label: 'Auto-start REST server',
                        subtitle: 'Binds to localhost:8432',
                        trailing: const _ToggleSwitch(isOn: true),
                      ),
                      _SettingRow(
                        label: 'MCP stdio adapter',
                        subtitle: 'For Claude Desktop / Cursor',
                        trailing: const _ToggleSwitch(isOn: true),
                      ),
                      _SettingRow(
                        label: 'Token TTL',
                        subtitle: 'Agent token validity period',
                        trailing: Text(
                          '15 min',
                          style: TrulanaTheme.monoStyle.copyWith(
                            fontSize: 13,
                            color: const Color(0xFF2A8A84),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _SettingGroup(
                    title: 'Data',
                    children: [
                      _SettingRow(
                        label: 'Export vault (encrypted)',
                        subtitle: 'Backup your context vault',
                        trailing: _ActionButton(
                          label: 'Export',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Vault export coming in a future release.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ),
                      _SettingRow(
                        label: 'Wipe all data',
                        subtitle: 'Permanently destroy everything',
                        trailing: _ActionButton(
                          label: 'Wipe',
                          isDanger: true,
                          onTap: () => _confirmWipe(context, ref),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmWipe(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E0E1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF14142A)),
        ),
        title: const Text('Wipe all data?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: TrulanaColors.textPrimary)),
        content: const Text(
            'This will permanently destroy your vault, preferences, agents, and audit log. This cannot be undone.',
            style: TextStyle(fontSize: 13, color: TrulanaColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: TextStyle(color: TrulanaColors.textTertiary)),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.instance.deleteDatabase();
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All data wiped. Restart the app.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text('Wipe Everything',
                style: TextStyle(color: Color(0xFFF05858))),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF14142A))),
      ),
      child: const Row(
        children: [
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: TrulanaColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingGroup extends StatelessWidget {
  const _SettingGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              title.toUpperCase(),
              style: TrulanaTheme.monoStyle.copyWith(
                fontSize: 10,
                letterSpacing: 0.8,
                color: TrulanaColors.textTertiary,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    this.subtitle,
    required this.trailing,
  });

  final String label;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x05FFFFFF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: TrulanaColors.textSecondary,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: TrulanaColors.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _ToggleSwitch extends StatefulWidget {
  const _ToggleSwitch({required this.isOn});

  final bool isOn;

  @override
  State<_ToggleSwitch> createState() => _ToggleSwitchState();
}

class _ToggleSwitchState extends State<_ToggleSwitch> {
  late bool _on;

  @override
  void initState() {
    super.initState();
    _on = widget.isOn;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _on = !_on),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 20,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: _on ? const Color(0xFF2A8A84) : TrulanaColors.surfaceLight,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: _on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _on
                  ? TrulanaColors.primaryCyan
                  : TrulanaColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyToggle extends StatelessWidget {
  const _PrivacyToggle({required this.level, required this.onChanged});

  final PrivacyLevel level;
  final ValueChanged<PrivacyLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: PrivacyLevel.values.map((pl) {
          final isActive = pl == level;
          return GestureDetector(
            onTap: () => onChanged(pl),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isActive
                    ? TrulanaColors.primaryCyan.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
              child: Text(
                pl.name[0].toUpperCase() + pl.name.substring(1),
                style: TrulanaTheme.monoStyle.copyWith(
                  fontSize: 9,
                  color: isActive
                      ? TrulanaColors.primaryCyan
                      : TrulanaColors.textTertiary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    this.isDanger = false,
    this.onTap,
  });

  final String label;
  final bool isDanger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDanger
                  ? const Color(0xFFF05858).withValues(alpha: 0.3)
                  : TrulanaColors.surfaceLight,
            ),
          ),
          child: Text(
            label,
            style: TrulanaTheme.monoStyle.copyWith(
              fontSize: 10,
              color: isDanger
                  ? const Color(0xFFF05858)
                  : TrulanaColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
