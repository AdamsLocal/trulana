import 'dart:convert';

import 'enums.dart';

/// A third-party application that has been granted (or denied) access
/// through the Gatekeeper Protocol.
///
/// `grantedScopes` is kept as a `List<String>` in Dart but serialised
/// to a JSON string for the single TEXT column in SQLite, because
/// sqflite does not support native JSON/array columns.
class AuthorizedAgent {
  final String agentId;
  final String agentName;
  final List<String> grantedScopes;
  final AgentStatus status;
  final DateTime expirationDate;

  const AuthorizedAgent({
    required this.agentId,
    required this.agentName,
    this.grantedScopes = const <String>[],
    this.status = AgentStatus.active,
    required this.expirationDate,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'agent_id': agentId,
        'agent_name': agentName,
        'granted_scopes': jsonEncode(grantedScopes),
        'status': status.value,
        'expiration_date': expirationDate.toIso8601String(),
      };

  factory AuthorizedAgent.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawScopes =
        jsonDecode(map['granted_scopes'] as String) as List<dynamic>;

    return AuthorizedAgent(
      agentId: map['agent_id'] as String,
      agentName: map['agent_name'] as String,
      grantedScopes: rawScopes.cast<String>(),
      status: AgentStatus.fromValue(map['status'] as String),
      expirationDate: DateTime.parse(map['expiration_date'] as String),
    );
  }

  AuthorizedAgent copyWith({
    String? agentId,
    String? agentName,
    List<String>? grantedScopes,
    AgentStatus? status,
    DateTime? expirationDate,
  }) =>
      AuthorizedAgent(
        agentId: agentId ?? this.agentId,
        agentName: agentName ?? this.agentName,
        grantedScopes: grantedScopes ?? this.grantedScopes,
        status: status ?? this.status,
        expirationDate: expirationDate ?? this.expirationDate,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthorizedAgent &&
          runtimeType == other.runtimeType &&
          agentId == other.agentId &&
          agentName == other.agentName &&
          _listEquals(grantedScopes, other.grantedScopes) &&
          status == other.status &&
          expirationDate == other.expirationDate;

  @override
  int get hashCode => Object.hash(
        agentId,
        agentName,
        Object.hashAll(grantedScopes),
        status,
        expirationDate,
      );

  @override
  String toString() => 'AuthorizedAgent(agentId: $agentId)';
}

/// Deep equality check for scope lists without pulling in `collection`.
bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
