import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Implements the `verified_search` MCP tool.
///
/// Given a single [query] string the tool:
///   1. Derives five distinct search-query formulations using established
///      Boolean/syntax best-practices (plain, exact-phrase, authoritative-
///      domain, opinion-filtered, research-framed).
///   2. Executes all five queries concurrently against the Brave Search API.
///   3. Deduplicates results by URL, scores every unique result using
///      domain-authority tier, recency, cross-variant validation, snippet
///      quality, and HTTPS trust signals, then returns the top-ranked items
///      in descending factuality_score order.
///
/// Required environment variable:
///   ANSWERS_API_KEY  – Brave Search API subscription token.
///                      Free tier: 2,000 queries/month.
///                      Sign up at https://brave.com/search/api/
///
/// The class name is intentionally kept as GoogleSearchTool to avoid a
/// rename cascade across the codebase; the underlying API is Brave Search.
class GoogleSearchTool {
  GoogleSearchTool._();

  static const String _apiHost = 'api.search.brave.com';
  static const String _apiPath = '/res/v1/web/search';
  static const int _resultsPerVariant = 10;
  static const int _topN = 10;
  static const Duration _timeout = Duration(seconds: 10);

  // ── Public entry point ──────────────────────────────────────────

  static Future<Map<String, Object?>> execute(
    Map<String, Object?> args,
  ) async {
    final String? rawQuery = args['query'] as String?;
    if (rawQuery == null || rawQuery.trim().isEmpty) {
      return _err('query parameter is required and must be non-empty.');
    }

    final String apiKey = Platform.environment['ANSWERS_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return _err(
        'Server misconfiguration: ANSWERS_API_KEY environment variable '
        'must be set. Obtain a free key at https://brave.com/search/api/',
      );
    }

    final String query = rawQuery.trim();

    // Step 1 – derive five syntactically distinct search queries.
    final List<_QueryVariant> variants = _buildVariants(query);

    // Step 2 – run all five searches concurrently.
    final List<List<_SearchResult>> resultSets = await Future.wait(
      variants.map((v) => _fetchResults(v.query, apiKey)),
    );

    // Step 3 – merge, deduplicate, score, and rank.
    final List<_ScoredResult> ranked = _rankResults(resultSets, variants);

