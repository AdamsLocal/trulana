import 'package:flutter_test/flutter_test.dart';
import 'package:sovereign/models/models.dart';

void main() {
  test('Core models round-trip through toMap/fromMap', () {
    final config = UserConfig(
      id: 'test-id',
      privacyLevel: PrivacyLevel.strict,
      autoMonetize: true,
      walletAddress: '0xABC',
      vaultStatus: DateTime(2026, 3, 6),
    );

    final map = config.toMap();
    final restored = UserConfig.fromMap(map);

    expect(restored.id, config.id);
    expect(restored.privacyLevel, PrivacyLevel.strict);
    expect(restored.autoMonetize, true);
    expect(restored.walletAddress, '0xABC');
  });

  test('PrivacyLevel enum round-trips through int value', () {
    for (final level in PrivacyLevel.values) {
      expect(PrivacyLevel.fromValue(level.value), level);
    }
  });

  test('AgentStatus enum round-trips through string value', () {
    for (final status in AgentStatus.values) {
      expect(AgentStatus.fromValue(status.value), status);
    }
  });
}
