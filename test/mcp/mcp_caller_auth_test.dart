import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trulana/mcp/mcp_caller_auth.dart';

void main() {
  final Ed25519 algorithm = Ed25519();
  int randomCounter = 0;

  List<int> deterministicBytes(int length) {
    randomCounter++;
    return List<int>.generate(
      length,
      (int index) => (index + randomCounter) % 256,
    );
  }

  String encode(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  Future<({SimpleKeyPair keyPair, String publicKey})> newIdentity() async {
    final SimpleKeyPair keyPair = await algorithm.newKeyPair();
    final SimplePublicKey publicKey = await keyPair.extractPublicKey();
    return (keyPair: keyPair, publicKey: encode(publicKey.bytes));
  }

  McpCallerChallenge issue(McpCallerAuth auth, String publicKey) {
    return auth.issue(
      appId: 'agent.test',
      appName: 'Test Agent',
      scopes: const <String>['context.read'],
      intent: 'Read approved context',
      publicKey: publicKey,
    );
  }

  group('McpCallerAuth', () {
    test('accepts a valid Ed25519 proof exactly once', () async {
      final identity = await newIdentity();
      final McpCallerAuth auth = McpCallerAuth(
        secureBytes: deterministicBytes,
      );
      final McpCallerChallenge challenge = issue(auth, identity.publicKey);
      final Signature signature = await algorithm.sign(
        challenge.signingPayloadBytes,
        keyPair: identity.keyPair,
      );

      final McpCallerChallenge verified = await auth.verify(
        challengeId: challenge.challengeId,
        signature: encode(signature.bytes),
      );
      expect(verified.appId, 'agent.test');

      await expectLater(
        auth.verify(
          challengeId: challenge.challengeId,
          signature: encode(signature.bytes),
        ),
        throwsA(isA<McpCallerAuthException>()),
      );
    });

    test('wrong-key proof fails and consumes the challenge', () async {
      final approved = await newIdentity();
      final attacker = await newIdentity();
      final McpCallerAuth auth = McpCallerAuth(
        secureBytes: deterministicBytes,
      );
      final McpCallerChallenge challenge = issue(auth, approved.publicKey);
      final Signature wrongSignature = await algorithm.sign(
        challenge.signingPayloadBytes,
        keyPair: attacker.keyPair,
      );

      await expectLater(
        auth.verify(
          challengeId: challenge.challengeId,
          signature: encode(wrongSignature.bytes),
        ),
        throwsA(
          isA<McpCallerAuthException>().having(
            (McpCallerAuthException error) => error.message,
            'message',
            contains('Invalid'),
          ),
        ),
      );

      final Signature correctSignature = await algorithm.sign(
        challenge.signingPayloadBytes,
        keyPair: approved.keyPair,
      );
      await expectLater(
        auth.verify(
          challengeId: challenge.challengeId,
          signature: encode(correctSignature.bytes),
        ),
        throwsA(isA<McpCallerAuthException>()),
      );
    });

    test('expired proof fails and consumes the challenge', () async {
      final identity = await newIdentity();
      DateTime now = DateTime.utc(2026, 7, 17, 12);
      final McpCallerAuth auth = McpCallerAuth(
        clock: () => now,
        secureBytes: deterministicBytes,
        challengeTtl: const Duration(seconds: 10),
      );
      final McpCallerChallenge challenge = issue(auth, identity.publicKey);
      final Signature signature = await algorithm.sign(
        challenge.signingPayloadBytes,
        keyPair: identity.keyPair,
      );
      now = now.add(const Duration(seconds: 10));

      await expectLater(
        auth.verify(
          challengeId: challenge.challengeId,
          signature: encode(signature.bytes),
        ),
        throwsA(
          isA<McpCallerAuthException>().having(
            (McpCallerAuthException error) => error.message,
            'message',
            contains('expired'),
          ),
        ),
      );
    });

    test('proof is bound to the exact returned payload', () async {
      final identity = await newIdentity();
      final McpCallerAuth auth = McpCallerAuth(
        secureBytes: deterministicBytes,
      );
      final McpCallerChallenge challenge = issue(auth, identity.publicKey);
      final Signature signature = await algorithm.sign(
        utf8.encode('a different challenge for another caller'),
        keyPair: identity.keyPair,
      );

      await expectLater(
        auth.verify(
          challengeId: challenge.challengeId,
          signature: encode(signature.bytes),
        ),
        throwsA(isA<McpCallerAuthException>()),
      );
    });

    test('rejects malformed public keys before issuing a challenge', () {
      final McpCallerAuth auth = McpCallerAuth(
        secureBytes: deterministicBytes,
      );

      expect(
        () => issue(auth, encode(List<int>.filled(31, 0))),
        throwsA(isA<McpCallerAuthException>()),
      );
      expect(
        () => issue(auth, 'not+base64url'),
        throwsA(isA<McpCallerAuthException>()),
      );
    });
  });
}
