// lib/screens/home_screen.dart
// Main screen of Tiebreaker AI - handles input and orchestrates the analysis flow

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tiebreaker_ai/services/gemini_service.dart';
import 'package:tiebreaker_ai/theme/app_theme.dart';
import 'package:tiebreaker_ai/widgets/analysis_result_card.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const HomeScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiService _geminiService = GeminiService();
  final FocusNode _focusNode = FocusNode();

  // State
  bool _isLoading = false;
  DecisionAnalysis? _analysis;
  String? _errorMessage;
  String _lastQuestion = '';

  // Loading messages that cycle while waiting
  final List<String> _loadingMessages = [
    'Weighing your options...',
    'Consulting the AI oracle...',
    'Mapping strengths & threats...',
    'Crafting your verdict...',
    'Almost there...',
  ];
  int _loadingMessageIndex = 0;
  late AnimationController _loadingAnimController;
  late Animation<double> _loadingFade;

  @override
  void initState() {
    super.initState();
    _loadingAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _loadingFade = CurvedAnimation(
      parent: _loadingAnimController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    _loadingAnimController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Cycles through loading messages every 2 seconds
  void _startLoadingCycle() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 2));
      if (!_isLoading || !mounted) return false;
      setState(() {
        _loadingMessageIndex =
            (_loadingMessageIndex + 1) % _loadingMessages.length;
      });
      return _isLoading;
    });
  }

  /// Main function: validates input then calls Gemini API
  Future<void> _analyzeDecision() async {
    final question = _questionController.text.trim();

    // Validate input
    if (question.isEmpty) {
      setState(() => _errorMessage = 'Please enter a question to analyze.');
      return;
    }

    if (question.length < 5) {
      setState(() => _errorMessage = 'Please enter a more detailed question.');
      return;
    }

    // Unfocus keyboard
    _focusNode.unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _analysis = null;
      _lastQuestion = question;
      _loadingMessageIndex = 0;
    });

    _startLoadingCycle();

    try {
      final result = await _geminiService.analyzeDecision(question);

      if (mounted) {
        setState(() {
          _analysis = result;
          _isLoading = false;
        });

        // Scroll to results after a brief delay for animation
        await Future.delayed(const Duration(milliseconds: 200));
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  /// Resets the screen for a new question
  void _resetAnalysis() {
    setState(() {
      _analysis = null;
      _errorMessage = null;
      _questionController.clear();
    });
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Gradient background
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
              const Color(0xFF1A1A2E),
              const Color(0xFF0F0F1E),
            ]
                : [
              const Color(0xFFF3F1FF),
              const Color(0xFFFAF9FF),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              _buildAppBar(isDark),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),

                      // Hero header
                      _buildHeroHeader(isDark),
                      const SizedBox(height: 28),

                      // Input card
                      _buildInputCard(isDark),
                      const SizedBox(height: 20),

                      // Error message
                      if (_errorMessage != null) _buildErrorBanner(isDark),

                      // Loading state
                      if (_isLoading) _buildLoadingState(isDark),

                      // Results
                      if (_analysis != null) ...[
                        // "New Question" button
                        _buildNewQuestionButton(isDark),
                        const SizedBox(height: 16),
                        // Question echo
                        _buildQuestionEcho(isDark),
                        const SizedBox(height: 16),
                        // Full analysis card
                        AnalysisResultCard(
                          analysis: _analysis!,
                          question: _lastQuestion,
                        ),
                      ],

                      // Bottom padding
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // App icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, Color(0xFF9D96FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.balance_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            'BreakPoint',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          // Dark mode toggle
          GestureDetector(
            onTap: widget.onToggleTheme,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 52,
              height: 28,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.primaryColor.withOpacity(0.3)
                    : const Color(0xFFE8E6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                ),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                alignment:
                isDark ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Make better\ndecisions. ✨',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            height: 1.2,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ask anything. Get AI-powered pros, cons, comparisons & SWOT analysis.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: isDark
                ? Colors.white.withOpacity(0.5)
                : const Color(0xFF8884B0),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInputCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2D2D5E)
              : const Color(0xFFE8E6FF),
        ),
        boxShadow: isDark
            ? []
            : [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Label
          Text(
            'What\'s your decision?',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),

          // Text input
          TextField(
            controller: _questionController,
            focusNode: _focusNode,
            maxLines: 4,
            minLines: 3,
            enabled: !_isLoading,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText:
              'e.g. Should I quit my job and start a business?\n'
                  'Should I buy a new laptop?\n'
                  'Should I move to another city?',
              hintMaxLines: 4,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _analyzeDecision(),
          ),

          const SizedBox(height: 16),

          // Quick examples
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _ExampleChip(
                label: '💻 Buy a laptop?',
                onTap: () => _questionController.text =
                'Should I buy a new laptop?',
              ),
              _ExampleChip(
                label: '🏠 Move cities?',
                onTap: () => _questionController.text =
                'Should I move to a new city for a job opportunity?',
              ),
              _ExampleChip(
                label: '🎓 Go back to school?',
                onTap: () => _questionController.text =
                'Should I go back to school for a master\'s degree?',
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Analyze button
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _analyzeDecision,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLoading
                    ? AppTheme.primaryColor.withOpacity(0.5)
                    : AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isLoading) ...[
                    const Icon(Icons.auto_awesome_rounded, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    _isLoading ? 'Analyzing...' : 'Analyze Decision',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.consColor.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.consColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: AppTheme.consColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.consColor,
                fontSize: 13.5,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = null),
            child: Icon(Icons.close_rounded,
                color: AppTheme.consColor.withOpacity(0.6), size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          // Animated shimmer loader
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.accentColor,
                ],
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              _loadingMessages[_loadingMessageIndex],
              key: ValueKey(_loadingMessageIndex),
              style: GoogleFonts.plusJakartaSans(
                color: isDark
                    ? Colors.white.withOpacity(0.6)
                    : const Color(0xFF8884B0),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionEcho(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.primaryColor.withOpacity(0.08)
            : AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.help_outline_rounded,
              color: AppTheme.primaryColor.withOpacity(0.7), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _lastQuestion,
              style: GoogleFonts.plusJakartaSans(
                color: isDark
                    ? Colors.white.withOpacity(0.75)
                    : const Color(0xFF4A4A8A),
                fontSize: 13.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewQuestionButton(bool isDark) {
    return GestureDetector(
      onTap: _resetAnalysis,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF2D2D5E)
              : const Color(0xFFEEECFF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh_rounded,
                color: AppTheme.primaryColor, size: 16),
            const SizedBox(width: 6),
            Text(
              'Ask a new question',
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

/// Example question chip
class _ExampleChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ExampleChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF2D2D5E)
              : const Color(0xFFEEECFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}