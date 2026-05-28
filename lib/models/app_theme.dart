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

  // ── Glass card — stronger blur so orb softens behind it ──────────────────
  static BoxDecoration glassCard({double radius = 20, double opacity = 0.07}) =>
      BoxDecoration(
        color: Color.fromRGBO(10, 10, 20, 0.55), // dark tinted base
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

  // ── Typography — SF Pro (iOS default), fallback to system ─────────────────
  static const String _font = '.SF Pro Display';

  static const TextStyle questionStyle = TextStyle(
    fontFamily: _font,
    color: textPrimary,
    fontSize: 21,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.4,
    height: 1.45,
  );

  static const TextStyle choiceStyle = TextStyle(
    fontFamily: _font,
    color: textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.4,
  );

  static const TextStyle labelStyle = TextStyle(
    fontFamily: _font,
    color: textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.2,
  );

  static const TextStyle appNameStyle = TextStyle(
    fontFamily: _font,
    color: textPrimary,
    fontSize: 30,
    fontWeight: FontWeight.w200,
    letterSpacing: 9,
  );

  static const TextStyle headlineStyle = TextStyle(
    fontFamily: _font,
    color: textPrimary,
    fontSize: 27,
    fontWeight: FontWeight.w200,
    letterSpacing: -0.5,
    height: 1.3,
  );
}