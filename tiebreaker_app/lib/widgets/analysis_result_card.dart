// lib/widgets/analysis_result_card.dart
// Tabbed result display: Pros & Cons | Comparison | SWOT

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tiebreaker_ai/services/gemini_service.dart';
import 'package:tiebreaker_ai/theme/app_theme.dart';

class AnalysisResultCard extends StatefulWidget {
  final DecisionAnalysis analysis;
  final String question;

  const AnalysisResultCard({
    super.key,
    required this.analysis,
    required this.question,
  });

  @override
  State<AnalysisResultCard> createState() => _AnalysisResultCardState();
}

class _AnalysisResultCardState extends State<AnalysisResultCard>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Share / Copy ──────────────────────────────────────────────────────────

  String _formatForSharing() {
    final a = widget.analysis;
    final buf = StringBuffer();
    buf.writeln('🤔 TIEBREAKER AI — ${widget.question}');
    buf.writeln();
    buf.writeln('⚡ QUICK VERDICT');
    buf.writeln(a.quickVerdict);
    buf.writeln();
    buf.writeln('✅ PROS');
    for (final p in a.pros) buf.writeln('• $p');
    buf.writeln();
    buf.writeln('❌ CONS');
    for (final c in a.cons) buf.writeln('• $c');
    buf.writeln();
    buf.writeln('📊 COMPARISON — ${a.comparison.labelA} vs ${a.comparison.labelB}');
    for (final r in a.comparison.rows) {
      buf.writeln('${r.criterion}: ${r.optionA} vs ${r.optionB} → ${r.winner}');
    }
    buf.writeln('Overall winner: ${a.comparison.overallWinner}');
    buf.writeln();
    buf.writeln('🔍 SWOT');
    buf.writeln('Strengths: ${a.swot.strengths.join(", ")}');
    buf.writeln('Weaknesses: ${a.swot.weaknesses.join(", ")}');
    buf.writeln('Opportunities: ${a.swot.opportunities.join(", ")}');
    buf.writeln('Threats: ${a.swot.threats.join(", ")}');
    buf.writeln();
    buf.writeln('💡 FINAL ADVICE');
    buf.writeln(a.finalAdvice);
    return buf.toString();
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _formatForSharing()));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Copied!', style: GoogleFonts.plusJakartaSans()),
      backgroundColor: AppTheme.accentColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  void _share() => Share.share(_formatForSharing(), subject: 'Tiebreaker AI Analysis');

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Verdict hero ────────────────────────────────────────────────
          _VerdictCard(verdict: widget.analysis.quickVerdict),
          const SizedBox(height: 16),

          // ── Tab bar + panels ────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0xFF2D2D5E) : const Color(0xFFE8E6FF),
              ),
            ),
            child: Column(
              children: [
                // Tab bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: _StyledTabBar(controller: _tabCtrl),
                ),
                // Tab views — fixed height so the card doesn't collapse
                SizedBox(
                  height: _tabHeight(),
                  child: TabBarView(
                    controller: _tabCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _ProsConsTab(analysis: widget.analysis),
                      _ComparisonTab(comparison: widget.analysis.comparison),
                      _SwotTab(swot: widget.analysis.swot),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Final advice ────────────────────────────────────────────────
          _FinalAdviceCard(advice: widget.analysis.finalAdvice),
          const SizedBox(height: 12),

          // ── Actions ─────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  onTap: _copy,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: _share,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  /// Estimates a sensible fixed height for the tab view based on content
  double _tabHeight() {
    final a = widget.analysis;
    final prosConsRows = (a.pros.length > a.cons.length ? a.pros.length : a.cons.length);
    final compRows = a.comparison.rows.length;
    final swotMax = [
      a.swot.strengths.length,
      a.swot.weaknesses.length,
      a.swot.opportunities.length,
      a.swot.threats.length,
    ].reduce((v, e) => v > e ? v : e);

    final prosConsH = 80.0 + prosConsRows * 52.0;
    final compH     = 120.0 + compRows * 56.0;
    final swotH     = 80.0 + (swotMax * 2) * 48.0;

    final maxH = [prosConsH, compH, swotH].reduce((v, e) => v > e ? v : e);
    return maxH.clamp(320.0, 700.0);
  }
}

// ============================================================================
// Styled Tab Bar
// ============================================================================

class _StyledTabBar extends StatelessWidget {
  final TabController controller;
  const _StyledTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F1E) : const Color(0xFFF0EEFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryColor, Color(0xFF9D96FF)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: isDark
            ? Colors.white.withOpacity(0.45)
            : const Color(0xFF7B77B0),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'Pros & Cons'),
          Tab(text: 'Comparison'),
          Tab(text: 'SWOT'),
        ],
      ),
    );
  }
}

