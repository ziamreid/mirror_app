// ─── Emotional tag types (used for fluid mood + future Haiku processing) ──────
enum EmotionalTag {
  safetySecking,
  fearOfUncertainty,
  autonomyDesire,
  externalValidation,
  approvalDependence,
  intrinsicMotivation,
  fearOfRegret,
  socialPressure,
  selfDoubt,
  ambiguity,
}

// ─── A single answer choice ───────────────────────────────────────────────────
class AnswerChoice {
  final String text;          // Display text
  final String textFranko;    // Franko version
  final String textArabic;    // Arabic version
  final List<EmotionalTag> tags;
  final double fluidSpeed;    // 1.0 = normal, <1 = slow/dark, >1 = fast/bright
  final double fluidMood;     // -1 = darker, 0 = neutral, 1 = brighter

  const AnswerChoice({
    required this.text,
    required this.textFranko,
    required this.textArabic,
    required this.tags,
    this.fluidSpeed = 1.0,
    this.fluidMood = 0.0,
  });
}

// ─── A single onboarding question ────────────────────────────────────────────
class OnboardingQuestion {
  final String id;
  final String text;
  final String textFranko;
  final String textArabic;
  final List<AnswerChoice> choices; // Always exactly 3

  const OnboardingQuestion({
    required this.id,
    required this.text,
    required this.textFranko,
    required this.textArabic,
    required this.choices,
  });
}

// ─── Language enum ────────────────────────────────────────────────────────────
enum AppLanguage { english, franko, arabic }

// ─── The 3 onboarding questions ───────────────────────────────────────────────
final List<OnboardingQuestion> onboardingQuestions = [
  // Q1 — Life stage
  OnboardingQuestion(
    id: 'life_stage',
    text: 'Where are you right now in life?',
    textFranko: 'Enta fe anhi marhala delwa2ty?',
    textArabic: 'إنت في أنهي مرحلة دلوقتي؟',
    choices: [
      AnswerChoice(
        text: 'Just starting out',
        textFranko: 'Bada2 el tari2 — kol 7aga possible',
        textArabic: 'بداية الطريق — كل حاجة possible',
        tags: [EmotionalTag.autonomyDesire, EmotionalTag.fearOfUncertainty],
        fluidSpeed: 1.3,
        fluidMood: 0.3,
      ),
      AnswerChoice(
        text: 'In the middle of it all',
        textFranko: 'Fe el nos — olt el 7aga welt el 7aga',
        textArabic: 'في النص — قلت الحاجة وليت الحاجة',
        tags: [EmotionalTag.selfDoubt, EmotionalTag.ambiguity],
        fluidSpeed: 0.8,
        fluidMood: -0.2,
      ),
      AnswerChoice(
        text: 'Things are starting to clear',
        textFranko: 'Bada yetwa\'\'a\' — bas lesa fi 7aga',
        textArabic: 'بدأ يتوضح — بس لسه في حاجة',
        tags: [EmotionalTag.intrinsicMotivation, EmotionalTag.safetySecking],
        fluidSpeed: 1.1,
        fluidMood: 0.1,
      ),
    ],
  ),

  // Q2 — First thought when hesitating
  OnboardingQuestion(
    id: 'hesitation_pattern',
    text: 'Last time you hesitated on a decision — what was the first thing in your head?',
    textFranko: 'A5er mara ettereddayt fe 2arar — eih awel 7aga ra7et fe demagh ak?',
    textArabic: 'آخر مرة اتترددت في قرار — إيه أول حاجة راحت في دماغك؟',
    choices: [
      AnswerChoice(
        text: 'What someone specific would think',
        textFranko: 'Ra2y 7ad mo3ayyan',
        textArabic: 'رأي حد معين',
        tags: [EmotionalTag.externalValidation, EmotionalTag.approvalDependence],
        fluidSpeed: 0.7,
        fluidMood: -0.3,
      ),
      AnswerChoice(
        text: 'What if I get it wrong',
        textFranko: 'Eih elly momken ye7sal law ghalet',
        textArabic: 'إيه اللي ممكن يحصل لو غلطت',
        tags: [EmotionalTag.fearOfRegret, EmotionalTag.fearOfUncertainty],
        fluidSpeed: 0.6,
        fluidMood: -0.4,
      ),
      AnswerChoice(
        text: "I don't know — just felt heavy",
        textFranko: 'Mesh 3aref — bas 7eset be te2l',
        textArabic: 'مش عارف — بس حسيت بثقل',
        tags: [EmotionalTag.selfDoubt, EmotionalTag.ambiguity],
        fluidSpeed: 0.5,
        fluidMood: -0.5,
      ),
    ],
  ),

  // Q3 — Who influences you most
  OnboardingQuestion(
    id: 'pressure_source',
    text: 'Who influences your decisions the most?',
    textFranko: 'Meen bey2assar fe 2araratak aktar?',
    textArabic: 'مين بيأثر في قراراتك أكتر؟',
    choices: [
      AnswerChoice(
        text: 'My family',
        textFranko: 'Ahly',
        textArabic: 'أهلي',
        tags: [EmotionalTag.externalValidation, EmotionalTag.socialPressure],
        fluidSpeed: 0.75,
        fluidMood: -0.2,
      ),
      AnswerChoice(
        text: 'The people around me',
        textFranko: 'El mogtama3 men 7awalyya',
        textArabic: 'المجتمع من حواليا',
        tags: [EmotionalTag.approvalDependence, EmotionalTag.socialPressure],
        fluidSpeed: 0.8,
        fluidMood: -0.15,
      ),
      AnswerChoice(
        text: "Myself — I'm afraid of something",
        textFranko: 'Ana nafssy — bakhaf men 7aga',
        textArabic: 'أنا نفسي — بخاف من حاجة',
        tags: [EmotionalTag.fearOfRegret, EmotionalTag.selfDoubt],
        fluidSpeed: 0.9,
        fluidMood: 0.1,
      ),
    ],
  ),
];