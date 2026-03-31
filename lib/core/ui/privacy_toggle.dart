import 'package:flutter/material.dart';

import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/models/models.dart';

/// Privacy level toggle pill: Standard / Strict / Paranoid.
///
/// Shared by DashboardView and SettingsView.
class PrivacyToggleWidget extends StatelessWidget {
  const PrivacyToggleWidget({
    super.key,
    required this.level,
    required this.onChanged,
  });

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