    return <String, Object?>{
      'success': true,
      'original_query': query,
      'search_variants': variants
          .map((v) => <String, Object?>{
                'index': v.index + 1,
                'label': v.label,
                'query': v.query,
              })
          .toList(),
      'result_count': ranked.length,
      'results': ranked.map((r) => r.toJson()).toList(),
      // This instruction is embedded in the tool RESPONSE so the LLM
      // reads it as part of the returned data — more reliable than
      // description-level imperatives which models may ignore.
      'grounding_instruction':
          'FACTUAL GROUNDING REQUIRED: Your response must be based exclusively '
          'on the results listed above. Use only results with a factuality_score '
          'of 7.0 or higher unless no such results exist. Include an inline '
          'citation [url] for every factual claim. Do not assert anything '
          'that cannot be traced to at least one result in this list.',
    };
  }

  // ── Query variant builder ────────────────────────────────────────

  static List<_QueryVariant> _buildVariants(String query) {
    // Extract the longest word (> 4 chars) as the "key term" for exact-phrase
    // wrapping. Falls back to the whole query if no such word exists.
    final List<String> words = query
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 4)
        .toList();
    final String keyTerm = words.isNotEmpty ? words.first : query;

    final String withoutKey =
        words.isNotEmpty ? query.replaceFirst(keyTerm, '').trim() : '';
    final String variant2Base =
        withoutKey.isEmpty ? '"$keyTerm"' : '"$keyTerm" $withoutKey';

    return [
      _QueryVariant(
        index: 0,
        label: 'plain',
        query: query,
      ),
      _QueryVariant(
        index: 1,
        label: 'exact-phrase key-term',
        query: variant2Base.trim(),
      ),
      _QueryVariant(
        index: 2,
        label: 'authoritative-domain (gov/edu)',
        query: '$query site:gov OR site:edu',
      ),
      _QueryVariant(
        index: 3,
        label: 'opinion-filtered',
        query: '$query '
            '-site:reddit.com -site:quora.com '
            '-site:pinterest.com -site:yahoo.com',
      ),
      _QueryVariant(
        index: 4,
        label: 'research-framed',
        query: 'facts "$query" research OR study OR report OR data',
      ),
    ];
  }

  // ── Brave Search API ─────────────────────────────────────────────

  static Future<List<_SearchResult>> _fetchResults(
    String query,
    String apiKey,
  ) async {
    try {
      final Uri uri = Uri.https(
        _apiHost,
        _apiPath,
        <String, String>{
          'q': query,
          'count': '$_resultsPerVariant',
          'safesearch': 'moderate',
          'text_decorations': 'false',
        },
      );

      final HttpClient client = HttpClient()
        ..connectionTimeout = _timeout;

      final HttpClientRequest request =
          await client.getUrl(uri).timeout(_timeout);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set('X-Subscription-Token', apiKey)
        ..set('Accept-Encoding', 'gzip');

      final HttpClientResponse response =
          await request.close().timeout(_timeout);
      final String body =
          await response.transform(utf8.decoder).join().timeout(_timeout);
      client.close();

      if (response.statusCode != 200) return <_SearchResult>[];

      final Object? decoded = jsonDecode(body);
      if (decoded is! Map<String, Object?>) return <_SearchResult>[];

      final Map<String, Object?>? web =
          decoded['web'] as Map<String, Object?>?;
      final List<Object?> items =
          (web?['results'] as List<Object?>?) ?? <Object?>[];

      return items.whereType<Map<String, Object?>>().map((m) {
        // Brave returns `page_age` as an ISO-8601 string when known.
        final String? pageAge = m['page_age'] as String?;
        DateTime? publishedAt;
        if (pageAge != null) {
          publishedAt = DateTime.tryParse(pageAge);
        }

        // `profile` contains the site name/category for extra domain signals.
        final Map<String, Object?>? profile =
            m['profile'] as Map<String, Object?>?;
        final String profileName =
            (profile?['name'] as String?) ?? '';

        return _SearchResult(
          title: (m['title'] as String?) ?? '',
          url: (m['url'] as String?) ?? '',
          snippet: (m['description'] as String?) ?? '',
          displayLink: Uri.tryParse((m['url'] as String?) ?? '')?.host ?? '',
          publishedAt: publishedAt,
          profileName: profileName,
          isHttps: ((m['url'] as String?) ?? '').startsWith('https://'),
        );
      }).toList();
    } catch (_) {
      // Individual variant failures are tolerated; remaining variants still
      // contribute to the merged result set.
      return <_SearchResult>[];
    }
  }

  // ── Result merging, scoring, and ranking ─────────────────────────

  static List<_ScoredResult> _rankResults(
    List<List<_SearchResult>> resultSets,
    List<_QueryVariant> variants,
  ) {
    final Map<String, _ScoredResult> byUrl = <String, _ScoredResult>{};

    for (int vi = 0; vi < resultSets.length; vi++) {
      for (final _SearchResult r in resultSets[vi]) {
        if (r.url.isEmpty) continue;
        if (byUrl.containsKey(r.url)) {
          byUrl[r.url]!.crossHits++;
        } else {
          byUrl[r.url] = _ScoredResult(
            result: r,
            sourceVariantIndex: vi,
            sourceVariantLabel: variants[vi].label,
          );
        }
      }
    }

    final List<_ScoredResult> all = byUrl.values.toList();
    for (final _ScoredResult s in all) {
      s.factualityScore = _computeScore(s);
    }

    all.sort((a, b) => b.factualityScore.compareTo(a.factualityScore));
    return all.take(_topN).toList();
  }

  static double _computeScore(_ScoredResult s) {
    double score = 0.0;
    final String host = s.result.displayLink.toLowerCase();

    // ── Domain-authority tier ──────────────────────────────────────
    if (host.endsWith('.gov')) {
      score += 12.0;
    } else if (host.endsWith('.edu')) {
      score += 11.0;
    } else if (_isEstablishedReference(host)) {
      score += 9.0;
    } else if (host.endsWith('.org')) {
      score += 7.0;
    } else {
      score += 4.0;
    }

    // ── HTTPS trust signal ─────────────────────────────────────────
    if (s.result.isHttps) score += 1.0;

    // ── Cross-validation bonus ─────────────────────────────────────
    // Each additional variant that independently returned this URL adds
    // confidence that the source is widely indexed and relevant.
    score += s.crossHits * 3.0;

    // ── Recency bonus ──────────────────────────────────────────────
    final DateTime? pub = s.result.publishedAt;
    if (pub != null) {
      final int daysOld = DateTime.now().difference(pub).inDays;
      if (daysOld <= 30) {
        score += 2.0;
      } else if (daysOld <= 365) {
        score += 1.0;
      }
      // Content older than 5 years gets a slight penalty for factual queries.
      if (daysOld > 1825) score -= 1.0;
    }

    // ── Snippet-quality signal ─────────────────────────────────────
    final int len = s.result.snippet.length;
    if (len > 250) {
      score += 2.0;
    } else if (len > 120) {
      score += 1.0;
    }

    // ── Low-quality-domain penalty ─────────────────────────────────
    if (_isLowQualityDomain(host)) score -= 6.0;

    return score;
  }

  static bool _isEstablishedReference(String host) {
    const List<String> refs = <String>[
      'wikipedia.org',
      'britannica.com',
      'nature.com',
      'science.org',
      'pubmed.ncbi.nlm.nih.gov',
      'ncbi.nlm.nih.gov',
      'who.int',
      'cdc.gov',
      'nytimes.com',
      'reuters.com',
      'apnews.com',
      'bbc.com',
      'bbc.co.uk',
      'theguardian.com',
      'wsj.com',
      'scientificamerican.com',
      'pnas.org',
      'arxiv.org',
      'smithsonianmag.com',
      'nationalgeographic.com',
    ];
    return refs.any(host.contains);
  }

  static bool _isLowQualityDomain(String host) {
    const List<String> low = <String>[
      'reddit.com',
      'quora.com',
      'pinterest.com',
      'answers.com',
      'ask.com',
      'buzzfeed.com',
      'ranker.com',
    ];
    return low.any(host.contains);
  }

  static Map<String, Object?> _err(String message) =>
      <String, Object?>{'success': false, 'error': message};
}

