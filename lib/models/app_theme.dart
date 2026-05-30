import 'package:flutter/material.dart';

class AppTheme {
  // ── Core palette ──────────────────────────────────────────────────────────
  static const Color deepViolet    = Color(0xFF6d28d9);
  static const Color midPurple     = Color(0xFFa855f7);
  static const Color hotPink       = Color(0xFFe879f9);
  static const Color pureBlack     = Color(0xFF000000);
  static const Color glassWhite    = Color(0x10FFFFFF);
  static const Color glassBorder   = Color(0x28FFFFFF);
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0x99FFFFFF);
  static const Color textHint      = Color(0x55FFFFFF);

  // ── Font — SF Pro Rounded throughout ─────────────────────────────────────
  static const String _font = '.SF Pro Rounded';

  // ── Glass card ────────────────────────────────────────────────────────────
  static BoxDecoration glassCard({double radius = 20, double opacity = 0.07}) =>
      BoxDecoration(
        color: const Color.fromRGBO(10, 10, 20, 0.55),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: glassBorder, width: 0.8),
      );

  // ── Choice card ───────────────────────────────────────────────────────────
  static BoxDecoration choiceCard({bool selected = false}) => BoxDecoration(
        color: selected
            ? const Color(0x1Ea855f7)
            : const Color(0x09FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? midPurple : const Color(0x22FFFFFF),
          width: selected ? 1.2 : 0.7,
        ),
      );

  // ── Typography — all SF Pro Rounded, consistent weight system ─────────────
  // Display: w600 — matches "Choose your language" heading
  // Body:    w400 — clean readable weight for all body text
  // Label:   w500 — small caps / metadata

  static const TextStyle questionStyle = TextStyle(
    fontFamily:    _font,
    color:         textPrimary,
    fontSize:      21,
    fontWeight:    FontWeight.w600,   // unified with heading weight
    letterSpacing: -0.4,
    height:        1.45,
  );

  static const TextStyle choiceStyle = TextStyle(
    fontFamily:    _font,
    color:         textPrimary,
    fontSize:      15,
    fontWeight:    FontWeight.w400,   // clean body weight
    letterSpacing: -0.1,
    height:        1.4,
  );

  static const TextStyle labelStyle = TextStyle(
    fontFamily:    _font,
    color:         textSecondary,
    fontSize:      11,
    fontWeight:    FontWeight.w500,
    letterSpacing: 1.2,
  );

  static const TextStyle appNameStyle = TextStyle(
    fontFamily:    _font,
    color:         textPrimary,
    fontSize:      30,
    fontWeight:    FontWeight.w600,   // unified
    letterSpacing: 9,
  );

  static const TextStyle headlineStyle = TextStyle(
    fontFamily:    _font,
    color:         textPrimary,
    fontSize:      27,
    fontWeight:    FontWeight.w600,   // unified — matches "Choose your language"
    letterSpacing: -0.5,
    height:        1.3,
  );

  // ── Card label style (used inside language cards) ─────────────────────────
  static const TextStyle cardLabelStyle = TextStyle(
    fontFamily:    _font,
    color:         textPrimary,
    fontSize:      15,
    fontWeight:    FontWeight.w600,   // prominent, matches heading feel
    letterSpacing: 2.4,
  );

  static const TextStyle cardSublabelStyle = TextStyle(
    fontFamily:    _font,
    color:         textHint,
    fontSize:      10,
    fontWeight:    FontWeight.w400,
    letterSpacing: 0.6,
  );
}