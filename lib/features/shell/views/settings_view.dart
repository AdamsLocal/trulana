import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/core/ui/ui.dart';
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
    final settingsAsync = ref.watch(appSettingsProvider);

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
                        trailing: PrivacyToggleWidget(
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
                        trailing: settingsAsync.whenOrNull(
                              data: (settings) => _ToggleSwitch(
                                isOn: settings.requireBiometric,
                                onChanged: (value) => ref
                                    .read(appSettingsProvider.notifier)
                                    .setRequireBiometric(value),
                              ),
                            ) ??
                            const _ToggleSwitch(isOn: true),
                      ),
                    ],
                  ),
                  _SettingGroup(
                    title: 'Server',
                    children: [
                      _SettingRow(
                        label: 'Auto-start REST server',
                        subtitle: 'Binds to localhost:8432',
                        trailing: settingsAsync.whenOrNull(
                              data: (settings) => _ToggleSwitch(
                                isOn: settings.autoStartServer,
                                onChanged: (value) => ref
                                    .read(appSettingsProvider.notifier)
                                    .setAutoStartServer(value),
                              ),
                            ) ??
                            const _ToggleSwitch(isOn: true),
                      ),
                      _SettingRow(
                        label: 'MCP stdio adapter',
                        subtitle: 'For Claude Desktop / Cursor',
                        trailing: settingsAsync.whenOrNull(
                              data: (settings) => _ToggleSwitch(
                                isOn: settings.mcpAdapter,
                                onChanged: (value) => ref
                                    .read(appSettingsProvider.notifier)
                                    .setMcpAdapter(value),
                              ),
                            ) ??
                            const _ToggleSwitch(isOn: true),
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
                        trailing: _ActionButton(label: 'Export'),
                      ),
                      _SettingRow(
                        label: 'Wipe all data',
                        subtitle: 'Permanently destroy everything',
                        trailing: _ActionButton(
                          label: 'Wipe',
                          isDanger: true,
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

/// Animated toggle switch that propagates changes to [onChanged].
class _ToggleSwitch extends StatefulWidget {
  const _ToggleSwitch({required this.isOn, this.onChanged});

  final bool isOn;
  final ValueChanged<bool>? onChanged;

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
  void didUpdateWidget(_ToggleSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOn != widget.isOn) {
      _on = widget.isOn;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final bool next = !_on;
        setState(() => _on = next);
        widget.onChanged?.call(next);
      },
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, this.isDanger = false});

  final String label;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
