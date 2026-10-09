import 'package:flutter/widgets.dart';

enum SaathiThemeMode {
  system,
  light,
  dark;

  static SaathiThemeMode fromName(String? name) =>
      SaathiThemeMode.values.firstWhere(
        (mode) => mode.name == name,
        orElse: () => SaathiThemeMode.system,
      );
}

/// Patient-adjustable display and voice settings.
///
/// These live outside [AppController] so that [ReminderService] can read the
/// voice speed without importing the controller (which imports the service in
/// turn). They are plain value types with no dependencies.

/// How large the app draws its own text, on top of whatever the phone's system
/// font setting already says.
///
/// This exists because the system font setting is buried several screens deep
/// in Android's settings and most of the patients this app is for will never
/// find it — but they will find one clearly labelled control on a screen they
/// were shown once. The two multiply rather than override each other, so a
/// patient who *has* set a large system font is not silently reset to normal.
enum PatientTextSize {
  normal(factor: 1.0),
  large(factor: 1.25),
  largest(factor: 1.5);

  const PatientTextSize({required this.factor});

  /// Multiplier applied on top of the platform's own text scaler.
  final double factor;

  static PatientTextSize fromName(String? name) =>
      PatientTextSize.values.firstWhere(
        (size) => size.name == name,
        orElse: () => PatientTextSize.normal,
      );
}

/// How fast the app speaks.
///
/// Every rate here is below the TTS engine's default of 0.5. The fastest
/// option is the speed the app used before this setting existed, which review
/// already found slow enough for an elderly ear; "normal" and "slow" step down
/// from there rather than up.
enum VoiceSpeed {
  slow(rate: 0.30),
  normal(rate: 0.42),
  fast(rate: 0.55);

  const VoiceSpeed({required this.rate});

  /// Passed straight to `FlutterTts.setSpeechRate`.
  final double rate;

  static VoiceSpeed fromName(String? name) => VoiceSpeed.values.firstWhere(
    (speed) => speed.name == name,
    orElse: () => VoiceSpeed.normal,
  );
}

/// Multiplies the platform's text scaler by the patient's own setting.
///
/// Deliberately wraps [base] rather than replacing it with a flat
/// `TextScaler.linear`: Android 14 and later scale text non-linearly, growing
/// small text more than large text so headings do not run away. Replacing the
/// platform scaler would throw that curve away.
@immutable
class AppTextScaler extends TextScaler {
  const AppTextScaler(this.base, this.factor);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  // Deprecated upstream in favour of [scale], but still abstract on
  // TextScaler, so a subclass has to provide it. Kept in step with [scale] so
  // any widget still reading the old flat factor gets a consistent answer.
  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * factor;

  // MediaQuery compares its data for equality to decide whether dependents
  // need rebuilding. Without these, every rebuild would produce an unequal
  // scaler and relayout the entire app.
  @override
  bool operator ==(Object other) =>
      other is AppTextScaler && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
