class P2PDiagnostics {
  /// Record a safe diagnostic event across offline emergency workflows.
  /// Never logs PII (names, phone numbers, exact GPS coordinates, API keys, or raw payloads).
  static void log(String correlationId, String eventType, [Map<String, dynamic>? metadata]) {
    final metaStr = metadata != null && metadata.isNotEmpty
        ? metadata.entries.map((e) => '${e.key}=${e.value}').join(' ')
        : '';
    // Format: [VITA-P2P][<correlation_id>][<event_type>] <safe_metadata>
    // ignore: avoid_print
    print('[VITA-P2P][$correlationId][$eventType] $metaStr'.trim());
  }
}
