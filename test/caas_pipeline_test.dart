import 'package:flutter_test/flutter_test.dart';
import 'package:trulana/features/monetization/zk_commitment_engine.dart';
import 'package:trulana/features/security/watermark_engine.dart';

void main() {
  group('2026 CaaS Pipeline Integration Test', () {
    const String highlyValuableContext = "User's deep work schedule is 8AM-11AM. Do not interrupt.";
    const String requestingAgentId = "cursor-mcp-agent-001";
    
    // Variables to hold the escrow state during the transaction
    late String publicHash;
    late String hiddenSalt;
    late String watermarkedPayload;

    test('Step 1: Escrow Initiated - Generate ZK Commitment', () {
      // The server generates the ZK proof instead of giving the data
      final commitment = ZkCommitmentEngine.instance.generateCommitment(highlyValuableContext);
      
      publicHash = commitment['hash']!;
      hiddenSalt = commitment['salt']!;

      expect(publicHash, isNotEmpty, reason: 'Hash must be generated');
      expect(hiddenSalt, isNotEmpty, reason: 'Salt must be generated securely');
      
      print('✅ Step 1 Passed: ZK Commitment Generated -> $publicHash');
    });

    test('Step 2: Escrow Settled - Agent Verifies Cryptographic Proof', () {
      // The agent pays, we reveal the salt and the data. 
      // The agent hashes them together to verify we didn't bait-and-switch them.
      final bool isValidProof = ZkCommitmentEngine.instance.verifyProof(
        publicHash, 
        hiddenSalt, 
        highlyValuableContext,
      );

      expect(isValidProof, isTrue, reason: 'The revealed salt and data must mathematically match the original hash');
      
      print('✅ Step 2 Passed: ZK Proof verified successfully by simulated agent.');
    });

    test('Step 3: Provenance Injected - Data is Holographically Watermarked', () {
      // We inject the invisible trace ID into the payload right before shipping it
      final String traceId = '$requestingAgentId:tx_89912';
      watermarkedPayload = WatermarkEngine.instance.injectHologram(highlyValuableContext, traceId);

      // To the naked eye (and standard string length checks if we strip zero-widths), it looks identical
      expect(watermarkedPayload, contains(highlyValuableContext));
      expect(watermarkedPayload.length, greaterThan(highlyValuableContext.length), 
        reason: 'The string must contain the hidden zero-width binary characters');

      print('✅ Step 3 Passed: Hologram injected. String looks normal but contains invisible trace.');
    });

    test('Step 4: The Audit - Extracting Leaked Provenance Data', () {
      // Imagine the agent leaked the context to a public forum. We scrape it and extract our mark.
      final String extractedTrace = WatermarkEngine.instance.extractHologram(watermarkedPayload);

      expect(extractedTrace, equals('$requestingAgentId:tx_89912'), 
        reason: 'The extracted watermark must exactly match the injected trace ID');
      
      print('✅ Step 4 Passed: Leak traced successfully! Extracted ID -> $extractedTrace');
    });
  });
}
