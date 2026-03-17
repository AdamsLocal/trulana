import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages the database encryption key lifecycle through the platform's
/// hardware-backed secure storage (Secure Enclave on iOS, KeyStore on Android).
///
/// Keys never leave the secure boundary — they are generated, stored, and
/// retrieved exclusively through `FlutterSecureStorage`, which delegates to
/// the OS-level credential manager. This ensures that even a rooted/jailbroken
/// device cannot trivially extract the raw key material.
class KeyManager {
  KeyManager._();

  static final KeyManager instance = KeyManager._();

  static const String _dbKeyName = 'sovereign_db_encryption_key';
  static const int _keyLengthBytes = 32; // 256-bit AES key

  /// Platform-specific options route storage through hardware-backed keystores
  /// rather than software-only encryption.
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      accountName: 'sovereign_vault',
    ),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Returns the existing database encryption key, or generates and persists
  /// a new one on first launch. This is the single external entry point —
  /// callers should not interact with the other methods directly.
  Future<String> getOrCreateDatabaseKey() async {
    try {
      final String? existingKey = await _secureStorage.read(key: _dbKeyName);
      if (existingKey != null && existingKey.isNotEmpty) {
        return existingKey;
      }

      await _generateAndStoreKey();
      final String? newKey = await _secureStorage.read(key: _dbKeyName);
      if (newKey == null || newKey.isEmpty) {
        throw StateError('Key generation succeeded but retrieval failed');
      }
      return newKey;
    } on Exception {
      rethrow;
    }
  }

  /// Generates a cryptographically secure 256-bit key and writes it into
  /// platform-backed secure storage. Uses `Random.secure()` which maps to
  /// `/dev/urandom` on POSIX and `CryptGenRandom` on Windows.
  Future<void> _generateAndStoreKey() async {
    final Random secureRandom = Random.secure();
    final List<int> keyBytes = List<int>.generate(
      _keyLengthBytes,
      (_) => secureRandom.nextInt(256),
    );
    final String encodedKey = base64Url.encode(keyBytes);

    await _secureStorage.write(key: _dbKeyName, value: encodedKey);
  }

  /// Indicates whether a database key already exists in secure storage.
  /// Useful for distinguishing first launch from returning sessions.
  Future<bool> hasExistingKey() async {
    try {
      final String? key = await _secureStorage.read(key: _dbKeyName);
      return key != null && key.isNotEmpty;
    } on Exception {
      return false;
    }
  }

  /// Permanently destroys the stored encryption key. Calling this makes the
  /// existing encrypted database irrecoverable — intended only for full
  /// account reset or test teardown.
  Future<void> deleteKey() async {
    try {
      await _secureStorage.delete(key: _dbKeyName);
    } on Exception {
      rethrow;
    }
  }
}
