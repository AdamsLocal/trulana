import 'package:flutter/material.dart';
import 'package:sovereign/core/theme/sovereign_colors.dart';

/// Compact pill-shaped badge for agent lifecycle states (ACTIVE,
/// REVOKED, PAUSED). If no explicit [color] is provided, the badge
/// auto-detects an appropriate hue from the [label] text so callers
/// can simply pass the raw status string from the database.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    this.color,
    super.key,
  });

  final String label;
  final Color? color;

  Color get _resolvedColor {
    if (color != null) return color!;
    return switch (label.toLowerCase()) {
      'active' => SovereignColors.successGreen,
      'revoked' => SovereignColors.dangerRed,
      'paused' => SovereignColors.warningAmber,
      _ => SovereignColors.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = _resolvedColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: c,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
