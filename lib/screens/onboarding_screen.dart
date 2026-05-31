import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_theme.dart';
import '../models/onboarding_data.dart';
import '../widgets/fluid_background.dart';
import '../widgets/liquid_glass_card.dart';
import '../widgets/orb_aware_text.dart';
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
  final Map<String, dynamic> _answers = {};
  static const int _totalQ = 3;

  late AnimationController _cardCtrl;
  late Animation<double> _fadeOut;
  late Animation<double> _fadeIn;
  late Animation<double> _blurOut;
  late Animation<double> _blurIn;
  bool _transitioning = false;
  bool _showNext      = false;

  late AnimationController _introCtrl;
  late Animation<double> _introBlur;
  late Animation<double> _introOpacity;

  // Skip / swipe state
  late AnimationController _skipCtrl; // 0 = hidden, 1 = fully revealed
  double _dragAccum   = 0.0;
  bool   _hapticFired = false;
  static const double _swipeThreshold = 110.0; // px to trigger skip
  static const double _skipBtnWidth   = 88.0;  // width of the skip panel

  @override
  void initState() {
    super.initState();

    _cardCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeOut = CurvedAnimation(
        parent: _cardCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn));
    _blurOut = Tween<double>(begin: 0, end: 12).animate(CurvedAnimation(
        parent: _cardCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn)));
    _fadeIn = CurvedAnimation(
        parent: _cardCtrl,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut));
    _blurIn = Tween<double>(begin: 12, end: 0).animate(CurvedAnimation(
        parent: _cardCtrl,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut)));

    _introCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
          ..forward();
    _introBlur = Tween<double>(begin: 18, end: 0)
        .animate(CurvedAnimation(parent: _introCtrl, curve: Curves.easeOut));
    _introOpacity =
        CurvedAnimation(parent: _introCtrl, curve: Curves.easeOut);

    _skipCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _introCtrl.dispose();
    _skipCtrl.dispose();
    super.dispose();
  }

  // ── Localisation helpers ──────────────────────────────────────────────────

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

  String get _skipLabel {
    switch (widget.language) {
      case AppLanguage.franko:  return 'Skip';
      case AppLanguage.arabic:  return 'تخطى';
      case AppLanguage.english: return 'Skip';
    }
  }

  // ── Answer / skip / advance ───────────────────────────────────────────────

  void _onAnswer(AnswerChoice choice) {
    if (_transitioning) return;
    _answers[onboardingQuestions[_currentQ].id] = {
      'choice': choice.text,
      'tags':   choice.tags.map((t) => t.name).toList(),
    };
    _fluidCtrl.setSpeed(choice.fluidSpeed);
    _fluidCtrl.setMood(choice.fluidMood);
    _dismissSkip();
    _advanceQuestion();
  }

  void _onSkip() {
    if (_transitioning) return;
    _answers[onboardingQuestions[_currentQ].id] = {
      'choice': '__skipped__',
      'tags':   ['skipped'],
    };
    _dismissSkip();
    _advanceQuestion();
  }

  void _onWriteOwn(String text) {
    if (text.trim().isEmpty) return;
    _answers[onboardingQuestions[_currentQ].id] = {
      'choice': '__custom__',
      'text':   text,
      'tags':   ['custom_input'],
    };
    _advanceQuestion();
  }

  void _dismissSkip() {
    _skipCtrl.animateTo(0.0,
        duration: const Duration(milliseconds: 200), curve: Curves.easeIn);
    setState(() {
      _dragAccum   = 0;
      _hapticFired = false;
    });
  }

  // ── Swipe gesture ─────────────────────────────────────────────────────────

  void _onCardDragUpdate(DragUpdateDetails d) {
    if (_transitioning) return;

    final newAccum =
        (_dragAccum + d.delta.dx).clamp(0.0, _skipBtnWidth + 30.0);
    if (newAccum < 0) return;
    setState(() => _dragAccum = newAccum);
    _skipCtrl.value = (newAccum / _skipBtnWidth).clamp(0.0, 1.0);

    if (newAccum >= _swipeThreshold && !_hapticFired) {
      _hapticFired = true;
      HapticFeedback.mediumImpact();
    }
  }

  void _onCardDragEnd(DragEndDetails d) {
    if (_hapticFired) {
      // Threshold reached → snap open → brief pause → skip
      _skipCtrl
          .animateTo(1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut)
          .then((_) {
        Future.delayed(const Duration(milliseconds: 80), _onSkip);
      });
    } else {
      // Snap back
      _skipCtrl.animateTo(0.0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      setState(() {
        _dragAccum   = 0;
        _hapticFired = false;
      });
    }
  }

  void _onCardDragCancel() {
    _skipCtrl.animateTo(0.0,
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    setState(() {
      _dragAccum   = 0;
      _hapticFired = false;
    });
  }

  void _advanceQuestion() {
    if (_currentQ >= _totalQ - 1) {
      Navigator.of(context).pushReplacement(_blurDissolveRoute(
        ProcessingScreen(language: widget.language, answers: _answers),
      ));
      return;
    }
    _transitioning = true;
    _showNext      = false;
    _cardCtrl.forward().then((_) {
      setState(() {
        _currentQ++;
        _showNext = true;
      });
      _cardCtrl.reset();
      _transitioning = false;
      Future.delayed(const Duration(milliseconds: 300), () {
        _fluidCtrl.setSpeed(1.0);
        _fluidCtrl.setMood(0.0);
      });
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FluidBackground(
      controller: _fluidCtrl,
      child: AnimatedBuilder(
        animation: _introCtrl,
        builder: (_, child) {
          if (_introCtrl.isCompleted) return child!;
          return ImageFiltered(
            imageFilter: ImageFilter.blur(
                sigmaX: _introBlur.value, sigmaY: _introBlur.value),
            child: Opacity(opacity: _introOpacity.value, child: child),
          );
        },
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
      ),
    );
  }

  Widget _buildCard() {
    final q = onboardingQuestions[_currentQ];

    return AnimatedBuilder(
      animation: _cardCtrl,
      builder: (_, __) {
        final isOut   = _cardCtrl.value < 0.5;
        final blur    = isOut ? _blurOut.value : _blurIn.value;
        final opacity = isOut
            ? (1.0 - _fadeOut.value).clamp(0.0, 1.0)
            : _fadeIn.value.clamp(0.0, 1.0);
        final displayQ = (!isOut && _showNext && _currentQ < _totalQ)
            ? onboardingQuestions[_currentQ]
            : q;

        Widget card = AnimatedBuilder(
          animation: _skipCtrl,
          builder: (_, __) {
            final t      = _skipCtrl.value;           // 0→1 as card slides right
            final offset = t * _skipBtnWidth;         // card translation in px
            final swipeBlur = t * 8.0;                // blur grows with drag

            final Offset orbOffset = _fluidCtrl.engine != null
                ? Offset(
                    _fluidCtrl.engine!.orbX, _fluidCtrl.engine!.orbY)
                : const Offset(0.5, 0.5);

            // The card with optional drag-blur applied
            Widget cardContent = GestureDetector(
              behavior:               HitTestBehavior.translucent,
              onHorizontalDragUpdate: _onCardDragUpdate,
              onHorizontalDragEnd:    _onCardDragEnd,
              onHorizontalDragCancel: _onCardDragCancel,
              child: Listener(
                onPointerDown:   (_) => _fluidCtrl.lockOrb(),
                onPointerUp:     (_) => _fluidCtrl.unlockOrb(),
                onPointerCancel: (_) => _fluidCtrl.unlockOrb(),
                child: _QuestionCard(
                  question:     displayQ,
                  questionText: _t(displayQ),
                  choiceText:   _tc,
                  language:     widget.language,
                  fluidCtrl:    _fluidCtrl,
                  onAnswer:     _onAnswer,
                  onWriteOwn:   _onWriteOwn,
                ),
              ),
            );

            // Apply swipe blur to the card as it slides
            if (swipeBlur > 0.3) {
              cardContent = ImageFiltered(
                imageFilter:
                    ImageFilter.blur(sigmaX: swipeBlur, sigmaY: swipeBlur / 2),
                child: cardContent,
              );
            }

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Glassy skip button — fixed behind the card ───────────
                Positioned(
                  left:   -_skipBtnWidth + (t * _skipBtnWidth),
                  top:    0,
                  bottom: 0,
                  width:  _skipBtnWidth,
                  child: _SkipPanel(
                    label:     _skipLabel,
                    progress:  t,
                    orbOffset: orbOffset,
                    proximity: t,
                  ),
                ),

                // ── Card slides right ────────────────────────────────────
                Transform.translate(
                  offset: Offset(offset, 0),
                  child:  cardContent,
                ),
              ],
            );
          },
        );

        // Wrap in horizontal overflow clipper so skip panel never escapes
        card = ClipRect(
          clipper: _HorizontalRevealClipper(revealFraction: _skipCtrl),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: card,
          ),
        );

        if (blur > 0.5) {
          card = ImageFiltered(
            imageFilter:
                ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: card,
          );
        }
        return Opacity(opacity: opacity, child: card);
      },
    );
  }
}