// ── Internal data classes ─────────────────────────────────────────

class _QueryVariant {
  const _QueryVariant({
    required this.index,
    required this.label,
    required this.query,
  });

  final int index;
  final String label;
  final String query;
}

class _SearchResult {
  const _SearchResult({
    required this.title,
    required this.url,
    required this.snippet,
    required this.displayLink,
    required this.isHttps,
    this.publishedAt,
    this.profileName = '',
  });

  final String title;
  final String url;
  final String snippet;
  final String displayLink;
  final bool isHttps;
  final DateTime? publishedAt;
  final String profileName;
}

class _ScoredResult {
  _ScoredResult({
    required this.result,
    required this.sourceVariantIndex,
    required this.sourceVariantLabel,
  });

  final _SearchResult result;
  final int sourceVariantIndex;
  final String sourceVariantLabel;

  /// Number of *additional* variants (beyond the first) that also returned
  /// this URL. Higher = cross-validated by multiple independent queries.
  int crossHits = 0;

  double factualityScore = 0.0;

  Map<String, Object?> toJson() {
    final Map<String, Object?> m = <String, Object?>{
      'title': result.title,
      'url': result.url,
      'snippet': result.snippet,
      'source_domain': result.displayLink,
      'factuality_score': double.parse(factualityScore.toStringAsFixed(1)),
      'cross_validated': crossHits > 0,
      'cross_validation_hits': crossHits,
      'https': result.isHttps,
      'first_found_in_variant': sourceVariantLabel,
    };
    if (result.publishedAt != null) {
      m['published_at'] = result.publishedAt!.toIso8601String();
    }
    return m;
  }
}
