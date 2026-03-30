// lib/services/gemini_service.dart
// Handles all communication with the Gemini API

import 'dart:convert';

import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Data Models
// ---------------------------------------------------------------------------

/// One row in the comparison table
class ComparisonRow {
  final String criterion;
  final String optionA;
  final String optionB;
  final String winner; // "A", "B", or "Tie"

  ComparisonRow({
    required this.criterion,
    required this.optionA,
    required this.optionB,
    required this.winner,
  });
}

/// Full comparison section with two named options
class ComparisonAnalysis {
  final String labelA;
  final String labelB;
  final List<ComparisonRow> rows;
  final String overallWinner; // "A", "B", or "Tie"

  ComparisonAnalysis({
    required this.labelA,
    required this.labelB,
    required this.rows,
    required this.overallWinner,
  });
}

/// SWOT breakdown model
class SwotAnalysis {
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> opportunities;
  final List<String> threats;

  SwotAnalysis({
    required this.strengths,
    required this.weaknesses,
    required this.opportunities,
    required this.threats,
  });
}

/// Full decision analysis returned from Gemini
class DecisionAnalysis {
  final String quickVerdict;
  final List<String> pros;
  final List<String> cons;
  final ComparisonAnalysis comparison;
  final SwotAnalysis swot;
  final String finalAdvice;
  final String rawResponse;

  DecisionAnalysis({
    required this.quickVerdict,
    required this.pros,
    required this.cons,
    required this.comparison,
    required this.swot,
    required this.finalAdvice,
    required this.rawResponse,
  });
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static const String _systemPrompt = r'''
You are a decision-making assistant. Analyze the user's question and respond using EXACTLY the format below.

## Quick Verdict
[One clear sentence verdict]

## Pros
- [Pro 1]
- [Pro 2]
- [Pro 3]
- [Pro 4]

## Cons
- [Con 1]
- [Con 2]
- [Con 3]
- [Con 4]

## Comparison
Infer two meaningful options from the question (e.g. "Do it" vs "Don't do it").

OPTION_A: [Short label for option A]
OPTION_B: [Short label for option B]

| Criterion | Option A | Option B | Winner |
|---|---|---|---|
| Cost | [value] | [value] | [A or B or Tie] |
| Time Required | [value] | [value] | [A or B or Tie] |
| Risk Level | [value] | [value] | [A or B or Tie] |
| Long-term Benefit | [value] | [value] | [A or B or Tie] |
| Ease | [value] | [value] | [A or B or Tie] |
| ROI / Value | [value] | [value] | [A or B or Tie] |
| Flexibility | [value] | [value] | [A or B or Tie] |

OVERALL_WINNER: [A or B or Tie]

## SWOT Analysis

### Strengths
- [Strength 1]
- [Strength 2]
- [Strength 3]

### Weaknesses
- [Weakness 1]
- [Weakness 2]
- [Weakness 3]

### Opportunities
- [Opportunity 1]
- [Opportunity 2]
- [Opportunity 3]

### Threats
- [Threat 1]
- [Threat 2]
- [Threat 3]

## Final Advice
[2-3 sentences of clear, actionable advice]
''';

  static const String _apiKey = '';