// ─── Custom clipper — expands left edge during swipe so skip button shows ─────
class _HorizontalRevealClipper extends CustomClipper<Rect> {
  final Animation<double> revealFraction;
  _HorizontalRevealClipper({required this.revealFraction})
      : super(reclip: revealFraction);

  @override
  Rect getClip(Size size) {
    final leftExpand = revealFraction.value * 88.0;
    return Rect.fromLTWH(
        -leftExpand, 0, size.width + leftExpand, size.height);
  }

  @override
  bool shouldReclip(_HorizontalRevealClipper old) => true;
}

// ─── Skip panel — exact same LiquidGlassCard as answer choices ───────────────
class _SkipPanel extends StatelessWidget {
  final String label;
  final double progress;
  final Offset orbOffset;
  final double proximity;

  const _SkipPanel({
    required this.label,
    required this.progress,
    required this.orbOffset,
    required this.proximity,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      selected:     false,
      orbOffset:    orbOffset,
      proximity:    proximity,
      cornerRadius: 20,
      height:       double.infinity,
      child: Center(
        child: Opacity(
          opacity: ((progress - 0.25) / 0.75).clamp(0.0, 1.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.85),
                size: 18,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color:         Colors.white,
                  fontSize:      13,
                  fontWeight:    FontWeight.w500,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Question card — transparent bg, reactive border, OrbAwareText ───────────
class _QuestionCard extends StatefulWidget {
  final OnboardingQuestion          question;
  final String                      questionText;
  final String Function(AnswerChoice) choiceText;
  final AppLanguage                 language;
  final FluidController             fluidCtrl;
  final void Function(AnswerChoice) onAnswer;
  final void Function(String)       onWriteOwn;

  const _QuestionCard({
    required this.question,
    required this.questionText,
    required this.choiceText,
    required this.language,
    required this.fluidCtrl,
    required this.onAnswer,
    required this.onWriteOwn,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  List<AnswerChoice> _choices    = [];
  bool               _showWriteOwn = false;
  final _textCtrl = TextEditingController();

  final GlobalKey _cardKey = GlobalKey();
  double _proximity = 0.0;
  Offset _localOrb  = const Offset(0.5, 0.5);
  int    _frameSkip = 0;

  @override
  void initState() {
    super.initState();
    _choices = List.from(widget.question.choices);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.fluidCtrl.repaint?.addListener(_onFrame);
    });
  }

  @override
  void dispose() {
    widget.fluidCtrl.repaint?.removeListener(_onFrame);
    _textCtrl.dispose();
    super.dispose();
  }

  void _onFrame() {
    if (!mounted) return;
    _frameSkip++;
    if (_frameSkip % 3 != 0) return;
    final engine = widget.fluidCtrl.engine;
    if (engine == null) return;
    final ctx = _cardKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final sz     = box.size;
    final pos    = box.localToGlobal(Offset.zero);
    final screen = MediaQuery.of(context).size;
    final orbSx  = engine.orbX * screen.width;
    final orbSy  = engine.orbY * screen.height;
    final lx     = orbSx - pos.dx;
    final ly     = orbSy - pos.dy;
    final dist   = sqrt(
        (lx - sz.width / 2) * (lx - sz.width / 2) +
        (ly - sz.height / 2) * (ly - sz.height / 2));
    final prox   = (1.0 - dist / (sz.width * 1.1)).clamp(0.0, 1.0);
    final newOrb = Offset(lx / sz.width, ly / sz.height);
    if ((prox - _proximity).abs() > 0.01 ||
        (newOrb - _localOrb).distance > 0.01) {
      setState(() {
        _proximity = prox;
        _localOrb  = newOrb;
      });
    }
  }

  Widget _orb(Widget child, {double inner = 55, double outer = 130}) {
    final engine  = widget.fluidCtrl.engine;
    final repaint = widget.fluidCtrl.repaint;
    if (engine == null || repaint == null) return child;
    return OrbAwareText(
      engine:      engine,
      repaint:     repaint,
      innerRadius: inner,
      outerRadius: outer,
      child:       child,
    );
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
    return CustomPaint(
      foregroundPainter:
          _CardBorderPainter(proximity: _proximity, orbOffset: _localOrb),
      child: Container(
        key: _cardKey,
        decoration: const BoxDecoration(
          color:        Colors.transparent,
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize:       MainAxisSize.min,
          children: [
            _orb(
              Directionality(
                textDirection: _textDir,
                child: Text(widget.questionText, style: AppTheme.questionStyle),
              ),
              inner: 50, outer: 140,
            ),
            const SizedBox(height: 28),
            ..._choices.asMap().entries.map((e) => _buildChoice(e.key, e.value)),
            const SizedBox(height: 12),
            _buildWriteOwn(),
          ],
        ),
      ),
    );
  }

  Widget _buildChoice(int index, AnswerChoice choice) {
    return GestureDetector(
      onTap: () => widget.onAnswer(choice),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: LiquidGlassCard(
          selected:     false,
          orbOffset:    _localOrb,
          proximity:    _proximity,
          cornerRadius: 16,
          height:       56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: _orb(
                    Directionality(
                      textDirection: _textDir,
                      child: Text(
                        widget.choiceText(choice),
                        style: AppTheme.choiceStyle,
                      ),
                    ),
                    inner: 40, outer: 110,
                  ),
                ),
                _orb(
                  Icon(Icons.chevron_right,
                      color: AppTheme.textHint, size: 16),
                  inner: 40, outer: 110,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWriteOwn() {
    if (_showWriteOwn) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color:        const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x22FFFFFF), width: 0.7),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller:    _textCtrl,
                    autofocus:     true,
                    textDirection: _textDir,
                    style:         AppTheme.choiceStyle,
                    maxLines:      2,
                    decoration: InputDecoration(
                      hintText:  _writeOwnLabel,
                      hintStyle: AppTheme.choiceStyle
                          .copyWith(color: AppTheme.textHint),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onWriteOwn(_textCtrl.text),
                  child: Text(
                    _sendLabel,
                    style: const TextStyle(
                      color:       AppTheme.midPurple,
                      fontWeight:  FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _showWriteOwn = true),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color:        const Color(0x07FFFFFF),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: const Color(0x1AFFFFFF), width: 0.7),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit, color: AppTheme.textHint, size: 14),
                const SizedBox(width: 10),
                Text(
                  _writeOwnLabel,
                  style: AppTheme.labelStyle.copyWith(
                      color: AppTheme.textHint, letterSpacing: 0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Card border painter ──────────────────────────────────────────────────────
class _CardBorderPainter extends CustomPainter {
  final double proximity;
  final Offset orbOffset;
  const _CardBorderPainter(
      {required this.proximity, required this.orbOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final rect  = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(24));

    if (proximity > 0.03) {
      final ox = orbOffset.dx * size.width;
      final oy = orbOffset.dy * size.height;
      final r  = size.width * 0.55;
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawCircle(
          Offset(ox, oy),
          r,
          Paint()
            ..shader = RadialGradient(colors: [
              Color.fromARGB(
                  (proximity * 18).round().clamp(0, 255), 200, 100, 255),
              Color.fromARGB(
                  (proximity * 7).round().clamp(0, 255), 168, 85, 247),
              const Color(0x00000000),
            ], stops: const [
              0.0,
              0.4,
              1.0
            ]).createShader(
                Rect.fromCircle(center: Offset(ox, oy), radius: r)));
      canvas.restore();
    }

    final alpha = (6 + proximity * 190).round().clamp(0, 255);
    final dimA  = (alpha * 0.09).round().clamp(0, 255);
    final dirX  = (orbOffset.dx - 0.5) * 2.0;
    final dirY  = (orbOffset.dy - 0.5) * 2.0;
    canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment(
                  dirX.clamp(-1.0, 1.0), dirY.clamp(-1.0, 1.0)),
              end: Alignment(
                  -dirX.clamp(-1.0, 1.0), -dirY.clamp(-1.0, 1.0)),
              colors: [
                Color.fromARGB(alpha, 220, 200, 255),
                Color.fromARGB(dimA, 220, 200, 255),
              ]).createShader(rect)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = proximity > 0.1 ? 1.3 : 0.8);

    if (proximity > 0.05) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
            const Radius.circular(23)),
        Paint()
          ..color = Color.fromARGB(
              (proximity * 20).round().clamp(0, 255), 255, 255, 255)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    }
  }

  @override
  bool shouldRepaint(_CardBorderPainter o) =>
      o.proximity != proximity || o.orbOffset != orbOffset;
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
        final done   = i < current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve:    Curves.easeOut,
          margin:   const EdgeInsets.symmetric(horizontal: 4),
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

// ─── Blur dissolve route ──────────────────────────────────────────────────────
PageRoute _blurDissolveRoute(Widget page) => PageRouteBuilder(
      pageBuilder:               (_, __, ___) => page,
      transitionDuration:        const Duration(milliseconds: 700),
      reverseTransitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (_, anim, __, child) {
        final blur = Tween<double>(begin: 14, end: 0)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));
        final opacity =
            CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return AnimatedBuilder(
          animation: anim,
          builder: (_, __) => blur.value > 0.3
              ? ImageFiltered(
                  imageFilter: ImageFilter.blur(
                      sigmaX: blur.value, sigmaY: blur.value),
                  child:
                      Opacity(opacity: opacity.value, child: child))
              : child,
        );
      },
    );