// ============================================================================
// Tab 1 — Pros & Cons
// ============================================================================

class _ProsConsTab extends StatelessWidget {
  final DecisionAnalysis analysis;
  const _ProsConsTab({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxLen = analysis.pros.length > analysis.cons.length
        ? analysis.pros.length
        : analysis.cons.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Column headers
          Row(
            children: [
              Expanded(child: _ColHeader('✅ Pros', AppTheme.prosColor)),
              const SizedBox(width: 10),
              Expanded(child: _ColHeader('❌ Cons', AppTheme.consColor)),
            ],
          ),
          const SizedBox(height: 10),
          // Rows
          ...List.generate(maxLen, (i) {
            final pro = i < analysis.pros.length ? analysis.pros[i] : null;
            final con = i < analysis.cons.length ? analysis.cons[i] : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _BulletCell(
                        text: pro,
                        color: AppTheme.prosColor,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BulletCell(
                        text: con,
                        color: AppTheme.consColor,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _ColHeader(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BulletCell extends StatelessWidget {
  final String? text;
  final Color color;
  final bool isDark;
  const _BulletCell({this.text, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.09 : 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: text == null
          ? const SizedBox.shrink()
          : Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                height: 1.5,
                color: isDark
                    ? Colors.white.withOpacity(0.85)
                    : const Color(0xFF2D2D5E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Tab 2 — Comparison Table
// ============================================================================

class _ComparisonTab extends StatelessWidget {
  final ComparisonAnalysis comparison;
  const _ComparisonTab({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Resolve the winner label
    String winnerLabel;
    Color winnerColor;
    if (comparison.overallWinner.toUpperCase() == 'A') {
      winnerLabel = comparison.labelA;
      winnerColor = AppTheme.prosColor;
    } else if (comparison.overallWinner.toUpperCase() == 'B') {
      winnerLabel = comparison.labelB;
      winnerColor = AppTheme.primaryColor;
    } else {
      winnerLabel = 'Tie';
      winnerColor = AppTheme.weaknessColor;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Options header row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF0EEFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Criterion',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.white.withOpacity(0.5)
                          : const Color(0xFF8884B0),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: _OptionHeaderCell(
                  label: comparison.labelA,
                  letter: 'A',
                  color: AppTheme.prosColor,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: _OptionHeaderCell(
                  label: comparison.labelB,
                  letter: 'B',
                  color: AppTheme.primaryColor,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              const SizedBox(width: 28), // winner icon column
            ],
          ),
          const SizedBox(height: 10),

          // Data rows
          ...comparison.rows.asMap().entries.map((e) {
            final i = e.key;
            final row = e.value;
            return _ComparisonRow(
              row: row,
              labelA: comparison.labelA,
              labelB: comparison.labelB,
              isEven: i.isEven,
              isDark: isDark,
            );
          }),

          const SizedBox(height: 14),

          // Overall winner banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [winnerColor, winnerColor.withOpacity(0.6)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: winnerColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Overall Winner: $winnerLabel',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionHeaderCell extends StatelessWidget {
  final String label;
  final String letter;
  final Color color;
  final bool isDark;
  const _OptionHeaderCell({
    required this.label,
    required this.letter,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final ComparisonRow row;
  final String labelA;
  final String labelB;
  final bool isEven;
  final bool isDark;

  const _ComparisonRow({
    required this.row,
    required this.labelA,
    required this.labelB,
    required this.isEven,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final winnerIsA = row.winner.toUpperCase() == 'A';
    final winnerIsB = row.winner.toUpperCase() == 'B';
    final isTie     = !winnerIsA && !winnerIsB;

    final rowBg = isEven
        ? (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02))
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          color: rowBg,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Criterion
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  row.criterion,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white.withOpacity(0.75)
                        : const Color(0xFF3D3D6E),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Option A value
            Expanded(
              flex: 3,
              child: _ValueCell(
                text: row.optionA,
                highlighted: winnerIsA,
                highlightColor: AppTheme.prosColor,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 6),
            // Option B value
            Expanded(
              flex: 3,
              child: _ValueCell(
                text: row.optionB,
                highlighted: winnerIsB,
                highlightColor: AppTheme.primaryColor,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 6),
            // Winner icon
            SizedBox(
              width: 28,
              child: Center(
                child: isTie
                    ? Icon(Icons.handshake_rounded,
                    size: 16,
                    color: isDark
                        ? Colors.white.withOpacity(0.3)
                        : Colors.grey.shade400)
                    : Icon(
                  Icons.arrow_circle_right_rounded,
                  size: 16,
                  color: winnerIsA
                      ? AppTheme.prosColor
                      : AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  final String text;
  final bool highlighted;
  final Color highlightColor;
  final bool isDark;

  const _ValueCell({
    required this.text,
    required this.highlighted,
    required this.highlightColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: highlighted
          ? BoxDecoration(
        color: highlightColor.withOpacity(isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: highlightColor.withOpacity(0.4)),
      )
          : null,
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          height: 1.4,
          fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
          color: highlighted
              ? highlightColor
              : (isDark
              ? Colors.white.withOpacity(0.65)
              : const Color(0xFF5A5A8A)),
        ),
      ),
    );
  }
}

// ============================================================================
// Tab 3 — SWOT
// ============================================================================

class _SwotTab extends StatelessWidget {
  final SwotAnalysis swot;
  const _SwotTab({required this.swot});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _SwotCell(
                      label: 'Strengths',
                      emoji: '💪',
                      items: swot.strengths,
                      color: AppTheme.strengthColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _SwotCell(
                      label: 'Opportunities',
                      emoji: '🚀',
                      items: swot.opportunities,
                      color: AppTheme.opportunityColor,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    _SwotCell(
                      label: 'Weaknesses',
                      emoji: '⚠️',
                      items: swot.weaknesses,
                      color: AppTheme.weaknessColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _SwotCell(
                      label: 'Threats',
                      emoji: '🛡️',
                      items: swot.threats,
                      color: AppTheme.threatColor,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwotCell extends StatelessWidget {
  final String label;
  final String emoji;
  final List<String> items;
  final Color color;
  final bool isDark;

  const _SwotCell({
    required this.label,
    required this.emoji,
    required this.items,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.1 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Items as table rows
          ...items.asMap().entries.map((e) {
            final isLast = e.key == items.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.value,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            height: 1.45,
                            color: isDark
                                ? Colors.white.withOpacity(0.82)
                                : const Color(0xFF3D3D6E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    color: color.withOpacity(0.15),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ============================================================================
// Shared small widgets
// ============================================================================

class _VerdictCard extends StatelessWidget {
  final String verdict;
  const _VerdictCard({required this.verdict});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, Color(0xFF9D96FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              'QUICK VERDICT',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            verdict.isEmpty ? 'See the analysis below.' : verdict,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalAdviceCard extends StatelessWidget {
  final String advice;
  const _FinalAdviceCard({required this.advice});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.accentColor.withOpacity(0.1)
            : AppTheme.accentColor.withOpacity(0.06),
        border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.lightbulb_rounded, color: AppTheme.accentColor, size: 16),
            const SizedBox(width: 6),
            Text(
              'FINAL ADVICE',
              style: GoogleFonts.spaceGrotesk(
                color: AppTheme.accentColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            advice.isEmpty
                ? 'Consider all factors carefully before making your decision.'
                : advice,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              height: 1.6,
              color: isDark
                  ? Colors.white.withOpacity(0.9)
                  : const Color(0xFF2D2D5E),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D2D5E) : const Color(0xFFEEECFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: AppTheme.primaryColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}