  Future<DecisionAnalysis> analyzeDecision(String question) async {
    final url = Uri.parse('$_baseUrl?key=$_apiKey');

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': '$_systemPrompt\n\nUser question: $question'}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 2000,
        'topP': 0.9,
      },
    };

    try {
      final response = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () =>
        throw Exception('Request timed out. Check your connection.'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
        if (text == null || text.isEmpty) {
          throw Exception('Empty response from Gemini API.');
        }
        return _parseResponse(text);
      } else if (response.statusCode == 403) {
        throw Exception('API key invalid or quota exceeded.');
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please wait and try again.');
      } else {
        throw Exception('API error ${response.statusCode}. Please try again.');
      }
    } on http.ClientException {
      throw Exception('Network error. Please check your internet connection.');
    }
  }

  // ---------------------------------------------------------------------------
  // Parsing helpers
  // ---------------------------------------------------------------------------

  DecisionAnalysis _parseResponse(String text) {
    String extractSection(String content, String header, [String? nextHeader]) {
      final startRe = RegExp('##\\s*${RegExp.escape(header)}', caseSensitive: false);
      final startMatch = startRe.firstMatch(content);
      if (startMatch == null) return '';
      final start = startMatch.end;
      int end = content.length;
      if (nextHeader != null) {
        final endRe = RegExp('##\\s*${RegExp.escape(nextHeader)}', caseSensitive: false);
        final endMatch = endRe.firstMatch(content.substring(start));
        if (endMatch != null) end = start + endMatch.start;
      }
      return content.substring(start, end).trim();
    }

    List<String> extractSubSection(String section, String header) {
      final re = RegExp(
        '###\\s*${RegExp.escape(header)}([^#]*)',
        caseSensitive: false,
        dotAll: true,
      );
      final match = re.firstMatch(section);
      if (match == null) return [];
      return _parseBullets(match.group(1) ?? '');
    }

    final verdictSection = extractSection(text, 'Quick Verdict', 'Pros');
    final prosSection    = extractSection(text, 'Pros', 'Cons');
    final consSection    = extractSection(text, 'Cons', 'Comparison');
    final compSection    = extractSection(text, 'Comparison', 'SWOT Analysis');
    final swotSection    = extractSection(text, 'SWOT Analysis', 'Final Advice');
    final adviceSection  = extractSection(text, 'Final Advice');

    return DecisionAnalysis(
      quickVerdict: verdictSection.replaceAll(RegExp(r'^[-*]\s*'), '').trim(),
      pros:         _parseBullets(prosSection),
      cons:         _parseBullets(consSection),
      comparison:   _parseComparison(compSection),
      swot: SwotAnalysis(
        strengths:     extractSubSection(swotSection, 'Strengths'),
        weaknesses:    extractSubSection(swotSection, 'Weaknesses'),
        opportunities: extractSubSection(swotSection, 'Opportunities'),
        threats:       extractSubSection(swotSection, 'Threats'),
      ),
      finalAdvice: adviceSection.trim(),
      rawResponse: text,
    );
  }

  ComparisonAnalysis _parseComparison(String section) {
    String labelA = 'Option A';
    String labelB = 'Option B';
    String overallWinner = 'Tie';

    final labelAMatch = RegExp(r'OPTION_A:\s*(.+)', caseSensitive: false).firstMatch(section);
    final labelBMatch = RegExp(r'OPTION_B:\s*(.+)', caseSensitive: false).firstMatch(section);
    final winnerMatch = RegExp(r'OVERALL_WINNER:\s*(\w+)', caseSensitive: false).firstMatch(section);

    if (labelAMatch != null) labelA = labelAMatch.group(1)!.trim();
    if (labelBMatch != null) labelB = labelBMatch.group(1)!.trim();
    if (winnerMatch != null) overallWinner = winnerMatch.group(1)!.trim();

    final rows = <ComparisonRow>[];
    for (final line in section.split('\n')) {
      final t = line.trim();
      if (!t.startsWith('|')) continue;
      if (t.contains('---')) continue;
      if (RegExp(r'\|\s*(Criterion|criterion)\s*\|').hasMatch(t)) continue;

      final cells = t.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
      if (cells.length >= 4) {
        rows.add(ComparisonRow(
          criterion: cells[0],
          optionA:   cells[1],
          optionB:   cells[2],
          winner:    cells[3],
        ));
      }
    }

    return ComparisonAnalysis(
      labelA: labelA,
      labelB: labelB,
      rows: rows,
      overallWinner: overallWinner,
    );
  }

  List<String> _parseBullets(String text) {
    return text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('-') || l.startsWith('*') || l.startsWith('•'))
        .map((l) => l.replaceFirst(RegExp(r'^[-*•]\s*'), '').trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }
}