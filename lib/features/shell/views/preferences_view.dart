import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/core/services/preferences_service.dart';
import 'package:trulana/models/models.dart';

/// Provider for loading all preferences.
final _preferencesProvider = FutureProvider<List<Preference>>((ref) async {
  return PreferencesService.instance.getAllPreferences();
});

/// Structured Preferences view matching the desktop HTML mockup.
///
/// Displays key-value pairs with scope tags in a clean list layout.
class PreferencesView extends ConsumerWidget {
  const PreferencesView({super.key});

  /// Fallback display data matching the HTML mockup when DB preferences
  /// don't have scope tags.
  static const List<_PrefDisplay> _fallbackPrefs = [
    _PrefDisplay(key: 'preferred_coffee', value: 'Philz, iced mint mojito', scope: 'routine'),
    _PrefDisplay(key: 'response_style', value: 'concise', scope: 'work'),
    _PrefDisplay(key: 'commute', value: 'Caltrain from San Francisco', scope: 'routine'),
    _PrefDisplay(key: 'workout_time', value: '6:30 AM', scope: 'health'),
    _PrefDisplay(key: 'work_style', value: 'deep focus mornings, meetings after 2 PM', scope: 'work'),
    _PrefDisplay(key: 'diet', value: 'Dairy-free, Mediterranean', scope: 'health'),
    _PrefDisplay(key: 'travel_airline', value: 'Delta, window, SkyMiles', scope: 'travel'),
    _PrefDisplay(key: 'meeting_default', value: '25 min, agenda-first', scope: 'work'),
  ];

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
              // Use DB prefs if available, fall back to display data
              final displayList = prefs.isNotEmpty
                  ? prefs
                      .map((p) => _PrefDisplay(
                            key: p.key,
                            value: p.value,
                            scope: p.tags.isNotEmpty ? p.tags.first : 'general',
                          ))
                      .toList()
                  : _fallbackPrefs;

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                itemCount: displayList.length,
                itemBuilder: (context, index) =>
                    _PrefRow(pref: displayList[index]),
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
          const Text(
            'Structured Preferences',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: TrulanaColors.textPrimary,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF2A8A84)),
              color: TrulanaColors.primaryCyan.withValues(alpha: 0.1),
            ),
            child: Text(
              '+ Add',
              style: TrulanaTheme.monoStyle.copyWith(
                fontSize: 10,
                color: TrulanaColors.primaryCyan,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrefRow extends StatelessWidget {
  const _PrefRow({required this.pref});

  final _PrefDisplay pref;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x05FFFFFF))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              pref.key,
              style: TrulanaTheme.monoStyle.copyWith(
                fontSize: 11,
                color: const Color(0xFF2A8A84),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              pref.value,
              style: const TextStyle(
                fontSize: 13,
                color: TrulanaColors.textSecondary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFF14142A)),
            ),
            child: Text(
              pref.scope,
              style: TrulanaTheme.monoStyle.copyWith(
                fontSize: 9,
                color: TrulanaColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrefDisplay {
  final String key;
  final String value;
  final String scope;

  const _PrefDisplay({
    required this.key,
    required this.value,
    required this.scope,
  });
}
