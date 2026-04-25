import 'dart:io' show stderr;

import 'package:flutter/foundation.dart';

/// Dev-safe structured logger that emits only operational metadata.
///
/// Never logs raw text, query content, PII, token values, or database
/// payloads. Output is limited to: route, HTTP method, status code,
/// agent ID, action type, and redaction counts.
///
/// In normal (REST/UI) mode, uses [debugPrint] so output appears in
/// the `flutter run` terminal. In MCP mode, writes to stderr so
/// stdout remains a clean JSON-RPC channel.
class SafeLogger {
  SafeLogger._();

  static const String _tag = 'Trulana';

  static bool _mcpMode = false;
  static void Function(String)? _testSink;

  /// Call once at startup before any logging occurs. Routes all
  /// subsequent output to stderr instead of stdout.
  static void enableMcpMode() => _mcpMode = true;

  /// Test-only hook. When set, log output is routed to this callback
  /// instead of debugPrint/stderr, enabling assertions on log content.
  static void setTestSink(void Function(String)? sink) => _testSink = sink;

  static void serverStart(int port) {
    _log('Server started on 127.0.0.1:$port');
  }

  static void serverStop() {
    _log('Server stopped');
  }

  static void mcpStart() {
    _log('MCP stdio server ready');
  }

  static void authGranted({
    required String agentId,
    required int ttlSeconds,
  }) {
    _log('auth/request_access -> granted'
        ' | agent=$agentId'
        ' | ttl=${ttlSeconds}s');
  }

  static void authRejected({
    required int statusCode,
    String? agentId,
  }) {
    final String agentPart = agentId != null ? ' | agent=$agentId' : '';
    _log('auth/request_access -> $statusCode'
        '$agentPart'
        ' | action=rejected');
  }

  static void contextQuery({
    required String agentId,
    required String privacyLevel,
    required int redactions,
    required int vaultHits,
  }) {
    _log('context/query -> 200'
        ' | agent=$agentId'
        ' | redactions=$redactions'
        ' | level=$privacyLevel'
        ' | vault_hits=$vaultHits');
  }

  static void preferenceUpdated({required String key}) {
    _log('preference/set | key=$key');
  }

  static void preferenceDeleted({required String key}) {
    _log('preference/delete | key=$key');
  }

  static void contextQueryRejected({
    required int statusCode,
    String? agentId,
  }) {
    final String agentPart = agentId != null ? ' | agent=$agentId' : '';
    _log('context/query -> $statusCode'
        '$agentPart'
        ' | action=rejected');
  }

  static void monetizeRejected({
    required int statusCode,
    String? agentId,
  }) {
    final String agentPart = agentId != null ? ' | agent=$agentId' : '';
    _log('monetize/lease_offer -> $statusCode'
        '$agentPart'
        ' | action=rejected');
  }

  static void _log(String message) {
    final String line = '[$_tag] $message';
    if (_testSink != null) {
      _testSink!(line);
    } else if (_mcpMode) {
      stderr.writeln(line);
    } else {
      debugPrint(line);
    }
  }
}
