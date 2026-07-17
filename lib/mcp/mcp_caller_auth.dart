import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';

const String _protocol = 'trulana-mcp-auth-v1';
const Duration _defaultChallengeTtl = Duration(seconds: 60);
const int _defaultMaxOutstanding = 128;

typedef McpClock = DateTime Function();
typedef SecureBytes = List<int> Function(int length);

/// A short-lived, single-use challenge bound to an approved MCP caller.
class McpCallerChallenge {
  const McpCallerChallenge({
    required this.challengeId,
    required this.appId,
    required this.appName,
    required this.scopes,
    required this.intent,
    required this.publicKey,
    required this.publicKeyFingerprint,
    required this.issuedAt,
    required this.expiresAt,
    required this.signingPayloadBytes,
  });

  final String challengeId;
  final String appId;
  final String appName;
  final List<String> scopes;
  final String intent;
  final String publicKey;
  final String publicKeyFingerprint;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final List<int> signingPayloadBytes;

  String get signingPayload => _encodeBase64Url(signingPayloadBytes);

  Map<String, Object> toPublicMap() => <String, Object>{
        'challenge_id': challengeId,
        'algorithm': 'Ed25519',
        'signing_payload_encoding': 'base64url',
        'signing_payload': signingPayload,
        'public_key_fingerprint': publicKeyFingerprint,
        'expires_at': expiresAt.toUtc().toIso8601String(),
      };
}

class McpCallerAuthException implements Exception {
  const McpCallerAuthException(this.message, {this.appId});

  final String message;
  final String? appId;

  @override
  String toString() => message;
}

/// Issues and verifies replay-resistant Ed25519 challenges for MCP callers.
///
/// Challenges live only in memory, expire quickly, and are removed before a
/// signature is verified. A failed proof therefore cannot be retried, and a
/// successful proof cannot be replayed.
class McpCallerAuth {
  McpCallerAuth({
    McpClock? clock,
    SecureBytes? secureBytes,
    SignatureAlgorithm? algorithm,
    this.challengeTtl = _defaultChallengeTtl,
    this.maxOutstanding = _defaultMaxOutstanding,
  })  : _clock = clock ?? DateTime.now,
        _secureBytes = secureBytes ?? _randomBytes,
        _algorithm = algorithm ?? Ed25519();

  final McpClock _clock;
  final SecureBytes _secureBytes;
  final SignatureAlgorithm _algorithm;
  final Duration challengeTtl;
  final int maxOutstanding;
  final Map<String, McpCallerChallenge> _challenges =
      <String, McpCallerChallenge>{};

  McpCallerChallenge issue({
    required String appId,
    required String appName,
    required List<String> scopes,
    required String intent,
    required String publicKey,
  }) {
    final String normalizedKey = normalizePublicKey(publicKey);
    final DateTime now = _clock().toUtc();
    _pruneExpired(now);

    // One live challenge per approved identity limits memory use and makes a
    // new request explicitly supersede an older one.
    _challenges.removeWhere((_, value) => value.appId == appId);
    if (_challenges.length >= maxOutstanding) {
      throw const McpCallerAuthException(
        'Too many outstanding authentication challenges. Try again shortly.',
      );
    }

    final String challengeId = _encodeBase64Url(_secureBytes(24));
    final String nonce = _encodeBase64Url(_secureBytes(32));
    final DateTime expiresAt = now.add(challengeTtl);
    final String fingerprint = publicKeyFingerprint(normalizedKey);

    // jsonEncode preserves insertion order for this literal. Callers sign the
    // returned bytes directly, so no independent canonicalization is needed.
    final List<int> payload = utf8.encode(jsonEncode(<String, Object>{
      'protocol': _protocol,
      'challenge_id': challengeId,
      'app_id': appId,
      'public_key_fingerprint': fingerprint,
      'nonce': nonce,
      'issued_at': now.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
    }));

    final McpCallerChallenge challenge = McpCallerChallenge(
      challengeId: challengeId,
      appId: appId,
      appName: appName,
      scopes: List<String>.unmodifiable(scopes),
      intent: intent,
      publicKey: normalizedKey,
      publicKeyFingerprint: fingerprint,
      issuedAt: now,
      expiresAt: expiresAt,
      signingPayloadBytes: List<int>.unmodifiable(payload),
    );
    _challenges[challengeId] = challenge;
    return challenge;
  }

  Future<McpCallerChallenge> verify({
    required String challengeId,
    required String signature,
  }) async {
    // Consume before checking expiry or signature. Every proof attempt is
    // single-use, including a malformed or invalid one.
    final McpCallerChallenge? challenge = _challenges.remove(challengeId);
    if (challenge == null) {
      throw const McpCallerAuthException(
        'Unknown, expired, or already-used authentication challenge.',
      );
    }

    if (!_clock().toUtc().isBefore(challenge.expiresAt)) {
      throw McpCallerAuthException(
        'Authentication challenge expired.',
        appId: challenge.appId,
      );
    }

    final List<int> signatureBytes;
    try {
      signatureBytes = _decodeBase64Url(signature);
    } on FormatException {
      throw McpCallerAuthException(
        'Signature must be base64url-encoded Ed25519 bytes.',
        appId: challenge.appId,
      );
    }
    if (signatureBytes.length != 64) {
      throw McpCallerAuthException(
        'Ed25519 signatures must be exactly 64 bytes.',
        appId: challenge.appId,
      );
    }

    final List<int> publicKeyBytes = _decodeBase64Url(challenge.publicKey);
    final Signature proof = Signature(
      signatureBytes,
      publicKey: SimplePublicKey(
        publicKeyBytes,
        type: KeyPairType.ed25519,
      ),
    );
    final bool valid = await _algorithm.verify(
      challenge.signingPayloadBytes,
      signature: proof,
    );
    if (!valid) {
      throw McpCallerAuthException(
        'Invalid MCP caller signature.',
        appId: challenge.appId,
      );
    }

    return challenge;
  }

  static String normalizePublicKey(String value) {
    final List<int> bytes;
    try {
      bytes = _decodeBase64Url(value.trim());
    } on FormatException {
      throw const McpCallerAuthException(
        'public_key must be a base64url-encoded Ed25519 public key.',
      );
    }
    if (bytes.length != 32) {
      throw const McpCallerAuthException(
        'Ed25519 public keys must be exactly 32 bytes.',
      );
    }
    return _encodeBase64Url(bytes);
  }

  static String publicKeyFingerprint(String normalizedPublicKey) {
    final List<int> bytes = _decodeBase64Url(normalizedPublicKey);
    return 'SHA256:${hashes.sha256.convert(bytes)}';
  }

  void _pruneExpired(DateTime now) {
    _challenges.removeWhere(
      (_, challenge) => !now.isBefore(challenge.expiresAt),
    );
  }

  static List<int> _randomBytes(int length) {
    final Random random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}

String _encodeBase64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

List<int> _decodeBase64Url(String value) {
  if (value.isEmpty || !RegExp(r'^[A-Za-z0-9_-]+={0,2}$').hasMatch(value)) {
    throw const FormatException('Invalid base64url');
  }
  final String unpadded = value.replaceAll('=', '');
  final int remainder = unpadded.length % 4;
  if (remainder == 1) throw const FormatException('Invalid base64url length');
  final String padded = unpadded.padRight(
    unpadded.length + ((4 - remainder) % 4),
    '=',
  );
  return base64Url.decode(padded);
}
