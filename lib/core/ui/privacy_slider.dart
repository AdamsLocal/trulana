import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sovereign/core/theme/sovereign_colors.dart';
import 'package:sovereign/models/models.dart';

/// Three-notch haptic slider for the Auto-Redact privacy level.
///
/// The track colour animates between cyan (Standard), amber (Strict),
/// and red (Paranoid) to give immediate visceral feedback about how
/// aggressively outbound data will be sanitised.
class PrivacySlider extends StatefulWidget {
  const PrivacySlider({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final PrivacyLevel value;
  final ValueChanged<PrivacyLevel> onChanged;

  @override
  State<PrivacySlider> createState() => _PrivacySliderState();
}

class _PrivacySliderState extends State<PrivacySlider> {
  static const _levels = PrivacyLevel.values;

  static const _levelColors = <PrivacyLevel, Color>{
    PrivacyLevel.standard: SovereignColors.primaryCyan,
    PrivacyLevel.strict: SovereignColors.warningAmber,
    PrivacyLevel.paranoid: SovereignColors.dangerRed,
  };

  static const _levelLabels = <PrivacyLevel, String>{
    PrivacyLevel.standard: 'Standard',
    PrivacyLevel.strict: 'Strict',
    PrivacyLevel.paranoid: 'Paranoid',
  };

  double get _sliderValue => widget.value.value.toDouble();

  Color get _activeColor =>
      _levelColors[widget.value] ?? SovereignColors.primaryCyan;

  void _onChanged(double v) {
    final snapped = v.round().clamp(1, 3);
    final level = PrivacyLevel.fromValue(snapped);
    if (level != widget.value) {
      HapticFeedback.mediumImpact();
      widget.onChanged(level);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _activeColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.15),
            thumbColor: Colors.transparent,
            overlayColor: color.withValues(alpha: 0.08),
            trackHeight: 4,
            thumbShape: _GlassThumbShape(color: color),
          ),
          child: Slider(
            value: _sliderValue,
            min: 1,
            max: 3,
            divisions: 2,
            onChanged: _onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final level in _levels)
                _NotchLabel(
                  label: _levelLabels[level]!,
                  color: level == widget.value
                      ? _levelColors[level]!
                      : SovereignColors.textTertiary,
                  active: level == widget.value,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Label rendered below each slider notch.
class _NotchLabel extends StatelessWidget {
  const _NotchLabel({
    required this.label,
    required this.color,
    required this.active,
  });

  final String label;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Glass-circle thumb that renders a frosted circle filled with
/// the current privacy-level colour at low opacity, surrounded
/// by a bright border ring.
class _GlassThumbShape extends SliderComponentShape {
  const _GlassThumbShape({required this.color});

  final Color color;

  static const _radius = 14.0;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // Glass fill
    canvas.drawCircle(
      center,
      _radius,
      Paint()..color = color.withValues(alpha: 0.15),
    );

    // Bright border
    canvas.drawCircle(
      center,
      _radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}
