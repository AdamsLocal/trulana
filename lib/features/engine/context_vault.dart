/// Hardcoded in-memory vault of PII-rich "life context" entries for the
/// MVP demo. Each entry is tagged with keywords so the query handler can
/// match inbound queries to relevant context before piping it through
/// the Auto-Redact Engine.
///
/// Production replaces this with vector-DB retrieval; the interface
/// (keyword in, raw text out) stays the same.
class ContextVault {
  ContextVault._();
  static final ContextVault instance = ContextVault._();

  static const List<_VaultEntry> _entries = <_VaultEntry>[
    _VaultEntry(
      keywords: ['morning', 'routine', 'wake', 'gym', 'coffee'],
      raw: 'User wakes up at 6:30 AM, takes the 7:15 AM Caltrain from '
          'San Francisco to Palo Alto. Goes to Equinox for a 45-minute '
          'session, then picks up a Philz Coffee on the way to the office. '
          'Contact for gym buddy: Michael at michael.fit@gmail.com or '
          '415-555-0192.',
    ),
    _VaultEntry(
      keywords: ['work', 'job', 'office', 'colleague', 'meeting', 'team'],
      raw: 'Works at Google as a senior product manager. Direct reports '
          'include Sarah (sarah.chen@google.com, 650-555-0134) and '
          'James (james.okafor@google.com). Weekly 1:1 with VP David at '
          '10:00 AM every Tuesday. Office is in Building 40, Mountain View. '
          'Badge ID tied to SSN 478-33-9182.',
    ),
    _VaultEntry(
      keywords: ['finance', 'financial', 'money', 'bank', 'payment', 'card', 'salary'],
      raw: 'Primary checking at Chase, card ending 4111 1111 1111 1234. '
          'Monthly take-home after tax is \$12,450. Rent is \$3,200/month '
          'for the apartment in San Francisco. Auto-pay set up with card '
          '3782 822463 10005. Financial advisor is Robert at '
          'robert.wealth@schwab.com, phone 212-555-0198.',
    ),
    _VaultEntry(
      keywords: ['health', 'doctor', 'medical', 'fitness', 'prescription', 'patient'],
      raw: 'Primary care physician is Dr. Emily Park at Kaiser Permanente, '
          'San Francisco. Patient born in 1991, age 35, blood type O+. '
          'Current prescription for atorvastatin refilled monthly. '
          'Emergency contact: Jennifer at 510-555-0147. '
          'Patient portal login tied to emily.patient@kaiser.org. '
          'Last visit IP logged from 192.168.1.42.',
    ),
    _VaultEntry(
      keywords: ['travel', 'flight', 'hotel', 'trip', 'vacation', 'airport'],
      raw: 'Upcoming trip to Nashville on March 28. Delta flight DL1847 '
          'departing San Francisco at 8:45 AM, confirmation JKXR29. '
          'Hotel: The Hermitage, booked under Jane Smith, '
          'jane.s@outlook.com, phone +1-615-555-0123. '
          'Passport number redacted but SSN on file: 291-55-8734. '
          'Travel insurance through Amazon at \$89.99.',
    ),
    _VaultEntry(
      keywords: ['family', 'home', 'personal', 'kids', 'spouse', 'partner'],
      raw: 'Lives with partner Lisa in the Noe Valley neighborhood of '
          'San Francisco. Lisa works at Apple as a design lead. '
          'Two kids enrolled at Pleasanton Elementary. '
          'Home network IP: 10.0.0.1. Family plan phone: 415-555-0201. '
          'Joint savings goal: \$50,000 by end of year. '
          'Lisa turns aged 33 on April 12.',
    ),
  ];

  /// Returns raw (unredacted) context matching the query keywords.
  /// The caller is responsible for running the result through
  /// [AutoRedactEngine] before it leaves the device.
  List<String> query(String input) {
    if (input.isEmpty) return const <String>[];

    final List<String> queryTokens = input
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((String t) => t.length > 2)
        .toList();

    if (queryTokens.isEmpty) return const <String>[];

    final List<String> matches = <String>[];

    for (final _VaultEntry entry in _entries) {
      final bool hit = queryTokens.any(
        (String token) => entry.keywords.any(
          (String kw) => kw.contains(token) || token.contains(kw),
        ),
      );
      if (hit) matches.add(entry.raw);
    }

    return matches;
  }
}

class _VaultEntry {
  final List<String> keywords;
  final String raw;

  const _VaultEntry({required this.keywords, required this.raw});
}
