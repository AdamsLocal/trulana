import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:trulana/features/monetization/zk_commitment_engine.dart';

Future<Response> handleLeaseOffer(Request request) async {
  try {
    final payload = await request.readAsString();
    final Map<String, dynamic> body = jsonDecode(payload);
    
    final String requestedIntent = body['intent'] ?? '';
    
    // In a full build, this would query your local DB for the requested data.
    // For now, we mock the retrieval of the highly valuable context.
    final String valuableContext = "User's deep work schedule is 8AM-11AM. Do not interrupt.";
    
    if (requestedIntent.isEmpty) {
      return Response.badRequest(body: jsonEncode({'error': 'Intent missing'}));
    }

    // Generate the Zero-Knowledge Proof (The Commitment)
    final commitment = ZkCommitmentEngine.instance.generateCommitment(valuableContext);

    // We store the salt locally (in memory or DB) to reveal later
    final String hiddenSalt = commitment['salt']!;
    final String publicHash = commitment['hash']!;

    // We send back ONLY the hash. The agent must accept the contract based on this proof.
    return Response.ok(
      jsonEncode({
        'status': 'zk_escrow_initiated',
        'message': 'Data located. Verify hash and submit bounty token to unlock.',
        'cryptographic_proof': publicHash,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
  }
}
