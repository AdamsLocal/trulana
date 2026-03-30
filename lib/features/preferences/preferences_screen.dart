import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trulana/core/theme/theme.dart';
import 'package:trulana/core/ui/ui.dart';
import 'package:trulana/models/models.dart';
import 'package:trulana/providers/preferences_provider.dart';

import 'widgets/add_edit_preference_sheet.dart';

/// Full-screen CRUD manager for the user's vault preferences.
///
/// Each row shows the preference key and value. Tapping a row opens
/// the edit sheet. A trailing delete icon (with confirmation dialog)
/// removes the preference from the encrypted local vault. The FAB
/// opens the add sheet.
class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Preference>> prefsAsync =
        ref.watch(preferencesProvider);

    return Scaffold(
      backgroundColor: TrulanaColors.background,
      body: MeshGradientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildHeader(context),
              Expanded(
                child: prefsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: TrulanaColors.primaryCyan,
                      strokeWidth: 2,
                    ),
                  ),
                  error: (Object error, StackTrace _) => Center(
                    child: Text(
                      'Failed to load preferences',
                      style: const TextStyle(
                        fontSize: 14,
                        color: TrulanaColors.dangerRed,
                      ),
                    ),
                  ),
                  data: (List<Preference> prefs) => prefs.isEmpty
                      ? _EmptyState(
                          onAdd: () => _showAddSheet(context, ref),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                          itemCount: prefs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (BuildContext context, int index) {
                            return AnimatedListItem(
                              index: index,
                              child: _PreferenceTile(
                                pref: prefs[index],
                                onEdit: () => _showEditSheet(
                                    context, ref, prefs[index]),
                                onDelete: () =>
                                    _confirmDelete(context, ref, prefs[index]),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, ref),
        backgroundColor: TrulanaColors.primaryCyan.withValues(alpha: 0.15),
        foregroundColor: TrulanaColors.primaryCyan,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: TrulanaColors.primaryCyan.withValues(alpha: 0.4),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: TrulanaColors.primaryCyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'My Vault',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: TrulanaColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(left: 32),
            child: Text(
              'The structured context AI agents query — never raw, always redacted.',
              style: TextStyle(
                fontSize: 12,
                color: TrulanaColors.textTertiary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TrulanaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AddEditPreferenceSheet(),
    );
  }

  Future<void> _showEditSheet(
    BuildContext context,
    WidgetRef ref,
    Preference pref,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TrulanaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddEditPreferenceSheet(existing: pref),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Preference pref,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: TrulanaColors.surface,
        title: const Text(
          'Remove preference?',
          style: TextStyle(color: TrulanaColors.textPrimary),
        ),
        content: Text(
          'Remove "${pref.key}" from your vault.',
          style: const TextStyle(color: TrulanaColors.textSecondary),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: TrulanaColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Remove',
              style: TextStyle(color: TrulanaColors.dangerRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(preferencesProvider.notifier).delete(pref.key);
    }
  }
}

// ── Preference tile ────────────────────────────────────────────────────────────

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.pref,
    required this.onEdit,
    required this.onDelete,
  });

  final Preference pref;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onEdit,
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 2,
            child: Text(
              pref.key,
              style: TrulanaTheme.monoStyle.copyWith(
                fontSize: 13,
                color: TrulanaColors.primaryCyan,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              pref.value,
              style: const TextStyle(
                fontSize: 13,
                color: TrulanaColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(
              Icons.delete_outline,
              size: 18,
              color: TrulanaColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.lock_outline,
            size: 48,
            color: TrulanaColors.primaryCyan.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your vault is empty',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: TrulanaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add preferences so AI agents can query\nyour context without seeing the raw data.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: TrulanaColors.textTertiary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: TrulanaColors.primaryCyan.withValues(alpha: 0.4),
                ),
                color: TrulanaColors.primaryCyan.withValues(alpha: 0.08),
              ),
              child: const Text(
                'Add your first preference',
                style: TextStyle(
                  color: TrulanaColors.primaryCyan,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
