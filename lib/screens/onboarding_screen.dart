import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/app_theme.dart';
import '../models/onboarding_data.dart';
import '../widgets/fluid_background.dart';
import 'processing_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final AppLanguage language;
  const OnboardingScreen({super.key, required this.language});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  int _currentQ = 0;
  final FluidController _fluidCtrl = FluidController();

  // Per-question state
  final Map<String, dynamic> _answers = {};

  // Card transition animation
  late AnimationController _cardCtrl;
  late Animation<Offset> _slideOut;
  late Animation<Offset> _slideIn;
  late Animation<double> _fadeOut;
  late Animation<double> _fadeIn;
  bool _transitioning = false;

  // Progress dots
  static const int _totalQ = 3;

  @override
  void initState() {
    super.initState();
    _cardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slideOut = Tween<Offset>(begin: Offset.zero, end: const Offset(-0.08, 0))
        .animate(CurvedAnimation(parent: _cardCtrl, curve: Curves.easeIn));
    _slideIn = Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut));
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _cardCtrl, curve: const Interval(0.0, 0.5)));
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _cardCtrl, curve: const Interval(0.5, 1.0)));
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    super.dispose();
  }

  String _t(OnboardingQuestion q) {
    switch (widget.language) {
      case AppLanguage.franko:  return q.textFranko;
      case AppLanguage.arabic:  return q.textArabic;
      case AppLanguage.english: return q.text;
    }
  }

  String _tc(AnswerChoice c) {
    switch (widget.language) {
      case AppLanguage.franko:  return c.textFranko;
      case AppLanguage.arabic:  return c.textArabic;
      case AppLanguage.english: return c.text;
    }
  }

  void _onAnswer(AnswerChoice choice) {
    if (_transitioning) return;

    // Record answer
    _answers[onboardingQuestions[_currentQ].id] = {
      'choice': choice.text,
      'tags': choice.tags.map((t) => t.name).toList(),
    };

    // Nudge fluid based on emotional tag
    _fluidCtrl.setSpeed(choice.fluidSpeed);
    _fluidCtrl.setMood(choice.fluidMood);

    _advanceQuestion();
  }

  void _onWriteOwn(String text) {
    if (text.trim().isEmpty) return;
    _answers[onboardingQuestions[_currentQ].id] = {
      'choice': '__custom__',
      'text': text,
      'tags': ['custom_input'], // Haiku will process this later
    };
    _advanceQuestion();
  }

  void _advanceQuestion() {
    if (_currentQ >= _totalQ - 1) {
      // Done — go to processing
      Navigator.of(context).pushReplacement(
        _smoothRoute(ProcessingScreen(
          language: widget.language,
          answers: _answers,
        )),
      );
      return;
    }

    _transitioning = true;
    _cardCtrl.forward().then((_) {
      setState(() => _currentQ++);
      _cardCtrl.reset();
      _transitioning = false;
      // Reset fluid to neutral between questions
      Future.delayed(const Duration(milliseconds: 300), () {
        _fluidCtrl.setSpeed(1.0);
        _fluidCtrl.setMood(0.0);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FluidBackground(
      controller: _fluidCtrl,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            _ProgressDots(current: _currentQ, total: _totalQ),
            const Spacer(),
            _buildCard(),
            const Spacer(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    final q = onboardingQuestions[_currentQ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedBuilder(
        animation: _cardCtrl,
        builder: (_, __) {
          if (_cardCtrl.value < 0.5) {
            // Sliding out
            return FadeTransition(
              opacity: _fadeOut,
              child: SlideTransition(
                position: _slideOut,
                child: _QuestionCard(
                  question: q,
                  questionText: _t(q),
                  choiceText: _tc,
                  language: widget.language,
                  onAnswer: _onAnswer,
                  onWriteOwn: _onWriteOwn,
                ),
              ),
            );
          } else {
            // Sliding in (next question)
            final nextQ = _currentQ < _totalQ - 1
                ? onboardingQuestions[_currentQ + 1]
                : q;
            return FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideIn,
                child: _QuestionCard(
                  question: nextQ,
                  questionText: _t(nextQ),
                  choiceText: _tc,
                  language: widget.language,
                  onAnswer: _onAnswer,
                  onWriteOwn: _onWriteOwn,
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

// ─── Question card with glassmorphism ────────────────────────────────────────
class _QuestionCard extends StatefulWidget {
  final OnboardingQuestion question;
  final String questionText;
  final String Function(AnswerChoice) choiceText;
  final AppLanguage language;
  final void Function(AnswerChoice) onAnswer;
  final void Function(String) onWriteOwn;

  const _QuestionCard({
    required this.question,
    required this.questionText,
    required this.choiceText,
    required this.language,
    required this.onAnswer,
    required this.onWriteOwn,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  // Swipe-to-replace state
  List<AnswerChoice> _choices = [];
  int _swipeCount = 0;
  static const int _maxSwipes = 2;

  // Write your own
  bool _showWriteOwn = false;
  final _textCtrl = TextEditingController();

  // Which choice is being swiped away
  int? _swipingIndex;
  double _swipeDx = 0;

  @override
  void initState() {
    super.initState();
    _choices = List.from(widget.question.choices);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _removeChoice(int index) {
    if (_swipeCount >= _maxSwipes) return;
    setState(() {
      _choices.removeAt(index);
      _swipeCount++;
      _swipingIndex = null;
      _swipeDx = 0;
    });
    // TODO Phase 2: generate replacement via Haiku
  }

  String get _writeOwnLabel {
    switch (widget.language) {
      case AppLanguage.franko:  return 'Ekteb be kalamak...';
      case AppLanguage.arabic:  return 'أو عبّر بكلامك...';
      case AppLanguage.english: return 'Write your own...';
    }
  }

  String get _sendLabel {
    switch (widget.language) {
      case AppLanguage.franko:  return 'yalla';
      case AppLanguage.arabic:  return 'تمام';
      case AppLanguage.english: return 'done';
    }
  }

  TextDirection get _textDir => widget.language == AppLanguage.arabic
      ? TextDirection.rtl
      : TextDirection.ltr;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: AppTheme.glassCard(radius: 24, opacity: 0.07),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Question text
              Directionality(
                textDirection: _textDir,
                child: Text(
                  widget.questionText,
                  style: AppTheme.questionStyle,
                ),
              ),
              const SizedBox(height: 28),

              // Choice list
              ..._choices.asMap().entries.map((e) => _buildChoice(e.key, e.value)),

              // "Write your own" row
              const SizedBox(height: 12),
              _buildWriteOwn(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoice(int index, AnswerChoice choice) {
    return GestureDetector(
      onTap: () => widget.onAnswer(choice),
      onHorizontalDragUpdate: _swipeCount < _maxSwipes
          ? (d) => setState(() {
                _swipingIndex = index;
                _swipeDx += d.delta.dx;
              })
          : null,
      onHorizontalDragEnd: _swipeCount < _maxSwipes
          ? (d) {
              if (_swipeDx > 60) {
                _removeChoice(index);
              } else {
                setState(() {
                  _swipingIndex = null;
                  _swipeDx = 0;
                });
              }
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        transform: Matrix4.translationValues(
          _swipingIndex == index ? _swipeDx.clamp(0, 80) : 0,
          0, 0,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: AppTheme.choiceCard(),
          child: Row(
            children: [
              Expanded(
                child: Directionality(
                  textDirection: _textDir,
                  child: Text(
                    widget.choiceText(choice),
                    style: AppTheme.choiceStyle,
                  ),
                ),
              ),
              if (_swipeCount < _maxSwipes)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.chevron_right,
                    color: AppTheme.textHint,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWriteOwn() {
    if (_showWriteOwn) {
      return Container(
        decoration: AppTheme.choiceCard(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textCtrl,
                autofocus: true,
                textDirection: _textDir,
                style: AppTheme.choiceStyle,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: _writeOwnLabel,
                  hintStyle: AppTheme.choiceStyle.copyWith(
                    color: AppTheme.textHint,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            TextButton(
              onPressed: () => widget.onWriteOwn(_textCtrl.text),
              child: Text(
                _sendLabel,
                style: const TextStyle(
                  color: AppTheme.midPurple,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _showWriteOwn = true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0x22FFFFFF),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.edit, color: AppTheme.textHint, size: 14),
            const SizedBox(width: 10),
            Text(
              _writeOwnLabel,
              style: AppTheme.labelStyle.copyWith(
                color: AppTheme.textHint,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Progress dots ────────────────────────────────────────────────────────────
class _ProgressDots extends StatelessWidget {
  final int current;
  final int total;
  const _ProgressDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        final done = i < current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? AppTheme.midPurple
                : done
                    ? AppTheme.midPurple.withOpacity(0.4)
                    : AppTheme.textHint,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ─── Smooth fade route ────────────────────────────────────────────────────────
PageRoute _smoothRoute(Widget page) => PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 600),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
    );