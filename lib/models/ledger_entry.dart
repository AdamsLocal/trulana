/// A settled micro-payment for anonymised data leased through the
/// Data Monetization Hub.
///
/// Each entry is keyed by a transaction hash so it can be
/// cross-referenced against on-chain or Stripe settlement records.
class LedgerEntry {
  final String txId;
  final String buyerName;

  /// Human-readable description of the data category that was sold
  /// (e.g. "Aggregated fitness trends Q1 2026").
  final String dataLeased;

  final double amountUsd;
  final DateTime timestamp;

  const LedgerEntry({
    required this.txId,
    required this.buyerName,
    required this.dataLeased,
    required this.amountUsd,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'tx_id': txId,
        'buyer_name': buyerName,
        'data_leased': dataLeased,
        'amount_usd': amountUsd,
        'timestamp': timestamp.toIso8601String(),
      };

  factory LedgerEntry.fromMap(Map<String, dynamic> map) => LedgerEntry(
        txId: map['tx_id'] as String,
        buyerName: map['buyer_name'] as String,
        dataLeased: map['data_leased'] as String,
        amountUsd: (map['amount_usd'] as num).toDouble(),
        timestamp: DateTime.parse(map['timestamp'] as String),
      );

  LedgerEntry copyWith({
    String? txId,
    String? buyerName,
    String? dataLeased,
    double? amountUsd,
    DateTime? timestamp,
  }) =>
      LedgerEntry(
        txId: txId ?? this.txId,
        buyerName: buyerName ?? this.buyerName,
        dataLeased: dataLeased ?? this.dataLeased,
        amountUsd: amountUsd ?? this.amountUsd,
        timestamp: timestamp ?? this.timestamp,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LedgerEntry &&
          runtimeType == other.runtimeType &&
          txId == other.txId &&
          buyerName == other.buyerName &&
          dataLeased == other.dataLeased &&
          amountUsd == other.amountUsd &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
        txId,
        buyerName,
        dataLeased,
        amountUsd,
        timestamp,
      );

  @override
  String toString() => 'LedgerEntry(txId: $txId)';
}
