import 'enums.dart';

/// Root configuration for the vault owner.
/// Only one row should ever exist — the `id` acts as a singleton guard
/// so multiple devices can eventually merge without conflict.
class UserConfig {
  final String id;
  final PrivacyLevel privacyLevel;
  final bool autoMonetize;

  /// Nullable because the user may never opt into monetisation.
  /// When persisted, this value is AES-encrypted at the DB layer.
  final String? walletAddress;

  /// Tracks the last successful vault sync so the UI can surface
  /// staleness warnings when edge data is out of date.
  final DateTime vaultStatus;

  const UserConfig({
    required this.id,
    this.privacyLevel = PrivacyLevel.standard,
    this.autoMonetize = false,
    this.walletAddress,
    required this.vaultStatus,
  });

  /// Converts to a flat map suitable for `sqflite_sqlcipher` INSERT/UPDATE.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'privacy_level': privacyLevel.value,
        'auto_monetize': autoMonetize ? 1 : 0,
        'wallet_address': walletAddress,
        'vault_status': vaultStatus.toIso8601String(),
      };

  /// Reconstitutes from a SQLite row.
  factory UserConfig.fromMap(Map<String, dynamic> map) => UserConfig(
        id: map['id'] as String,
        privacyLevel: PrivacyLevel.fromValue(map['privacy_level'] as int),
        autoMonetize: (map['auto_monetize'] as int) == 1,
        walletAddress: map['wallet_address'] as String?,
        vaultStatus: DateTime.parse(map['vault_status'] as String),
      );

  UserConfig copyWith({
    String? id,
    PrivacyLevel? privacyLevel,
    bool? autoMonetize,
    String? walletAddress,
    DateTime? vaultStatus,
  }) =>
      UserConfig(
        id: id ?? this.id,
        privacyLevel: privacyLevel ?? this.privacyLevel,
        autoMonetize: autoMonetize ?? this.autoMonetize,
        walletAddress: walletAddress ?? this.walletAddress,
        vaultStatus: vaultStatus ?? this.vaultStatus,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserConfig &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          privacyLevel == other.privacyLevel &&
          autoMonetize == other.autoMonetize &&
          walletAddress == other.walletAddress &&
          vaultStatus == other.vaultStatus;

  @override
  int get hashCode => Object.hash(
        id,
        privacyLevel,
        autoMonetize,
        walletAddress,
        vaultStatus,
      );

  @override
  String toString() => 'UserConfig(id: $id)';
}
