import 'app_text.dart';

/// ============================================================================
/// PHASE 2 SEAM — LOCAL DISEASE NAMES
/// ============================================================================
///
/// The backend currently stores the condition as one free-text English string
/// on `patients.condition` (for example "Type 2 Diabetes Mellitus"). That is a
/// clinical label. It is not the word an elderly patient in India uses for
/// their own illness, and it is not something we can translate reliably at
/// runtime.
///
/// So this file maps a clinical string onto the familiar, everyday name for
/// the same illness, in each language the app offers. The mapping is hardcoded
/// keyword matching. It is a stand-in, not a clinical terminology service.
///
/// WHAT PHASE 2 REPLACES
///   The backend should model the condition properly — a `condition_code`
///   column on `patients` (ICD-10, SNOMED, or an internal hospital code set),
///   plus a lookup table of patient-friendly names per language maintained by
///   the hospital. When that lands, delete `_keywordRules` below and look the
///   code up instead. `LocalDiseaseName.forCondition` keeps the same signature,
///   so no screen code has to change.
///
/// WHAT HAPPENS TO AN UNRECOGNISED CONDITION
///   It falls through and the raw clinical string is shown unchanged. That is
///   deliberate — showing the doctor's own words is safe, guessing is not.
/// ============================================================================
class LocalDiseaseName {
  const LocalDiseaseName._();

  /// Returns the familiar local name for [condition] in [language], or the
  /// original [condition] string if we have no mapping for it.
  static String forCondition(String condition, AppLanguage language) {
    final haystack = condition.toLowerCase();
    for (final rule in _keywordRules) {
      if (rule.keywords.any(haystack.contains)) {
        return rule.names[language] ?? rule.names[AppLanguage.english]!;
      }
    }
    return condition;
  }

  /// True when we actually recognised the condition. Screens use this to
  /// decide whether to also show the clinical string underneath in smaller
  /// text, so the patient's own doctor can still verify what was recorded.
  static bool isRecognised(String condition) {
    final haystack = condition.toLowerCase();
    return _keywordRules.any((rule) => rule.keywords.any(haystack.contains));
  }
}

class _DiseaseRule {
  const _DiseaseRule({required this.keywords, required this.names});
  final List<String> keywords;
  final Map<AppLanguage, String> names;
}

/// PLACEHOLDER DATA — replaced by a backend code set in Phase 2.
///
/// Covers the two conditions named in the project brief (diabetes, roughly
/// 101 million people in India; hypertension, roughly 315 million) plus the
/// handful of comorbidities a chronic-care clinic sees most often.
const List<_DiseaseRule> _keywordRules = [
  _DiseaseRule(
    keywords: ['diabet', 'dm2', 'dm 2', 'mellitus', 'blood sugar'],
    names: {
      AppLanguage.english: 'Sugar illness (diabetes)',
      AppLanguage.hindi: 'शुगर की बीमारी',
      AppLanguage.kannada: 'ಸಕ್ಕರೆ ಕಾಯಿಲೆ',
    },
  ),
  _DiseaseRule(
    keywords: ['hypertens', 'high blood pressure', 'htn', 'high bp'],
    names: {
      AppLanguage.english: 'High BP (blood pressure)',
      AppLanguage.hindi: 'हाई बी.पी. (रक्तचाप)',
      AppLanguage.kannada: 'ಅಧಿಕ ರಕ್ತದೊತ್ತಡ (ಬಿ.ಪಿ.)',
    },
  ),
  _DiseaseRule(
    keywords: ['asthma', 'copd', 'bronchial'],
    names: {
      AppLanguage.english: 'Breathing illness (asthma)',
      AppLanguage.hindi: 'साँस की बीमारी (दमा)',
      AppLanguage.kannada: 'ಉಸಿರಾಟದ ಕಾಯಿಲೆ (ಅಸ್ತಮಾ)',
    },
  ),
  _DiseaseRule(
    keywords: ['thyroid', 'hypothyroid'],
    names: {
      AppLanguage.english: 'Thyroid illness',
      AppLanguage.hindi: 'थायरॉइड की बीमारी',
      AppLanguage.kannada: 'ಥೈರಾಯ್ಡ್ ಕಾಯಿಲೆ',
    },
  ),
  _DiseaseRule(
    keywords: ['cardiac', 'heart', 'coronary', 'ihd'],
    names: {
      AppLanguage.english: 'Heart illness',
      AppLanguage.hindi: 'दिल की बीमारी',
      AppLanguage.kannada: 'ಹೃದಯ ಕಾಯಿಲೆ',
    },
  ),
  _DiseaseRule(
    keywords: ['kidney', 'renal', 'ckd'],
    names: {
      AppLanguage.english: 'Kidney illness',
      AppLanguage.hindi: 'गुर्दे की बीमारी',
      AppLanguage.kannada: 'ಮೂತ್ರಪಿಂಡ ಕಾಯಿಲೆ',
    },
  ),
];
