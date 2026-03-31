import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/core/services/preferences_service.dart';
import 'package:trulana/models/models.dart';

/// Provider for loading all preferences from the encrypted database.
final _preferencesProvider = FutureProvider<List<Preference>>((ref) async {
  return PreferencesService.instance.getAllPreferences();
});

/// Structured Preferences view — live from the database.
class PreferencesView extends ConsumerWidget {
  const PreferencesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(_preferencesProvider);

    return Column(
      children: [
        _header(),
        Expanded(
          child: prefsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: TrulanaColors.primaryCyan,
                strokeWidth: 2,
              ),
            ),
            error: (e, s) => Center(
              child: Text('Failed to load preferences',
                  style: TextStyle(color: TrulanaColors.dangerRed)),
            ),
            data: (prefs) {
              if (prefs.isEmpty) {
                return Center(
                  child: Text('No preferences set',
                      style: TextStyle(
                          fontSize: 14,
                          color: TrulanaColors.textTertiary)),
                );
              }
              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 20),
                itemCount: prefs.length,
                itemBuilder: (context, index) =>
                    _PrefRow(pref: prefs[index]),
              );
            },
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
      child: Row(
        children: [
          const Text('Structured Preferences',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: TrulanaColors.textPrimary)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF2A8A84)),
              color: TrulanaColors.primaryCyan.withValues(alpha: 0.1),
            ),
            child: Text('+ Add',
                style: TrulanaTheme.monoStyle.copyWith(
                    fontSize: 10, color: TrulanaColors.primaryCyan)),
          ),
        ],
      ),
    );
  }
}

class _PrefRow extends StatelessWidget {
  const _PrefRow({required this.pref});

  final Preference pref;

  @override
  Widget build(BuildContext context) {
    final scope = pref.tags.isNotEmpty ? pref.tags.first : _inferScope(pref.key);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x05FFFFFF)))),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(pref.key,
                style: TrulanaTheme.monoStyle.copyWith(
                    fontSize: 11, color: const Color(0xFF2A8A84))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(pref.value,
                style: const TextStyle(
                    fontSize: 13, color: TrulanaColors.textSecondary)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFF14142A)),
            ),
            child: Text(scope,
                style: TrulanaTheme.monoStyle.copyWith(
                    fontSize: 9, color: TrulanaColors.textTertiary)),
          ),
        ],
      ),
    );
  }

  /// Infers a scope tag from the preference key when no tags are set.
  String _inferScope(String key) {
    if (key.contains('coffee') || key.contains('commute')) return 'routine';
    if (key.contains('work') || key.contains('response') || key.contains('meeting')) return 'work';
    if (key.contains('workout') || key.contains('diet')) return 'health';
    if (key.contains('travel') || key.contains('airline')) return 'travel';
    return 'general';
  }
}
