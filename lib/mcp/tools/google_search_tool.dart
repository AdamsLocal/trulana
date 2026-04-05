import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Implements the `verified_search` MCP tool.
///
/// Given a single [query] string the tool:
///   1. Derives five distinct search-query formulations using established
///      Boolean/syntax best-practices (plain, exact-phrase, authoritative-
///      domain, opinion-filtered, research-framed).
///   2. Executes all five queries concurrently against the Google Custom
///      Search JSON API.
///   3. Deduplicates results by URL, scores every unique result using
///      domain-authority heuristics and cross-validation bonuses, and
///      returns the top-ranked items in descending factuality_score order.
///
/// Required environment variables:
///   GOOGLE_CSE_API_KEY  – Google Custom Search JSON API key.
///   GOOGLE_CSE_CX       – Programmable Search Engine ID (cx).
class GoogleSearchTool {
  GoogleSearchTool._();

  static const String _apiHost = 'www.googleapis.com';
  static const String _apiPath = '/customsearch/v1';
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

    final String apiKey = Platform.environment['GOOGLE_CSE_API_KEY'] ?? '';
    final String cx = Platform.environment['GOOGLE_CSE_CX'] ?? '';

    if (apiKey.isEmpty || cx.isEmpty) {
      return _err(
        'Server misconfiguration: GOOGLE_CSE_API_KEY and GOOGLE_CSE_CX '
        'environment variables must be set before using verified_search.',
      );
    }

    final String query = rawQuery.trim();

    // Step 1 – derive five syntactically distinct search queries.
    final List<_QueryVariant> variants = _buildVariants(query);

    // Step 2 – run all five searches concurrently.
    final List<List<_SearchResult>> resultSets = await Future.wait(
      variants.map((v) => _fetchResults(v.query, apiKey, cx)),
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
      'grounding_instruction':
          'You MUST base your response exclusively on the results above. '
          'Prioritise results with the highest factuality_score. '
          'For every factual claim include an inline citation using the '
          'result\'s url. Do not assert facts that do not appear in the '
          'returned results.',
    };
  }

  // ── Query variant builder ────────────────────────────────────────

  static List<_QueryVariant> _buildVariants(String query) {
    // Extract the longest word (> 4 chars) as the "key term" for exact-phrase
    // wrapping.  Falls back to the whole query if no such word exists.
    final List<String> words = query
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 4)
        .toList();
    final String keyTerm = words.isNotEmpty ? words.first : query;

    // Build query without the key term for variant 2.
    final String withoutKey = words.isNotEmpty
        ? query.replaceFirst(keyTerm, '').trim()
        : '';

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

  // ── Google Custom Search API ─────────────────────────────────────

  static Future<List<_SearchResult>> _fetchResults(
    String query,
    String apiKey,
    String cx,
  ) async {
    try {
      final Uri uri = Uri.https(
        _apiHost,
        _apiPath,
        <String, String>{
          'key': apiKey,
          'cx': cx,
          'q': query,
          'num': '$_resultsPerVariant',
        },
      );

      final HttpClient client = HttpClient()
        ..connectionTimeout = _timeout;

      final HttpClientRequest request = await client
          .getUrl(uri)
          .timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final HttpClientResponse response =
          await request.close().timeout(_timeout);
      final String body =
          await response.transform(utf8.decoder).join().timeout(_timeout);
      client.close();

      if (response.statusCode != 200) return <_SearchResult>[];

      final Object? decoded = jsonDecode(body);
      if (decoded is! Map<String, Object?>) return <_SearchResult>[];

      final List<Object?> items =
          (decoded['items'] as List<Object?>?) ?? <Object?>[];

      return items.whereType<Map<String, Object?>>().map((m) {
        return _SearchResult(
          title: (m['title'] as String?) ?? '',
          url: (m['link'] as String?) ?? '',
          snippet: (m['snippet'] as String?) ?? '',
          displayLink: (m['displayLink'] as String?) ?? '',
        );
      }).toList();
    } catch (_) {
      // Individual variant failures are tolerated; the remaining variants
      // still contribute to the merged result set.
      return <_SearchResult>[];
    }
  }

  // ── Result merging, scoring, and ranking ─────────────────────────

  static List<_ScoredResult> _rankResults(
    List<List<_SearchResult>> resultSets,
    List<_QueryVariant> variants,
  ) {
    // Merge all results keyed by URL; track cross-variant hit count.
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

    // Score every unique result.
    final List<_ScoredResult> all = byUrl.values.toList();
    for (final _ScoredResult s in all) {
      s.factualityScore = _computeScore(s);
    }

    // Sort descending and return the top N.
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

    // ── Cross-validation bonus ─────────────────────────────────────
    // Each additional variant that independently surfaced this URL adds
    // confidence that the source is widely indexed and relevant.
    score += s.crossHits * 3.0;

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

  // ── Helper ───────────────────────────────────────────────────────

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
  });

  final String title;
  final String url;
  final String snippet;
  final String displayLink;
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

  /// Number of additional search variants (beyond the first) that also
  /// returned this URL.  A higher value signals cross-validated relevance.
  int crossHits = 0;

  double factualityScore = 0.0;

  Map<String, Object?> toJson() => <String, Object?>{
        'title': result.title,
        'url': result.url,
        'snippet': result.snippet,
        'source_domain': result.displayLink,
        'factuality_score': double.parse(
          factualityScore.toStringAsFixed(1),
        ),
        'cross_validated': crossHits > 0,
        'cross_validation_hits': crossHits,
        'first_found_in_variant': sourceVariantLabel,
      };
}
