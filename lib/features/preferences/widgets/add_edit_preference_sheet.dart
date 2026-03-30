import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/models/models.dart';
import 'package:trulana/providers/preferences_provider.dart';

/// Bottom sheet for adding a new preference or editing an existing one.
///
/// Pass [existing] to pre-fill the fields for an edit. For a new
/// preference, leave [existing] null. The sheet validates that both
/// fields are non-empty before calling [preferencesProvider.notifier].
class AddEditPreferenceSheet extends ConsumerStatefulWidget {
  const AddEditPreferenceSheet({this.existing, super.key});

  /// When non-null, the sheet is in edit mode.
  final Preference? existing;

  @override
  ConsumerState<AddEditPreferenceSheet> createState() =>
      _AddEditPreferenceSheetState();
}

class _AddEditPreferenceSheetState
    extends ConsumerState<AddEditPreferenceSheet> {
  late final TextEditingController _keyCtrl;
  late final TextEditingController _valueCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _keyCtrl =
        TextEditingController(text: widget.existing?.key ?? '');
    _valueCtrl =
        TextEditingController(text: widget.existing?.value ?? '');
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final String key = _keyCtrl.text.trim();
    final String value = _valueCtrl.text.trim();
    final notifier = ref.read(preferencesProvider.notifier);

    if (_isEditing) {
      await notifier.update(key, value);
    } else {
      await notifier.add(key, value);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit preference' : 'Add preference',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: TrulanaColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close,
                      color: TrulanaColors.textTertiary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _keyCtrl,
              enabled: !_isEditing,
              style: TrulanaTheme.monoStyle.copyWith(fontSize: 14),
              decoration: const InputDecoration(labelText: 'Key'),
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _valueCtrl,
              enabled: !_saving,
              style: const TextStyle(
                fontSize: 14,
                color: TrulanaColors.textPrimary,
              ),
              decoration: const InputDecoration(labelText: 'Value'),
              maxLines: 3,
              minLines: 1,
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: _SaveButton(saving: _saving, onTap: _save),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saving, required this.onTap});

  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: saving ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          color: TrulanaColors.primaryCyan.withValues(alpha: 0.12),
          border: Border.all(
            color: TrulanaColors.primaryCyan.withValues(alpha: 0.4),
          ),
        ),
        child: Center(
          child: saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: TrulanaColors.primaryCyan,
                  ),
                )
              : const Text(
                  'Save',
                  style: TextStyle(
                    color: TrulanaColors.primaryCyan,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}
