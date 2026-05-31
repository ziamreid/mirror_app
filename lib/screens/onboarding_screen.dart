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
  final double initialOrbX;
  final double initialOrbY;
  const OnboardingScreen({
    super.key,
    required this.language,
    this.initialOrbX = 0.5,
    this.initialOrbY = 0.5,
  });

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

  // Skip swipe state
  late AnimationController _skipSnapCtrl;
  double _dragAccum     = 0.0;
  bool   _hapticFired   = false;
  bool   _skipDone      = false; // true only after we actually commit to skip
  static const double _swipeThreshold = 120.0;
  static const double _skipBtnWidth   = 80.0;
  static const double _skipGap        = 12.0; // gap between skip btn and card

  // Physical screen size — immune to keyboard resize
  Size _screenSize = Size.zero;

  @override
  void initState() {
    super.initState();

    _cardCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeOut = CurvedAnimation(parent: _cardCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn));
    _blurOut = Tween<double>(begin: 0, end: 12).animate(CurvedAnimation(
        parent: _cardCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn)));
    _fadeIn = CurvedAnimation(parent: _cardCtrl,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut));
    _blurIn = Tween<double>(begin: 12, end: 0).animate(CurvedAnimation(
        parent: _cardCtrl,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut)));

    _introCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))..forward();
    _introBlur = Tween<double>(begin: 18, end: 0)
        .animate(CurvedAnimation(parent: _introCtrl, curve: Curves.easeOut));
    _introOpacity =
        CurvedAnimation(parent: _introCtrl, curve: Curves.easeOut);

    _skipSnapCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));

    // Seed orb to match where it was on the previous screen so it doesn't jump
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fluidCtrl.engine?.seedOrb(widget.initialOrbX, widget.initialOrbY);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final view = View.of(context);
    final dpr  = view.devicePixelRatio;
    _screenSize = Size(
      view.physicalSize.width  / dpr,
      view.physicalSize.height / dpr,
    );
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _introCtrl.dispose();
    _skipSnapCtrl.dispose();
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

  String get _skipLabel {
    switch (widget.language) {
      case AppLanguage.franko:  return 'Skip';
      case AppLanguage.arabic:  return 'تخطى';
      case AppLanguage.english: return 'Skip';
    }
  }

  void _onAnswer(AnswerChoice choice) {
    if (_transitioning) return;
    _answers[onboardingQuestions[_currentQ].id] = {
      'choice': choice.text,
      'tags':   choice.tags.map((t) => t.name).toList(),
    };
    _fluidCtrl.setSpeed(choice.fluidSpeed);
    _fluidCtrl.setMood(choice.fluidMood);
    _resetSkip();
    _advanceQuestion();
  }

  void _onSkip() {
    if (_transitioning) return;
    _answers[onboardingQuestions[_currentQ].id] = {
      'choice': '__skipped__',
      'tags':   ['skipped'],
    };
    _resetSkip();
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

  void _resetSkip() {
    _skipDone    = false;
    _hapticFired = false;
    _dragAccum   = 0;
    _skipSnapCtrl.value = 0.0;
  }

  // ── Skip drag logic ──────────────────────────────────────────────────────────
  // Key fix: we track whether the finger is currently moving RIGHT (positive dx)
  // when haptic fires. We only commit to skip on drag-END if _skipDone is true,
  // which is set only when finger is still moving right at release.
  // Swiping back left after haptic clears _hapticFired and snaps back.

  void _onCardDragUpdate(DragUpdateDetails d) {
    if (_transitioning || _skipDone) return;

    final newAccum = (_dragAccum + d.delta.dx)
        .clamp(0.0, _skipBtnWidth + _skipGap + 60.0);
    setState(() => _dragAccum = newAccum);
    _skipSnapCtrl.value =
        (newAccum / (_skipBtnWidth + _skipGap)).clamp(0.0, 1.0);

    // Fire haptic when crossing threshold going RIGHT
    if (newAccum >= _swipeThreshold && !_hapticFired && d.delta.dx > 0) {
      _hapticFired = true;
      HapticFeedback.mediumImpact();
    }

    // If user swipes BACK left after haptic — reset haptic so snap-back works
    if (_hapticFired && d.delta.dx < -8) {
      _hapticFired = false;
    }
  }

  void _onCardDragEnd(DragEndDetails d) {
    if (_skipDone) return;

    final vel = d.velocity.pixelsPerSecond.dx;
    // Only skip if haptic fired AND velocity is rightward (not returning left)
    if (_hapticFired && vel > 0) {
      _skipDone = true;
      _skipSnapCtrl
          .animateTo(1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut)
          .then((_) => Future.delayed(
              const Duration(milliseconds: 60), _onSkip));
    } else {
      // Snap back cleanly
      _hapticFired = false;
      _skipSnapCtrl.animateTo(0.0,
          duration: const Duration(milliseconds: 320), curve: Curves.elasticOut);
      setState(() => _dragAccum = 0);
    }
  }

  void _onCardDragCancel() {
    _hapticFired = false;
    _skipSnapCtrl.animateTo(0.0,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    setState(() => _dragAccum = 0);
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
      setState(() { _currentQ++; _showNext = true; });
      _cardCtrl.reset();
      _transitioning = false;
      Future.delayed(const Duration(milliseconds: 300), () {
        _fluidCtrl.setSpeed(1.0);
        _fluidCtrl.setMood(0.0);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: FluidBackground(
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
            maintainBottomViewPadding: true,
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
            ? onboardingQuestions[_currentQ] : q;

        Widget card = AnimatedBuilder(
          animation: _skipSnapCtrl,
          builder: (_, __) {
            final t      = _skipSnapCtrl.value;
            // Card moves right by (skipBtnWidth + gap) at t=1
            final offset = t * (_skipBtnWidth + _skipGap);

            final Offset orbOffset = _fluidCtrl.engine != null
                ? Offset(_fluidCtrl.engine!.orbX, _fluidCtrl.engine!.orbY)
                : const Offset(0.5, 0.5);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Skip button: fully hidden at t=0, slides into view as t grows
                // left edge of button stays _skipGap away from card at t=1
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

                // Card slides right, leaving gap after skip button
                Transform.translate(
                  offset: Offset(offset, 0),
                  child: GestureDetector(
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
                        screenSize:   _screenSize,
                        onAnswer:     _onAnswer,
                        onWriteOwn:   _onWriteOwn,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );

        // Clip expands left so skip panel isn't cut off
        card = ClipRect(
          clipper: _SkipRevealClipper(
              skipCtrl: _skipSnapCtrl,
              maxExpand: _skipBtnWidth + _skipGap),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: card,
          ),
        );

        if (blur > 0.5) {
          card = ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: card,
          );
        }
        return Opacity(opacity: opacity, child: card);
      },
    );
  }
}

// ─── Clip: expands left during swipe so skip panel isn't clipped ──────────────
class _SkipRevealClipper extends CustomClipper<Rect> {
  final Animation<double> skipCtrl;
  final double            maxExpand;
  _SkipRevealClipper({required this.skipCtrl, required this.maxExpand})
      : super(reclip: skipCtrl);

  @override
  Rect getClip(Size size) {
    final expand = skipCtrl.value * maxExpand;
    return Rect.fromLTWH(-expand, 0, size.width + expand, size.height);
  }

  @override
  bool shouldReclip(_SkipRevealClipper old) => true;
}

// ─── Skip panel ───────────────────────────────────────────────────────────────
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
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.85), size: 16),
              const SizedBox(height: 5),
              Text(label,
                  style: const TextStyle(
                    color:         Colors.white,
                    fontSize:      12,
                    fontWeight:    FontWeight.w500,
                    letterSpacing: 0.5,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Question card ────────────────────────────────────────────────────────────
class _QuestionCard extends StatefulWidget {
  final OnboardingQuestion            question;
  final String                        questionText;
  final String Function(AnswerChoice) choiceText;
  final AppLanguage                   language;
  final FluidController               fluidCtrl;
  final Size                          screenSize;
  final void Function(AnswerChoice)   onAnswer;
  final void Function(String)         onWriteOwn;

  const _QuestionCard({
    required this.question,
    required this.questionText,
    required this.choiceText,
    required this.language,
    required this.fluidCtrl,
    required this.screenSize,
    required this.onAnswer,
    required this.onWriteOwn,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  List<AnswerChoice> _choices      = [];
  bool               _showWriteOwn = false;
  final _textCtrl = TextEditingController();

  // Per-choice swipe state
  int    _swipingChoice  = -1;
  double _choiceDrag     = 0.0;
  bool   _changeHapticFired = false;
  static const double _changeThreshold = 80.0;
  static const double _changeBtnWidth  = 72.0;
  static const double _changeGap       = 10.0; // gap between choice card and change btn

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
    final sz  = box.size;
    final pos = box.localToGlobal(Offset.zero);
    final sw  = widget.screenSize.width;
    final sh  = widget.screenSize.height;
    final orbSx = engine.orbX * sw;
    final orbSy = engine.orbY * sh;
    final lx    = orbSx - pos.dx;
    final ly    = orbSy - pos.dy;
    final dist  = sqrt(
        (lx - sz.width / 2) * (lx - sz.width / 2) +
        (ly - sz.height / 2) * (ly - sz.height / 2));
    final prox   = (1.0 - dist / (sz.width * 1.1)).clamp(0.0, 1.0);
    final newOrb = Offset(lx / sz.width, ly / sz.height);
    if ((prox - _proximity).abs() > 0.01 ||
        (newOrb - _localOrb).distance > 0.01) {
      setState(() { _proximity = prox; _localOrb = newOrb; });
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

  String get _changeLabel {
    switch (widget.language) {
      case AppLanguage.franko:  return 'Change';
      case AppLanguage.arabic:  return 'غيّر';
      case AppLanguage.english: return 'Change';
    }
  }

  TextDirection get _textDir => widget.language == AppLanguage.arabic
      ? TextDirection.rtl : TextDirection.ltr;

  void _resetChoiceSwipe() {
    setState(() {
      _swipingChoice     = -1;
      _choiceDrag        = 0.0;
      _changeHapticFired = false;
    });
  }

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
    final isSwiping = _swipingChoice == index;
    final drag      = isSwiping ? _choiceDrag : 0.0;
    // drag is NEGATIVE (left swipe), revealT 0→1
    final revealT   = ((-drag) / (_changeBtnWidth + _changeGap)).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRect(
        clipper: _ChangeRevealClipper(
            revealT: revealT, btnWidth: _changeBtnWidth + _changeGap),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Change button on the RIGHT, slides in from right edge
            Positioned(
              right:  -_changeBtnWidth + (revealT * _changeBtnWidth),
              top:    0,
              bottom: 0,
              width:  _changeBtnWidth,
              child: _ChangeAnswerPanel(
                label:     _changeLabel,
                progress:  revealT,
                orbOffset: _localOrb,
                proximity: _proximity,
                onTap:     _resetChoiceSwipe,
              ),
            ),

            // Choice card slides left, leaving gap before change button
            Transform.translate(
              offset: Offset(drag, 0),
              child: GestureDetector(
                onTap: () {
                  if (isSwiping && _choiceDrag < -8) {
                    _resetChoiceSwipe();
                    return;
                  }
                  widget.onAnswer(choice);
                },
                onHorizontalDragStart: (d) {
                  // Only start if moving leftward
                  if (d.globalPosition.dx >= 0) {
                    setState(() {
                      _swipingChoice     = index;
                      _choiceDrag        = 0.0;
                      _changeHapticFired = false;
                    });
                  }
                },
                onHorizontalDragUpdate: (d) {
                  if (_swipingChoice != index) return;
                  final newDrag = (_choiceDrag + d.delta.dx)
                      .clamp(-(_changeBtnWidth + _changeGap + 20.0), 0.0);
                  setState(() => _choiceDrag = newDrag);

                  // Fire haptic when crossing threshold going LEFT
                  if (-newDrag >= _changeThreshold &&
                      !_changeHapticFired &&
                      d.delta.dx < 0) {
                    _changeHapticFired = true;
                    HapticFeedback.lightImpact();
                    // ── Haptic = instant change (no tap needed) ──
                    Future.microtask(() => _resetChoiceSwipe());
                  }

                  // Reset haptic if they swipe back right
                  if (_changeHapticFired && d.delta.dx > 8) {
                    _changeHapticFired = false;
                  }
                },
                onHorizontalDragEnd: (d) {
                  // If haptic already fired → change already triggered, just reset
                  if (_changeHapticFired) {
                    _resetChoiceSwipe();
                    return;
                  }
                  // Otherwise snap back
                  _resetChoiceSwipe();
                },
                onHorizontalDragCancel: _resetChoiceSwipe,
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
                              child: Text(widget.choiceText(choice),
                                  style: AppTheme.choiceStyle),
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
            ),
          ],
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  child: Text(_sendLabel,
                      style: const TextStyle(
                        color:         AppTheme.midPurple,
                        fontWeight:    FontWeight.w600,
                        letterSpacing: 0.5,
                      )),
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
              border: Border.all(color: const Color(0x1AFFFFFF), width: 0.7),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit, color: AppTheme.textHint, size: 14),
                const SizedBox(width: 10),
                Text(_writeOwnLabel,
                    style: AppTheme.labelStyle
                        .copyWith(color: AppTheme.textHint, letterSpacing: 0.8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Clipper for choice swipe reveal (right side) ────────────────────────────
class _ChangeRevealClipper extends CustomClipper<Rect> {
  final double revealT;
  final double btnWidth;
  const _ChangeRevealClipper({required this.revealT, required this.btnWidth});

  @override
  Rect getClip(Size size) {
    final expand = revealT * btnWidth;
    return Rect.fromLTWH(0, 0, size.width + expand, size.height);
  }

  @override
  bool shouldReclip(_ChangeRevealClipper old) => old.revealT != revealT;
}

// ─── Change answer panel ──────────────────────────────────────────────────────
class _ChangeAnswerPanel extends StatelessWidget {
  final String       label;
  final double       progress;
  final Offset       orbOffset;
  final double       proximity;
  final VoidCallback onTap;

  const _ChangeAnswerPanel({
    required this.label,
    required this.progress,
    required this.orbOffset,
    required this.proximity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlassCard(
        selected:     false,
        orbOffset:    orbOffset,
        proximity:    proximity,
        cornerRadius: 16,
        height:       double.infinity,
        child: Center(
          child: Opacity(
            opacity: ((progress - 0.2) / 0.8).clamp(0.0, 1.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded,
                    color: Colors.white.withOpacity(0.85), size: 16),
                const SizedBox(height: 4),
                Text(label,
                    style: const TextStyle(
                      color:         Colors.white,
                      fontSize:      11,
                      fontWeight:    FontWeight.w500,
                      letterSpacing: 0.4,
                    )),
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
  const _CardBorderPainter({required this.proximity, required this.orbOffset});

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
      canvas.drawCircle(Offset(ox, oy), r, Paint()
        ..shader = RadialGradient(colors: [
          Color.fromARGB((proximity * 18).round().clamp(0, 255), 200, 100, 255),
          Color.fromARGB((proximity *  7).round().clamp(0, 255), 168,  85, 247),
          const Color(0x00000000),
        ], stops: const [0.0, 0.4, 1.0])
            .createShader(Rect.fromCircle(center: Offset(ox, oy), radius: r)));
      canvas.restore();
    }

    final alpha = (6 + proximity * 190).round().clamp(0, 255);
    final dimA  = (alpha * 0.09).round().clamp(0, 255);
    final dirX  = (orbOffset.dx - 0.5) * 2.0;
    final dirY  = (orbOffset.dy - 0.5) * 2.0;
    canvas.drawRRect(rrect, Paint()
      ..shader = LinearGradient(
          begin: Alignment(dirX.clamp(-1.0, 1.0), dirY.clamp(-1.0, 1.0)),
          end:   Alignment(-dirX.clamp(-1.0, 1.0), -dirY.clamp(-1.0, 1.0)),
          colors: [
            Color.fromARGB(alpha, 220, 200, 255),
            Color.fromARGB(dimA,  220, 200, 255),
          ]).createShader(rect)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = proximity > 0.1 ? 1.3 : 0.8);

    if (proximity > 0.05) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
            const Radius.circular(23)),
        Paint()
          ..color       = Color.fromARGB(
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
          width: active ? 20 : 6, height: 6,
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
        final opacity = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return AnimatedBuilder(
          animation: anim,
          builder: (_, __) => blur.value > 0.3
              ? ImageFiltered(
                  imageFilter: ImageFilter.blur(
                      sigmaX: blur.value, sigmaY: blur.value),
                  child: Opacity(opacity: opacity.value, child: child))
              : child,
        );
      },
    );