import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';

/// Patient-facing translations for the Saathi patient app.
///
/// This is a hand-written localisation table rather than generated `.arb`
/// output. It is deliberate: the patient app has a small, stable string set,
/// and keeping the translations readable in one file means a clinician or a
/// native speaker can review them without running any build step.
///
/// ⚠️ NEEDS NATIVE REVIEW — EVERY HINDI AND KANNADA STRING IN THIS FILE
///
/// All non-English strings below are AI-generated drafts. Not one of them has
/// been checked by a native speaker. They must be reviewed before this app is
/// given to a real patient, and the medicine and emergency wording must be
/// reviewed by a clinician as well: a mistranslated dose instruction or
/// emergency prompt is a safety issue, not a copy issue.
///
/// Review order, highest risk first:
///   1. reminder* and emergency* keys  (dosage / calling for help)
///   2. prescription and appointment keys
///   3. everything else
enum AppLanguage {
  english(code: 'en', nativeLabel: 'English', englishLabel: 'English'),
  hindi(code: 'hi', nativeLabel: 'हिन्दी', englishLabel: 'Hindi'),
  kannada(code: 'kn', nativeLabel: 'ಕನ್ನಡ', englishLabel: 'Kannada');

  const AppLanguage({
    required this.code,
    required this.nativeLabel,
    required this.englishLabel,
  });

  /// ISO 639-1 code, also what gets persisted to secure storage.
  final String code;

  /// The language's name written in its own script. This is what the patient
  /// sees in the language picker — someone who cannot read English still
  /// recognises "हिन्दी".
  final String nativeLabel;

  /// The language's name in English, shown underneath the native label so
  /// hospital staff helping a patient can find the right row.
  final String englishLabel;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) => AppLanguage.values.firstWhere(
    (language) => language.code == code,
    orElse: () => AppLanguage.english,
  );
}

/// Every translatable string in the patient app.
///
/// Using an enum instead of raw string keys means a typo is a compile error
/// rather than a blank label on a screen an elderly patient is relying on.
enum T {
  appName,
  // Welcome / one-time hospital login
  welcomeHeading,
  welcomeBody,
  welcomeLinkedCaption,
  askStaffToActivate,
  nextStepScanner,
  // Scan screen
  scanTitle,
  scanInstruction,
  scanTorchOn,
  scanTorchOff,
  scanCameraUnavailable,
  scanCameraUnavailableBody,
  scanUseIdInstead,
  scanLinking,
  scanInvalidCode,
  // Manual ID entry screen
  manualTitle,
  manualHeading,
  manualSubtext,
  manualFieldId,
  manualFieldIdHint,
  manualFieldCode,
  manualErrorId,
  manualErrorCode,
  manualSubmit,
  manualCodeOnce,
  manualNeedHelp,
  manualCannotConnect,
  // Home
  yourId,
  emergency,
  emergencyHint,
  nextAppointment,
  nextAppointmentHint,
  prescription,
  prescriptionHint,
  pastVisits,
  pastVisitsHint,
  deviceManaged,
  // Emergency confirmation
  emergencyConfirmTitle,
  emergencyConfirmBody,
  emergencyConfirmYes,
  emergencyConfirmNo,
  emergencyCalling,
  // Shared states
  pleaseWait,
  cannotReachHospital,
  cannotReachHospitalBody,
  tryAgain,
  goBack,
  // Language
  language,
  chooseLanguage,
  chooseLanguageHint,
  // Visit history
  visitHistoryTitle,
  visitHistoryHint,
  doctorLabel,
  medicinesLabel,
  nextVisitLabel,
  downloadReport,
  downloading,
  downloaded,
  noVisitsTitle,
  noVisitsBody,
  // Appointment
  appointmentTitle,
  appointmentNobooked,
  appointmentDaysAway,
  appointmentToday,
  appointmentTomorrow,
  appointmentActions,
  appointmentUpcoming,
  appointmentAddReminder,
  appointmentRemindMe,
  appointmentOneDayBefore,
  appointmentTwoHoursBefore,
  appointmentOneHourBefore,
  appointmentThirtyMinutesBefore,
  appointmentSaveReminder,
  appointmentReminderAdded,
  appointmentReminderUpdated,
  appointmentReminderRemoved,
  appointmentReminderPassed,
  appointmentReminderFailed,
  appointmentRequestReschedule,
  appointmentCurrent,
  appointmentPreferredDate,
  appointmentPreferredTime,
  appointmentReason,
  appointmentReasonForVisit,
  appointmentOptional,
  appointmentSendRequest,
  appointmentReschedulePending,
  appointmentRescheduleRequested,
  appointmentRescheduleAlreadyPending,
  appointmentRescheduleApproved,
  appointmentRescheduleRejected,
  appointmentRescheduleFailed,
  appointmentRescheduleSent,
  appointmentRescheduleWait,
  appointmentRescheduleUnchanged,
  appointmentOk,
  appointmentCancel,
  appointmentCancelQuestion,
  appointmentKeep,
  appointmentCancelled,
  appointmentCancelFailed,
  appointmentWillBeCancelled,
  appointmentNote,
  appointmentNoBookedBody,
  // Prescription
  prescriptionTitle,
  prescribedOn,
  morning,
  afternoon,
  night,
  afterFood,
  beforeFood,
  // Medicine reminder
  reminderTitle,
  reminderItIsTimeFor,
  reminderYourMedicineFor,
  reminderTaken,
  reminderSnooze,
  reminderHearAgain,
  reminderTakenConfirm,
  reminderPreview,
  // Patient dashboard (home screen)
  dashboardListen,
  dashboardListenScreen,
  dashboardStop,
  dashboardStopSpeaking,
  dashboardNextAppointment,
  dashboardMyPrescription,
  dashboardMyPrescriptionHint,
  dashboardReport,
  dashboardReportHint,
  dashboardMedicines,
  dashboardMedicinesHint,
  dashboardMedicineReminders,
  dashboardMedicineRemindersHint,
  dashboardAppointments,
  dashboardAppointmentsHint,
  dashboardHealthSummary,
  dashboardHealthSummaryHint,
  healthTitle,
  healthLatestCheck,
  healthRecordedOn,
  healthVitalsHeading,
  healthHeartRate,
  healthBloodPressure,
  healthOxygen,
  healthTemperature,
  healthWeight,
  healthHeight,
  healthNotRecorded,
  healthRecordedDuring,
  healthLoading,
  healthLoadError,
  healthNoVitals,
  healthNoVitalsBody,
  vitalsHistoryTitle,
  vitalsHistoryButton,
  vitalsHistoryHint,
  vitalsHistoryEmpty,
  vitalsHistoryEmptyBody,
  vitalsHistoryLoading,
  vitalsHistoryError,
  dashboardEmergencyHint,
  dashboardTodaysMedicine,
  dashboardNoMedicineToday,
  // Dashboard greetings
  greetingMorning,
  greetingAfternoon,
  greetingEvening,
  // Bottom navigation
  navHome,
  navAppointments,
  navMedicines,
  navMore,
  // More tab / not-yet-built screens
  moreTitle,
  moreGreeting,
  moreGreetingBody,
  supportTitle,
  supportHint,
  privacySecurityTitle,
  privacySecurityHint,
  comingSoonTitle,
  comingSoonBody,
  // Medicine reminders screen
  medicineTimesTitle,
  medicineTimesHint,
  // Settings
  settingsTitle,
  settingsHint,
  settingsLanguageSection,
  settingsTextSizeSection,
  settingsTextSizeHint,
  settingsTextSizeNormal,
  settingsTextSizeLarge,
  settingsTextSizeLargest,
  settingsTextSizePreview,
  settingsAppearanceSection,
  settingsThemeHint,
  settingsThemeSystem,
  settingsThemeLight,
  settingsThemeDark,
  settingsBoldText,
  settingsBoldTextHint,
  settingsHighContrast,
  settingsHighContrastHint,
  settingsVoiceSection,
  settingsVoiceHint,
  settingsVoiceSlow,
  settingsVoiceNormal,
  settingsVoiceFast,
  settingsVoiceTry,
  settingsVoiceSample,
  settingsTestReminder,
  settingsTestReminderHint,
  settingsHelpSection,
  settingsHelpStep1,
  settingsHelpStep2,
  settingsHelpStep3,
  settingsHelpStep4,
  settingsHelpListen,
  settingsHospitalSection,
  settingsHospitalReception,
  settingsHospitalCallNote,
  settingsYourDetailsSection,
  settingsAboutSection,
  settingsVersion,
  settingsPrivacyBody,
}

@immutable
class AppText {
  const AppText(this.language);

  final AppLanguage language;

  static AppText of(BuildContext context) =>
      Localizations.of<AppText>(context, AppText) ??
      const AppText(AppLanguage.english);

  static const LocalizationsDelegate<AppText> delegate = _AppTextDelegate();

  static List<Locale> get supportedLocales =>
      AppLanguage.values.map((language) => language.locale).toList();

  /// Looks up [key], falling back to English if a translation is missing.
  ///
  /// Falling back is intentional: showing the English word is recoverable,
  /// showing an empty label on a medicine screen is not.
  String call(T key) => _tables[language]?[key] ?? _english[key]!;

  /// Debug-only completeness check, run once at app start.
  static void debugAssertComplete() {
    assert(() {
      for (final language in AppLanguage.values) {
        final missing = T.values
            .where((key) => !(_tables[language]?.containsKey(key) ?? false))
            .toList();
        if (missing.isNotEmpty) {
          debugPrint(
            'AppText: ${language.englishLabel} is missing ${missing.length} '
            'string(s), falling back to English for: '
            '${missing.map((k) => k.name).join(', ')}',
          );
        }
      }
      return true;
    }());
  }
}

class _AppTextDelegate extends LocalizationsDelegate<AppText> {
  const _AppTextDelegate();

  @override
  bool isSupported(Locale locale) => AppLanguage.values.any(
    (language) => language.code == locale.languageCode,
  );

  @override
  Future<AppText> load(Locale locale) =>
      // SynchronousFuture, not `async`, so the translation table is ready on
      // the very first frame. An `async` function's Future only resolves on
      // the next microtask, which left the app rendering one blank frame
      // (Localizations' fallback SizedBox) every time the locale changed —
      // including at startup.
      SynchronousFuture(AppText(AppLanguage.fromCode(locale.languageCode)));

  @override
  bool shouldReload(_AppTextDelegate old) => false;
}

/// Returns the appropriate greeting key based on the current hour:
/// - 04:00 to 11:59: Morning
/// - 12:00 to 16:59: Afternoon
/// - 17:00 to 03:59: Evening
T greetingKeyForTime([DateTime? now]) {
  final current = now ?? DateTime.now();
  final hour = current.hour;
  if (hour >= 4 && hour < 12) {
    return T.greetingMorning;
  } else if (hour >= 12 && hour < 17) {
    return T.greetingAfternoon;
  } else {
    return T.greetingEvening;
  }
}

const Map<AppLanguage, Map<T, String>> _tables = {
  AppLanguage.english: _english,
  AppLanguage.hindi: _hindi,
  AppLanguage.kannada: _kannada,
};

const Map<T, String> _english = {
  T.appName: 'Saathi',
  // Wording restored to match the approved final design for this screen.
  // NOTE: this reverses the earlier plain-language pass — "login", "link",
  // "health record", "activate" and "QR code scanner" are back. See the note
  // in the handover if the low-literacy wording is wanted again.
  T.welcomeHeading: 'One-time hospital login',
  T.welcomeBody:
      'Your hospital staff will link this phone to your health record once.',
  T.welcomeLinkedCaption: 'Linked to Hospital Record',
  T.askStaffToActivate: 'Ask staff to activate',
  T.nextStepScanner: 'Next step: staff will open the QR code scanner.',
  T.scanTitle: 'Scan the code',
  T.scanInstruction: 'Point the camera at the code shown by reception.',
  T.scanTorchOn: 'Turn on light',
  T.scanTorchOff: 'Turn off light',
  T.scanCameraUnavailable: 'Camera is not working',
  T.scanCameraUnavailableBody:
      'Allow the camera, or use your ID number instead.',
  T.scanUseIdInstead: 'Use ID number instead',
  T.scanLinking: 'Please wait…',
  T.scanInvalidCode: 'This is not a hospital code. Ask reception for help.',
  T.manualTitle: 'Enter your ID',
  T.manualHeading: 'Type your ID and code',
  T.manualSubtext: 'Reception will give you these two.',
  T.manualFieldId: 'Patient ID',
  T.manualFieldIdHint: 'SAA-0000-0000',
  T.manualFieldCode: 'Activation Code',
  T.manualErrorId: 'Type the ID from reception',
  T.manualErrorCode: 'Enter the activation code',
  T.manualSubmit: 'Link this phone',
  T.manualCodeOnce: 'This code works only once.',
  T.manualNeedHelp: 'Ask reception if you do not have these.',
  T.manualCannotConnect: 'Could not reach the hospital. Please try again.',
  T.yourId: 'Your ID',
  T.emergency: 'EMERGENCY',
  T.emergencyHint: 'Call the hospital now',
  T.nextAppointment: 'NEXT APPOINTMENT',
  T.nextAppointmentHint: 'When to come again',
  T.prescription: "DOCTOR'S PRESCRIPTION",
  T.prescriptionHint: 'Your medicines',
  T.pastVisits: 'Past Visits',
  T.pastVisitsHint: 'Old reports and medicines',
  T.deviceManaged: 'This device login is handled by the hospital',
  T.emergencyConfirmTitle: 'Call the hospital for help?',
  T.emergencyConfirmBody:
      'The hospital emergency desk will be called right now.',
  T.emergencyConfirmYes: 'YES, CALL NOW',
  T.emergencyConfirmNo: 'NO, GO BACK',
  T.emergencyCalling: 'Calling the hospital…',
  T.pleaseWait: 'Please wait',
  T.cannotReachHospital: 'Cannot reach the hospital right now',
  T.cannotReachHospitalBody:
      'Please check that the internet is on, then try again. Your information '
      'is safe.',
  T.tryAgain: 'TRY AGAIN',
  T.goBack: 'GO BACK',
  T.language: 'Language',
  T.chooseLanguage: 'Choose your language',
  T.chooseLanguageHint: 'The whole app will change to this language.',
  T.visitHistoryTitle: 'Past visits',
  T.visitHistoryHint: 'Tap a visit to see the medicines given that day.',
  T.doctorLabel: 'Doctor',
  T.medicinesLabel: 'Medicines',
  T.nextVisitLabel: 'Next visit',
  T.downloadReport: 'DOWNLOAD',
  T.downloading: 'Saving…',
  T.downloaded: 'Saved to your phone',
  T.noVisitsTitle: 'No visits yet',
  T.noVisitsBody:
      'After your first visit to the doctor, your reports will appear here.',
  T.appointmentTitle: 'Next appointment',
  T.appointmentNobooked: 'No appointment booked yet',
  T.appointmentDaysAway: 'days from today',
  T.appointmentToday: 'Today',
  T.appointmentTomorrow: 'Tomorrow',
  T.appointmentActions: 'Appointment Actions',
  T.appointmentUpcoming: 'Upcoming Appointment',
  T.appointmentAddReminder: 'Add Reminder',
  T.appointmentRemindMe: 'Remind me',
  T.appointmentOneDayBefore: '1 day before',
  T.appointmentTwoHoursBefore: '2 hours before',
  T.appointmentOneHourBefore: '1 hour before',
  T.appointmentThirtyMinutesBefore: '30 minutes before',
  T.appointmentSaveReminder: 'Save Reminder',
  T.appointmentReminderAdded: 'Reminder added',
  T.appointmentReminderUpdated: 'Reminder updated',
  T.appointmentReminderRemoved: 'Reminder removed',
  T.appointmentReminderPassed:
      'This reminder time has already passed. Please choose another option.',
  T.appointmentReminderFailed:
      'The reminder could not be scheduled. Check notification permission and try again.',
  T.appointmentRequestReschedule: 'Request Reschedule',
  T.appointmentCurrent: 'Current appointment',
  T.appointmentPreferredDate: 'Preferred date',
  T.appointmentPreferredTime: 'Preferred time',
  T.appointmentReason: 'Reason',
  T.appointmentReasonForVisit: 'Reason for Visit',
  T.appointmentOptional: 'Optional',
  T.appointmentSendRequest: 'Send Request',
  T.appointmentReschedulePending: 'Reschedule request pending',
  T.appointmentRescheduleRequested: 'Reschedule requested',
  T.appointmentRescheduleAlreadyPending:
      'A reschedule request is already pending.',
  T.appointmentRescheduleApproved: 'Reschedule request approved',
  T.appointmentRescheduleRejected: 'Reschedule request was not approved',
  T.appointmentRescheduleFailed: "We couldn't send your request.",
  T.appointmentRescheduleSent: 'Reschedule Request Sent',
  T.appointmentRescheduleWait:
      'Kindly wait for the doctor to review and approve your request.',
  T.appointmentRescheduleUnchanged:
      'Your current appointment remains unchanged until the request is approved.',
  T.appointmentOk: 'OK',
  T.appointmentCancel: 'Cancel Appointment',
  T.appointmentCancelQuestion: 'Cancel Appointment?',
  T.appointmentKeep: 'Keep Appointment',
  T.appointmentCancelled: 'Appointment cancelled',
  T.appointmentCancelFailed: 'Unable to cancel appointment.',
  T.appointmentWillBeCancelled: 'will be cancelled.',
  T.appointmentNote: 'Appointment Note',
  T.appointmentNoBookedBody:
      'Your doctor will notify you when your next visit is booked.',
  T.prescriptionTitle: "Doctor's prescription",
  T.prescribedOn: 'Given on',
  T.morning: 'Morning',
  T.afternoon: 'Afternoon',
  T.night: 'Night',
  T.afterFood: 'After food',
  T.beforeFood: 'Before food',
  T.reminderTitle: 'Medicine time',
  T.reminderItIsTimeFor: 'it is time for your medicine',
  T.reminderYourMedicineFor: 'This medicine is for your',
  T.reminderTaken: 'I HAVE TAKEN IT',
  T.reminderSnooze: 'REMIND ME IN 10 MINUTES',
  T.reminderHearAgain: 'HEAR AGAIN',
  T.reminderTakenConfirm: 'Well done. Noted.',
  T.reminderPreview: 'Preview my reminder',
  T.dashboardListen: 'Listen',
  T.dashboardListenScreen: 'Listen to this screen',
  T.dashboardStop: 'Stop',
  T.dashboardStopSpeaking: 'Stop reading',
  T.dashboardNextAppointment: 'Next Appointment',
  T.dashboardMyPrescription: 'My Prescription',
  T.dashboardMyPrescriptionHint: "View your doctor's prescription",
  T.dashboardReport: 'Report',
  T.dashboardReportHint: 'View your doctor report',
  T.dashboardMedicines: 'Medicines',
  T.dashboardMedicinesHint: 'View your assigned medicines',
  T.dashboardMedicineReminders: 'Medicine Reminders',
  T.dashboardMedicineRemindersHint: 'Get reminders for your medicines',
  T.dashboardAppointments: 'Appointments',
  T.dashboardAppointmentsHint: 'View and manage your appointments',
  T.dashboardHealthSummary: 'Health Summary',
  T.dashboardHealthSummaryHint: 'Track your health in one place',
  T.healthTitle: 'My Health',
  T.healthLatestCheck: 'LATEST HEALTH CHECK',
  T.healthRecordedOn: 'Recorded on',
  T.healthVitalsHeading: 'Vitals from your latest consultation',
  T.healthHeartRate: 'Heart Rate',
  T.healthBloodPressure: 'Blood Pressure',
  T.healthOxygen: 'Oxygen Level',
  T.healthTemperature: 'Temperature',
  T.healthWeight: 'Weight',
  T.healthHeight: 'Height',
  T.healthNotRecorded: 'Not recorded',
  T.healthRecordedDuring: 'Recorded during your consultation with',
  T.healthLoading: 'Loading your latest health information…',
  T.healthLoadError: "We couldn't load your health information.",
  T.healthNoVitals: 'No vitals have been recorded yet.',
  T.healthNoVitalsBody:
      'Your health measurements will appear here after they are recorded during a doctor consultation.',
  T.vitalsHistoryTitle: 'Vitals History',
  T.vitalsHistoryButton: 'View Vitals History',
  T.vitalsHistoryHint:
      'Previous health measurements recorded during your doctor consultations.',
  T.vitalsHistoryEmpty: 'No vitals history available.',
  T.vitalsHistoryEmptyBody:
      'Your previous health measurements will appear here after doctor consultations.',
  T.vitalsHistoryLoading: 'Loading vitals history…',
  T.vitalsHistoryError: "We couldn't load your vitals history.",
  T.dashboardEmergencyHint: 'Tap for immediate help',
  T.dashboardTodaysMedicine: "Today's Medicine",
  T.dashboardNoMedicineToday: 'No medicine due today',
  T.greetingMorning: 'Good morning',
  T.greetingAfternoon: 'Good afternoon',
  T.greetingEvening: 'Good evening',
  T.navHome: 'Home',
  T.navAppointments: 'Appointments',
  T.navMedicines: 'Medicines',
  T.navMore: 'More',
  T.moreTitle: 'More',
  T.moreGreeting: 'Hello!',
  T.moreGreetingBody:
      'Manage your app settings, get help and view your records.',
  T.supportTitle: 'Support',
  T.supportHint: 'Call your hospital for help',
  T.privacySecurityTitle: 'Privacy & Security',
  T.privacySecurityHint: 'Who can see your information',
  T.comingSoonTitle: 'Coming soon',
  T.comingSoonBody:
      'This part of the app is still being built. It will be ready soon.',
  T.medicineTimesTitle: "Today's reminder times",
  T.medicineTimesHint:
      'The phone will remind you, and read the medicine out to you, at each '
      'of these times.',
  T.settingsTitle: 'Settings',
  T.settingsHint: 'Language, text size, voice and help',
  T.settingsLanguageSection: 'Language',
  T.settingsTextSizeSection: 'Text size',
  T.settingsTextSizeHint: 'Make the words in this app bigger.',
  T.settingsTextSizeNormal: 'Normal',
  T.settingsTextSizeLarge: 'Large',
  T.settingsTextSizeLargest: 'Very large',
  T.settingsTextSizePreview: 'Take 1 tablet after food.',
  T.settingsAppearanceSection: 'Display and theme',
  T.settingsThemeHint: 'Choose how the app looks on this phone.',
  T.settingsThemeSystem: 'Use phone setting',
  T.settingsThemeLight: 'Light',
  T.settingsThemeDark: 'Dark',
  T.settingsBoldText: 'Bold text',
  T.settingsBoldTextHint: 'Make words thicker and easier to see.',
  T.settingsHighContrast: 'High contrast',
  T.settingsHighContrastHint: 'Use stronger borders and text colours.',
  T.settingsVoiceSection: 'Voice',
  T.settingsVoiceHint: 'How fast the app reads things out to you.',
  T.settingsVoiceSlow: 'Slow',
  T.settingsVoiceNormal: 'Normal',
  T.settingsVoiceFast: 'Fast',
  T.settingsVoiceTry: 'TRY THE VOICE',
  T.settingsVoiceSample: 'This is how the app will read things out to you.',
  T.settingsTestReminder: 'TEST A MEDICINE REMINDER',
  T.settingsTestReminderHint: 'Hear your name, medicine and condition now.',
  T.settingsHelpSection: 'How to use this app',
  T.settingsHelpStep1:
      'The big green card at the top shows when to come to the hospital next.',
  T.settingsHelpStep2:
      'Press any card to open it. Press the arrow at the top left to come '
      'back.',
  T.settingsHelpStep3:
      'Press a Listen button to have the screen read out to you.',
  T.settingsHelpStep4:
      'Press the red EMERGENCY card if you need help right away. It always '
      'asks you once before calling.',
  T.settingsHelpListen: 'LISTEN TO THIS',
  T.settingsHospitalSection: 'Your hospital',
  T.settingsHospitalReception: 'Reception',
  T.settingsHospitalCallNote:
      'For anything that is not an emergency, call reception on this number.',
  T.settingsYourDetailsSection: 'Your details',
  T.settingsAboutSection: 'About',
  T.settingsVersion: 'App version',
  T.settingsPrivacyBody:
      'Your name, your illness and your medicines are kept by your hospital. '
      'Only the staff treating you can see them. Hospital staff linked this '
      'phone for you, and only they can change or remove that.',
};

const Map<T, String> _hindi = {
  T.appName: 'साथी',
  T.welcomeHeading: 'एक बार का अस्पताल लॉगिन',
  T.welcomeBody:
      'अस्पताल का स्टाफ़ इस फ़ोन को आपके स्वास्थ्य रिकॉर्ड से एक बार जोड़ देगा।',
  T.welcomeLinkedCaption: 'अस्पताल रिकॉर्ड से जुड़ा',
  T.askStaffToActivate: 'स्टाफ़ से चालू करवाएँ',
  T.nextStepScanner: 'अगला कदम: स्टाफ़ QR स्कैनर खोलेगा।',
  T.scanTitle: 'कोड स्कैन करें',
  T.scanInstruction: 'कैमरा उस कोड पर रखें जो रिसेप्शन दिखाएगा।',
  T.scanTorchOn: 'लाइट चालू करें',
  T.scanTorchOff: 'लाइट बंद करें',
  T.scanCameraUnavailable: 'कैमरा काम नहीं कर रहा',
  T.scanCameraUnavailableBody:
      'कैमरे की अनुमति दें, या अपना आईडी नंबर इस्तेमाल करें।',
  T.scanUseIdInstead: 'आईडी नंबर इस्तेमाल करें',
  T.scanLinking: 'कृपया प्रतीक्षा करें…',
  T.scanInvalidCode: 'यह अस्पताल का कोड नहीं है। रिसेप्शन से मदद लें।',
  T.manualTitle: 'अपनी आईडी डालें',
  T.manualHeading: 'अपनी आईडी और कोड लिखें',
  T.manualSubtext: 'ये दोनों रिसेप्शन देगा।',
  T.manualFieldId: 'मरीज़ आईडी',
  T.manualFieldIdHint: 'SAA-0000-0000',
  T.manualFieldCode: 'एक्टिवेशन कोड',
  T.manualErrorId: 'रिसेप्शन से मिली आईडी लिखें',
  T.manualErrorCode: 'एक्टिवेशन कोड दर्ज करें',
  T.manualSubmit: 'यह फ़ोन जोड़ें',
  T.manualCodeOnce: 'यह कोड सिर्फ़ एक बार चलता है।',
  T.manualNeedHelp: 'अगर आपके पास ये नहीं हैं तो रिसेप्शन से पूछें।',
  T.manualCannotConnect: 'अस्पताल से संपर्क नहीं हो पाया। दोबारा कोशिश करें।',
  T.yourId: 'आपकी आईडी',
  T.emergency: 'आपातकाल',
  T.emergencyHint: 'अभी अस्पताल को फ़ोन करें',
  T.nextAppointment: 'अगली मुलाक़ात',
  T.nextAppointmentHint: 'दोबारा कब आना है',
  T.prescription: 'डॉक्टर की पर्ची',
  T.prescriptionHint: 'आपकी दवाइयाँ',
  T.pastVisits: 'पिछली मुलाक़ातें',
  T.pastVisitsHint: 'पुरानी रिपोर्ट और दवाइयाँ',
  T.deviceManaged: 'इस डिवाइस का लॉगिन अस्पताल द्वारा संभाला जाता है',
  T.emergencyConfirmTitle: 'क्या अस्पताल को मदद के लिए फ़ोन करें?',
  T.emergencyConfirmBody: 'अस्पताल के आपातकालीन नंबर पर अभी फ़ोन जाएगा।',
  T.emergencyConfirmYes: 'हाँ, अभी फ़ोन करें',
  T.emergencyConfirmNo: 'नहीं, वापस जाएँ',
  T.emergencyCalling: 'अस्पताल को फ़ोन किया जा रहा है…',
  T.pleaseWait: 'कृपया प्रतीक्षा करें',
  T.cannotReachHospital: 'अभी अस्पताल से संपर्क नहीं हो पा रहा',
  T.cannotReachHospitalBody:
      'कृपया देखें कि इंटरनेट चालू है, फिर दोबारा कोशिश करें। आपकी जानकारी '
      'सुरक्षित है।',
  T.tryAgain: 'दोबारा कोशिश करें',
  T.goBack: 'वापस जाएँ',
  T.language: 'भाषा',
  T.chooseLanguage: 'अपनी भाषा चुनें',
  T.chooseLanguageHint: 'पूरा ऐप इसी भाषा में बदल जाएगा।',
  T.visitHistoryTitle: 'पिछली मुलाक़ातें',
  T.visitHistoryHint: 'उस दिन दी गई दवाइयाँ देखने के लिए मुलाक़ात पर दबाएँ।',
  T.doctorLabel: 'डॉक्टर',
  T.medicinesLabel: 'दवाइयाँ',
  T.nextVisitLabel: 'अगली मुलाक़ात',
  T.downloadReport: 'डाउनलोड करें',
  T.downloading: 'सहेजा जा रहा है…',
  T.downloaded: 'आपके फ़ोन में सहेज लिया गया',
  T.noVisitsTitle: 'अभी कोई मुलाक़ात नहीं',
  T.noVisitsBody:
      'डॉक्टर से पहली मुलाक़ात के बाद आपकी रिपोर्ट यहाँ दिखाई देगी।',
  T.appointmentTitle: 'अगली मुलाक़ात',
  T.appointmentNobooked: 'अभी कोई मुलाक़ात तय नहीं है',
  T.appointmentDaysAway: 'दिन बाद',
  T.appointmentToday: 'आज',
  T.appointmentTomorrow: 'कल',
  T.appointmentActions: 'अपॉइंटमेंट विकल्प',
  T.appointmentUpcoming: 'आगामी अपॉइंटमेंट',
  T.appointmentAddReminder: 'रिमाइंडर जोड़ें',
  T.appointmentRemindMe: 'मुझे याद दिलाएँ',
  T.appointmentOneDayBefore: '1 दिन पहले',
  T.appointmentTwoHoursBefore: '2 घंटे पहले',
  T.appointmentOneHourBefore: '1 घंटे पहले',
  T.appointmentThirtyMinutesBefore: '30 मिनट पहले',
  T.appointmentSaveReminder: 'रिमाइंडर सेव करें',
  T.appointmentReminderAdded: 'रिमाइंडर जोड़ दिया गया',
  T.appointmentReminderUpdated: 'रिमाइंडर अपडेट किया गया',
  T.appointmentReminderRemoved: 'रिमाइंडर हटा दिया गया',
  T.appointmentReminderPassed:
      'इस रिमाइंडर का समय पहले ही बीत चुका है। कृपया दूसरा विकल्प चुनें।',
  T.appointmentReminderFailed:
      'रिमाइंडर तय नहीं किया जा सका। नोटिफिकेशन अनुमति जाँचें और फिर प्रयास करें।',
  T.appointmentRequestReschedule: 'समय बदलने का अनुरोध',
  T.appointmentCurrent: 'वर्तमान अपॉइंटमेंट',
  T.appointmentPreferredDate: 'पसंदीदा तारीख',
  T.appointmentPreferredTime: 'पसंदीदा समय',
  T.appointmentReason: 'कारण',
  T.appointmentReasonForVisit: 'मुलाक़ात का कारण',
  T.appointmentOptional: 'वैकल्पिक',
  T.appointmentSendRequest: 'अनुरोध भेजें',
  T.appointmentReschedulePending: 'समय बदलने का अनुरोध लंबित है',
  T.appointmentRescheduleRequested: 'समय बदलने का अनुरोध भेज दिया गया',
  T.appointmentRescheduleAlreadyPending:
      'समय बदलने का अनुरोध पहले से लंबित है।',
  T.appointmentRescheduleApproved: 'समय बदलने का अनुरोध स्वीकार कर लिया गया है',
  T.appointmentRescheduleRejected: 'समय बदलने का अनुरोध स्वीकार नहीं किया गया',
  T.appointmentRescheduleFailed: 'आपका अनुरोध भेजा नहीं जा सका।',
  T.appointmentRescheduleSent: 'समय बदलने का अनुरोध भेज दिया गया',
  T.appointmentRescheduleWait:
      'कृपया डॉक्टर द्वारा आपके अनुरोध की समीक्षा और स्वीकृति की प्रतीक्षा करें।',
  T.appointmentRescheduleUnchanged:
      'अनुरोध स्वीकृत होने तक आपकी वर्तमान अपॉइंटमेंट में कोई बदलाव नहीं होगा।',
  T.appointmentOk: 'ठीक है',
  T.appointmentCancel: 'अपॉइंटमेंट रद्द करें',
  T.appointmentCancelQuestion: 'क्या अपॉइंटमेंट रद्द करें?',
  T.appointmentKeep: 'अपॉइंटमेंट रखें',
  T.appointmentCancelled: 'अपॉइंटमेंट रद्द कर दिया गया',
  T.appointmentCancelFailed: 'अपॉइंटमेंट रद्द नहीं किया जा सका।',
  T.appointmentWillBeCancelled: 'रद्द कर दिया जाएगा।',
  T.appointmentNote: 'अपॉइंटमेंट नोट',
  T.appointmentNoBookedBody:
      'अगली मुलाक़ात तय होने पर आपका डॉक्टर आपको सूचित करेगा।',
  T.prescriptionTitle: 'डॉक्टर की पर्ची',
  T.prescribedOn: 'दिनांक',
  T.morning: 'सुबह',
  T.afternoon: 'दोपहर',
  T.night: 'रात',
  T.afterFood: 'खाने के बाद',
  T.beforeFood: 'खाने से पहले',
  T.reminderTitle: 'दवा का समय',
  T.reminderItIsTimeFor: 'आपकी दवा का समय हो गया है',
  T.reminderYourMedicineFor: 'यह दवा आपकी इस बीमारी के लिए है',
  T.reminderTaken: 'मैंने दवा ले ली',
  T.reminderSnooze: '10 मिनट बाद याद दिलाएँ',
  T.reminderHearAgain: 'दोबारा सुनें',
  T.reminderTakenConfirm: 'बहुत अच्छा। दर्ज कर लिया गया।',
  T.reminderPreview: 'मेरा रिमाइंडर देखें',
  // ⚠️ NEEDS NATIVE REVIEW — AI-generated drafts, like the rest of this table.
  T.dashboardListen: 'सुनें',
  T.dashboardListenScreen: 'यह स्क्रीन सुनें',
  T.dashboardStop: 'रोकें',
  T.dashboardStopSpeaking: 'पढ़ना रोकें',
  T.dashboardNextAppointment: 'अगली मुलाक़ात',
  T.dashboardMyPrescription: 'मेरी पर्ची',
  T.dashboardMyPrescriptionHint: 'डॉक्टर की दी हुई पर्ची देखें',
  T.dashboardReport: 'रिपोर्ट',
  T.dashboardReportHint: 'डॉक्टर की रिपोर्ट देखें',
  T.dashboardMedicines: 'दवाइयाँ',
  T.dashboardMedicinesHint: 'निर्धारित दवाइयाँ देखें',
  T.dashboardMedicineReminders: 'दवा की याद',
  T.dashboardMedicineRemindersHint: 'दवा लेने की याद दिलाई जाएगी',
  T.dashboardAppointments: 'मुलाक़ातें',
  T.dashboardAppointmentsHint: 'अपनी मुलाक़ातें देखें और संभालें',
  T.dashboardHealthSummary: 'सेहत का ब्यौरा',
  T.dashboardHealthSummaryHint: 'अपनी सेहत एक ही जगह देखें',
  T.healthTitle: 'मेरा स्वास्थ्य',
  T.healthLatestCheck: 'नवीनतम स्वास्थ्य जाँच',
  T.healthRecordedOn: 'दर्ज किया गया',
  T.healthVitalsHeading: 'आपकी नवीनतम परामर्श की स्वास्थ्य माप',
  T.healthHeartRate: 'हृदय गति',
  T.healthBloodPressure: 'रक्तचाप',
  T.healthOxygen: 'ऑक्सीजन स्तर',
  T.healthTemperature: 'तापमान',
  T.healthWeight: 'वजन',
  T.healthHeight: 'लंबाई',
  T.healthNotRecorded: 'दर्ज नहीं किया गया',
  T.healthRecordedDuring: 'आपके परामर्श के दौरान दर्ज किया गया',
  T.healthLoading: 'आपकी नवीनतम स्वास्थ्य जानकारी लोड हो रही है…',
  T.healthLoadError: 'हम आपकी स्वास्थ्य जानकारी लोड नहीं कर सके।',
  T.healthNoVitals: 'अभी तक कोई स्वास्थ्य माप दर्ज नहीं किया गया है।',
  T.healthNoVitalsBody:
      'डॉक्टर के परामर्श के दौरान दर्ज किए जाने के बाद आपकी स्वास्थ्य माप यहाँ दिखाई देंगी।',
  T.vitalsHistoryTitle: 'स्वास्थ्य माप इतिहास',
  T.vitalsHistoryButton: 'स्वास्थ्य माप इतिहास देखें',
  T.vitalsHistoryHint:
      'डॉक्टर के परामर्श के दौरान दर्ज किए गए आपके पिछले स्वास्थ्य माप।',
  T.vitalsHistoryEmpty: 'कोई स्वास्थ्य माप इतिहास उपलब्ध नहीं है।',
  T.vitalsHistoryEmptyBody:
      'डॉक्टर के परामर्श के बाद आपके पिछले स्वास्थ्य माप यहाँ दिखाई देंगे।',
  T.vitalsHistoryLoading: 'स्वास्थ्य माप इतिहास लोड हो रहा है…',
  T.vitalsHistoryError: 'हम आपका स्वास्थ्य माप इतिहास लोड नहीं कर सके।',
  T.dashboardEmergencyHint: 'तुरंत मदद के लिए दबाएँ',
  T.dashboardTodaysMedicine: 'आज की दवा',
  T.dashboardNoMedicineToday: 'आज कोई दवा नहीं है',
  T.greetingMorning: 'शुभ प्रभात',
  T.greetingAfternoon: 'शुभ दोपहर',
  T.greetingEvening: 'शुभ संध्या',
  T.navHome: 'होम',
  T.navAppointments: 'मुलाक़ात',
  T.navMedicines: 'दवाइयाँ',
  T.navMore: 'और',
  T.moreTitle: 'और',
  T.moreGreeting: 'नमस्ते!',
  T.moreGreetingBody: 'ऐप की सेटिंग बदलें, मदद लें और अपने रिकॉर्ड देखें।',
  T.supportTitle: 'सहायता',
  T.supportHint: 'मदद के लिए अपने अस्पताल को फ़ोन करें',
  T.privacySecurityTitle: 'गोपनीयता और सुरक्षा',
  T.privacySecurityHint: 'आपकी जानकारी कौन देख सकता है',
  T.comingSoonTitle: 'जल्द आ रहा है',
  T.comingSoonBody: 'ऐप का यह हिस्सा अभी बन रहा है। यह जल्दी ही तैयार होगा।',
  T.medicineTimesTitle: 'आज याद दिलाने के समय',
  T.medicineTimesHint:
      'इनमें से हर समय पर फ़ोन आपको याद दिलाएगा और दवा का नाम पढ़कर सुनाएगा।',
  T.settingsTitle: 'सेटिंग',
  T.settingsHint: 'भाषा, अक्षरों का आकार, आवाज़ और मदद',
  T.settingsLanguageSection: 'भाषा',
  T.settingsTextSizeSection: 'अक्षरों का आकार',
  T.settingsTextSizeHint: 'इस ऐप के अक्षर बड़े करें।',
  T.settingsTextSizeNormal: 'सामान्य',
  T.settingsTextSizeLarge: 'बड़ा',
  T.settingsTextSizeLargest: 'बहुत बड़ा',
  T.settingsTextSizePreview: 'खाने के बाद 1 गोली लें।',
  T.settingsAppearanceSection: 'डिस्प्ले और थीम',
  T.settingsThemeHint: 'इस फ़ोन पर ऐप कैसा दिखे, चुनें।',
  T.settingsThemeSystem: 'फ़ोन की सेटिंग',
  T.settingsThemeLight: 'हल्का',
  T.settingsThemeDark: 'गहरा',
  T.settingsBoldText: 'गहरे अक्षर',
  T.settingsBoldTextHint: 'शब्दों को मोटा और पढ़ने में आसान बनाएँ।',
  T.settingsHighContrast: 'ज़्यादा कॉन्ट्रास्ट',
  T.settingsHighContrastHint: 'किनारों और अक्षरों को अधिक साफ़ दिखाएँ।',
  T.settingsVoiceSection: 'आवाज़',
  T.settingsVoiceHint: 'ऐप कितनी तेज़ी से पढ़कर सुनाए।',
  T.settingsVoiceSlow: 'धीमी',
  T.settingsVoiceNormal: 'सामान्य',
  T.settingsVoiceFast: 'तेज़',
  T.settingsVoiceTry: 'आवाज़ सुनकर देखें',
  T.settingsVoiceSample: 'ऐप आपको इसी तरह पढ़कर सुनाएगा।',
  T.settingsTestReminder: 'दवा की याद जाँचें',
  T.settingsTestReminderHint: 'अपना नाम, दवा और बीमारी अभी सुनें।',
  T.settingsHelpSection: 'इस ऐप को कैसे चलाएँ',
  T.settingsHelpStep1:
      'सबसे ऊपर का बड़ा हरा कार्ड बताता है कि अस्पताल दोबारा कब आना है।',
  T.settingsHelpStep2:
      'किसी भी कार्ड को खोलने के लिए उस पर दबाएँ। वापस आने के लिए ऊपर बाईं '
      'ओर के तीर को दबाएँ।',
  T.settingsHelpStep3: 'स्क्रीन पढ़कर सुनने के लिए "सुनें" बटन दबाएँ।',
  T.settingsHelpStep4:
      'अगर आपको अभी मदद चाहिए तो लाल आपातकाल कार्ड दबाएँ। फ़ोन करने से पहले '
      'यह हमेशा एक बार पूछता है।',
  T.settingsHelpListen: 'यह सुनें',
  T.settingsHospitalSection: 'आपका अस्पताल',
  T.settingsHospitalReception: 'रिसेप्शन',
  T.settingsHospitalCallNote:
      'जो बात आपातकाल न हो, उसके लिए इस नंबर पर रिसेप्शन को फ़ोन करें।',
  T.settingsYourDetailsSection: 'आपका ब्यौरा',
  T.settingsAboutSection: 'ऐप के बारे में',
  T.settingsVersion: 'ऐप का संस्करण',
  T.settingsPrivacyBody:
      'आपका नाम, आपकी बीमारी और आपकी दवाइयाँ आपका अस्पताल रखता है। इन्हें '
      'सिर्फ़ आपका इलाज करने वाला स्टाफ़ देख सकता है। यह फ़ोन अस्पताल के '
      'स्टाफ़ ने जोड़ा है, और उसे सिर्फ़ वही बदल या हटा सकते हैं।',
};

/// ⚠️ NEEDS NATIVE REVIEW — every string in this table.
///
/// AI-generated Kannada draft, unreviewed. See the header note on
/// [AppLanguage] for the review order; the reminder* and emergency* keys
/// carry the most risk and should be checked first.
const Map<T, String> _kannada = {
  T.appName: 'ಸಾಥಿ',
  T.welcomeHeading: 'ಒಮ್ಮೆ ಮಾತ್ರ ಆಸ್ಪತ್ರೆ ಲಾಗಿನ್',
  T.welcomeBody:
      'ಆಸ್ಪತ್ರೆ ಸಿಬ್ಬಂದಿ ಈ ಫೋನ್ ಅನ್ನು ನಿಮ್ಮ ಆರೋಗ್ಯ ದಾಖಲೆಗೆ ಒಮ್ಮೆ ಜೋಡಿಸುತ್ತಾರೆ.',
  T.welcomeLinkedCaption: 'ಆಸ್ಪತ್ರೆ ದಾಖಲೆಗೆ ಜೋಡಿಸಲಾಗಿದೆ',
  T.askStaffToActivate: 'ಸಿಬ್ಬಂದಿಗೆ ಚಾಲನೆ ಮಾಡಲು ಹೇಳಿ',
  T.nextStepScanner: 'ಮುಂದಿನ ಹಂತ: ಸಿಬ್ಬಂದಿ QR ಸ್ಕ್ಯಾನರ್ ತೆರೆಯುತ್ತಾರೆ.',
  T.scanTitle: 'ಕೋಡ್ ಸ್ಕ್ಯಾನ್ ಮಾಡಿ',
  T.scanInstruction: 'ಸ್ವಾಗತ ವಿಭಾಗ ತೋರಿಸುವ ಕೋಡ್‌ಗೆ ಕ್ಯಾಮೆರಾ ಹಿಡಿಯಿರಿ.',
  T.scanTorchOn: 'ಬೆಳಕು ಆನ್ ಮಾಡಿ',
  T.scanTorchOff: 'ಬೆಳಕು ಆಫ್ ಮಾಡಿ',
  T.scanCameraUnavailable: 'ಕ್ಯಾಮೆರಾ ಕೆಲಸ ಮಾಡುತ್ತಿಲ್ಲ',
  T.scanCameraUnavailableBody:
      'ಕ್ಯಾಮೆರಾಗೆ ಅನುಮತಿ ಕೊಡಿ, ಅಥವಾ ನಿಮ್ಮ ಗುರುತಿನ ಸಂಖ್ಯೆ ಬಳಸಿ.',
  T.scanUseIdInstead: 'ಗುರುತಿನ ಸಂಖ್ಯೆ ಬಳಸಿ',
  T.scanLinking: 'ದಯವಿಟ್ಟು ಕಾಯಿರಿ…',
  T.scanInvalidCode: 'ಇದು ಆಸ್ಪತ್ರೆಯ ಕೋಡ್ ಅಲ್ಲ. ಸ್ವಾಗತ ವಿಭಾಗದ ಸಹಾಯ ಪಡೆಯಿರಿ.',
  T.manualTitle: 'ನಿಮ್ಮ ಗುರುತಿನ ಸಂಖ್ಯೆ ಹಾಕಿ',
  T.manualHeading: 'ನಿಮ್ಮ ಸಂಖ್ಯೆ ಮತ್ತು ಕೋಡ್ ಬರೆಯಿರಿ',
  T.manualSubtext: 'ಇವೆರಡನ್ನೂ ಸ್ವಾಗತ ವಿಭಾಗ ಕೊಡುತ್ತದೆ.',
  T.manualFieldId: 'ರೋಗಿಯ ಸಂಖ್ಯೆ',
  T.manualFieldIdHint: 'SAA-0000-0000',
  T.manualFieldCode: 'ಆಕ್ಟಿವೇಶನ್ ಕೋಡ್',
  T.manualErrorId: 'ಸ್ವಾಗತ ವಿಭಾಗ ಕೊಟ್ಟ ಸಂಖ್ಯೆ ಬರೆಯಿರಿ',
  T.manualErrorCode: 'ಆಕ್ಟಿವೇಶನ್ ಕೋಡ್ ನಮೂದಿಸಿ',
  T.manualSubmit: 'ಈ ಫೋನ್ ಜೋಡಿಸಿ',
  T.manualCodeOnce: 'ಈ ಕೋಡ್ ಒಮ್ಮೆ ಮಾತ್ರ ಕೆಲಸ ಮಾಡುತ್ತದೆ.',
  T.manualNeedHelp: 'ಇವು ನಿಮ್ಮ ಬಳಿ ಇಲ್ಲದಿದ್ದರೆ ಸ್ವಾಗತ ವಿಭಾಗವನ್ನು ಕೇಳಿ.',
  T.manualCannotConnect: 'ಆಸ್ಪತ್ರೆಯನ್ನು ಸಂಪರ್ಕಿಸಲು ಆಗಲಿಲ್ಲ. ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
  T.yourId: 'ನಿಮ್ಮ ಗುರುತಿನ ಸಂಖ್ಯೆ',
  T.emergency: 'ತುರ್ತು',
  T.emergencyHint: 'ಈಗಲೇ ಆಸ್ಪತ್ರೆಗೆ ಕರೆ ಮಾಡಿ',
  T.nextAppointment: 'ಮುಂದಿನ ಭೇಟಿ',
  T.nextAppointmentHint: 'ಮತ್ತೆ ಯಾವಾಗ ಬರಬೇಕು',
  T.prescription: 'ವೈದ್ಯರ ಚೀಟಿ',
  T.prescriptionHint: 'ನಿಮ್ಮ ಔಷಧಿಗಳು',
  T.pastVisits: 'ಹಿಂದಿನ ಭೇಟಿಗಳು',
  T.pastVisitsHint: 'ಹಳೆಯ ವರದಿ ಮತ್ತು ಔಷಧಿ',
  T.deviceManaged: 'ಈ ಸಾಧನದ ಲಾಗಿನ್ ಅನ್ನು ಆಸ್ಪತ್ರೆ ನಿರ್ವಹಿಸುತ್ತದೆ',
  T.emergencyConfirmTitle: 'ಸಹಾಯಕ್ಕಾಗಿ ಆಸ್ಪತ್ರೆಗೆ ಕರೆ ಮಾಡಬೇಕೇ?',
  T.emergencyConfirmBody: 'ಆಸ್ಪತ್ರೆಯ ತುರ್ತು ಸಂಖ್ಯೆಗೆ ಈಗಲೇ ಕರೆ ಹೋಗುತ್ತದೆ.',
  T.emergencyConfirmYes: 'ಹೌದು, ಈಗಲೇ ಕರೆ ಮಾಡಿ',
  T.emergencyConfirmNo: 'ಇಲ್ಲ, ಹಿಂದೆ ಹೋಗಿ',
  T.emergencyCalling: 'ಆಸ್ಪತ್ರೆಗೆ ಕರೆ ಮಾಡುತ್ತಿದ್ದೇವೆ…',
  T.pleaseWait: 'ದಯವಿಟ್ಟು ಕಾಯಿರಿ',
  T.cannotReachHospital: 'ಈಗ ಆಸ್ಪತ್ರೆಯನ್ನು ಸಂಪರ್ಕಿಸಲು ಆಗುತ್ತಿಲ್ಲ',
  T.cannotReachHospitalBody:
      'ಇಂಟರ್ನೆಟ್ ಚಾಲನೆಯಲ್ಲಿದೆಯೇ ಎಂದು ನೋಡಿ, ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ. ನಿಮ್ಮ ಮಾಹಿತಿ ಸುರಕ್ಷಿತವಾಗಿದೆ.',
  T.tryAgain: 'ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ',
  T.goBack: 'ಹಿಂದೆ ಹೋಗಿ',
  T.language: 'ಭಾಷೆ',
  T.chooseLanguage: 'ನಿಮ್ಮ ಭಾಷೆ ಆಯ್ಕೆ ಮಾಡಿ',
  T.chooseLanguageHint: 'ಇಡೀ ಆ್ಯಪ್ ಈ ಭಾಷೆಗೆ ಬದಲಾಗುತ್ತದೆ.',
  T.visitHistoryTitle: 'ಹಿಂದಿನ ಭೇಟಿಗಳು',
  T.visitHistoryHint: 'ಆ ದಿನ ಕೊಟ್ಟ ಔಷಧಿ ನೋಡಲು ಭೇಟಿಯನ್ನು ಒತ್ತಿ.',
  T.doctorLabel: 'ವೈದ್ಯರು',
  T.medicinesLabel: 'ಔಷಧಿಗಳು',
  T.nextVisitLabel: 'ಮುಂದಿನ ಭೇಟಿ',
  T.downloadReport: 'ಡೌನ್‌ಲೋಡ್',
  T.downloading: 'ಉಳಿಸುತ್ತಿದೆ…',
  T.downloaded: 'ನಿಮ್ಮ ಫೋನ್‌ನಲ್ಲಿ ಉಳಿಸಲಾಗಿದೆ',
  T.noVisitsTitle: 'ಇನ್ನೂ ಯಾವುದೇ ಭೇಟಿ ಇಲ್ಲ',
  T.noVisitsBody: 'ವೈದ್ಯರ ಮೊದಲ ಭೇಟಿಯ ನಂತರ ನಿಮ್ಮ ವರದಿಗಳು ಇಲ್ಲಿ ಕಾಣಿಸುತ್ತವೆ.',
  T.appointmentTitle: 'ಮುಂದಿನ ಭೇಟಿ',
  T.appointmentNobooked: 'ಇನ್ನೂ ಭೇಟಿ ನಿಗದಿಯಾಗಿಲ್ಲ',
  T.appointmentDaysAway: 'ದಿನಗಳ ನಂತರ',
  T.appointmentToday: 'ಇಂದು',
  T.appointmentTomorrow: 'ನಾಳೆ',
  T.appointmentActions: 'ಅಪಾಯಿಂಟ್‌ಮೆಂಟ್ ಆಯ್ಕೆಗಳು',
  T.appointmentUpcoming: 'ಮುಂಬರುವ ಅಪಾಯಿಂಟ್‌ಮೆಂಟ್',
  T.appointmentAddReminder: 'ಜ್ಞಾಪನೆ ಸೇರಿಸಿ',
  T.appointmentRemindMe: 'ನನಗೆ ನೆನಪಿಸಿ',
  T.appointmentOneDayBefore: '1 ದಿನ ಮೊದಲು',
  T.appointmentTwoHoursBefore: '2 ಗಂಟೆಗಳ ಮೊದಲು',
  T.appointmentOneHourBefore: '1 ಗಂಟೆ ಮೊದಲು',
  T.appointmentThirtyMinutesBefore: '30 ನಿಮಿಷ ಮೊದಲು',
  T.appointmentSaveReminder: 'ಜ್ಞಾಪನೆ ಉಳಿಸಿ',
  T.appointmentReminderAdded: 'ಜ್ಞಾಪನೆ ಸೇರಿಸಲಾಗಿದೆ',
  T.appointmentReminderUpdated: 'ಜ್ಞಾಪನೆ ನವೀಕರಿಸಲಾಗಿದೆ',
  T.appointmentReminderRemoved: 'ಜ್ಞಾಪನೆ ತೆಗೆದುಹಾಕಲಾಗಿದೆ',
  T.appointmentReminderPassed:
      'ಈ ಜ್ಞಾಪನೆಯ ಸಮಯ ಈಗಾಗಲೇ ಕಳೆದಿದೆ. ದಯವಿಟ್ಟು ಬೇರೆ ಆಯ್ಕೆಯನ್ನು ಆರಿಸಿ.',
  T.appointmentReminderFailed:
      'ಜ್ಞಾಪನೆಯನ್ನು ನಿಗದಿಪಡಿಸಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ. ಸೂಚನೆ ಅನುಮತಿಯನ್ನು ಪರಿಶೀಲಿಸಿ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
  T.appointmentRequestReschedule: 'ಸಮಯ ಬದಲಾವಣೆಗೆ ವಿನಂತಿ',
  T.appointmentCurrent: 'ಪ್ರಸ್ತುತ ಅಪಾಯಿಂಟ್‌ಮೆಂಟ್',
  T.appointmentPreferredDate: 'ಆದ್ಯತೆಯ ದಿನಾಂಕ',
  T.appointmentPreferredTime: 'ಆದ್ಯತೆಯ ಸಮಯ',
  T.appointmentReason: 'ಕಾರಣ',
  T.appointmentReasonForVisit: 'ಭೇಟಿಯ ಕಾರಣ',
  T.appointmentOptional: 'ಐಚ್ಛಿಕ',
  T.appointmentSendRequest: 'ವಿನಂತಿ ಕಳುಹಿಸಿ',
  T.appointmentReschedulePending: 'ಸಮಯ ಬದಲಾವಣೆಯ ವಿನಂತಿ ಬಾಕಿಯಿದೆ',
  T.appointmentRescheduleRequested: 'ಸಮಯ ಬದಲಾವಣೆಯ ವಿನಂತಿ ಕಳುಹಿಸಲಾಗಿದೆ',
  T.appointmentRescheduleAlreadyPending: 'ಸಮಯ ಬದಲಾವಣೆಯ ವಿನಂತಿ ಈಗಾಗಲೇ ಬಾಕಿಯಿದೆ.',
  T.appointmentRescheduleApproved: 'ಸಮಯ ಬದಲಾವಣೆಯ ವಿನಂತಿಯನ್ನು ಅನುಮೋದಿಸಲಾಗಿದೆ',
  T.appointmentRescheduleRejected: 'ಸಮಯ ಬದಲಾವಣೆಯ ವಿನಂತಿಯನ್ನು ಅನುಮೋದಿಸಲಾಗಿಲ್ಲ',
  T.appointmentRescheduleFailed: 'ನಿಮ್ಮ ವಿನಂತಿಯನ್ನು ಕಳುಹಿಸಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.',
  T.appointmentRescheduleSent: 'ಸಮಯ ಬದಲಾವಣೆಯ ವಿನಂತಿ ಕಳುಹಿಸಲಾಗಿದೆ',
  T.appointmentRescheduleWait:
      'ದಯವಿಟ್ಟು ವೈದ್ಯರು ನಿಮ್ಮ ವಿನಂತಿಯನ್ನು ಪರಿಶೀಲಿಸಿ ಅನುಮೋದಿಸುವವರೆಗೆ ಕಾಯಿರಿ.',
  T.appointmentRescheduleUnchanged:
      'ವಿನಂತಿ ಅನುಮೋದನೆಯಾಗುವವರೆಗೆ ನಿಮ್ಮ ಪ್ರಸ್ತುತ ಅಪಾಯಿಂಟ್‌ಮೆಂಟ್ ಬದಲಾಗುವುದಿಲ್ಲ.',
  T.appointmentOk: 'ಸರಿ',
  T.appointmentCancel: 'ಅಪಾಯಿಂಟ್‌ಮೆಂಟ್ ರದ್ದುಮಾಡಿ',
  T.appointmentCancelQuestion: 'ಅಪಾಯಿಂಟ್‌ಮೆಂಟ್ ರದ್ದುಮಾಡಬೇಕೇ?',
  T.appointmentKeep: 'ಅಪಾಯಿಂಟ್‌ಮೆಂಟ್ ಉಳಿಸಿ',
  T.appointmentCancelled: 'ಅಪಾಯಿಂಟ್‌ಮೆಂಟ್ ರದ್ದಾಗಿದೆ',
  T.appointmentCancelFailed: 'ಅಪಾಯಿಂಟ್‌ಮೆಂಟ್ ರದ್ದುಮಾಡಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.',
  T.appointmentWillBeCancelled: 'ರದ್ದಾಗುತ್ತದೆ.',
  T.appointmentNote: 'ಅಪಾಯಿಂಟ್‌ಮೆಂಟ್ ಟಿಪ್ಪಣಿ',
  T.appointmentNoBookedBody:
      'ನಿಮ್ಮ ಮುಂದಿನ ಭೇಟಿ ನಿಗದಿಯಾದಾಗ ವೈದ್ಯರು ನಿಮಗೆ ತಿಳಿಸುತ್ತಾರೆ.',
  T.prescriptionTitle: 'ವೈದ್ಯರ ಚೀಟಿ',
  T.prescribedOn: 'ದಿನಾಂಕ',
  T.morning: 'ಬೆಳಿಗ್ಗೆ',
  T.afternoon: 'ಮಧ್ಯಾಹ್ನ',
  T.night: 'ರಾತ್ರಿ',
  T.afterFood: 'ಊಟದ ನಂತರ',
  T.beforeFood: 'ಊಟದ ಮೊದಲು',
  T.reminderTitle: 'ಔಷಧಿ ಸಮಯ',
  T.reminderItIsTimeFor: 'ನಿಮ್ಮ ಔಷಧಿ ತೆಗೆದುಕೊಳ್ಳುವ ಸಮಯ ಆಗಿದೆ',
  T.reminderYourMedicineFor: 'ಈ ಔಷಧಿ ನಿಮ್ಮ ಈ ಕಾಯಿಲೆಗಾಗಿ',
  T.reminderTaken: 'ನಾನು ಔಷಧಿ ತೆಗೆದುಕೊಂಡೆ',
  T.reminderSnooze: '10 ನಿಮಿಷದ ನಂತರ ನೆನಪಿಸಿ',
  T.reminderHearAgain: 'ಮತ್ತೆ ಕೇಳಿ',
  T.reminderTakenConfirm: 'ಒಳ್ಳೆಯದು. ದಾಖಲಾಗಿದೆ.',
  T.reminderPreview: 'ನನ್ನ ನೆನಪೋಲೆ ನೋಡಿ',
  // ⚠️ NEEDS NATIVE REVIEW — AI-generated drafts, like the rest of this table.
  T.dashboardListen: 'ಕೇಳಿ',
  T.dashboardListenScreen: 'ಈ ಪರದೆಯನ್ನು ಕೇಳಿ',
  T.dashboardStop: 'ನಿಲ್ಲಿಸಿ',
  T.dashboardStopSpeaking: 'ಓದುವುದನ್ನು ನಿಲ್ಲಿಸಿ',
  T.dashboardNextAppointment: 'ಮುಂದಿನ ಭೇಟಿ',
  T.dashboardMyPrescription: 'ನನ್ನ ಚೀಟಿ',
  T.dashboardMyPrescriptionHint: 'ವೈದ್ಯರು ಕೊಟ್ಟ ಚೀಟಿ ನೋಡಿ',
  T.dashboardReport: 'ವರದಿ',
  T.dashboardReportHint: 'ವೈದ್ಯರ ವರದಿಯನ್ನು ನೋಡಿ',
  T.dashboardMedicines: 'ಔಷಧಿಗಳು',
  T.dashboardMedicinesHint: 'ನಿಗದಿಪಡಿಸಿದ ಔಷಧಿಗಳನ್ನು ವೀಕ್ಷಿಸಿ',
  T.dashboardMedicineReminders: 'ಔಷಧಿ ನೆನಪು',
  T.dashboardMedicineRemindersHint: 'ಔಷಧಿ ತೆಗೆದುಕೊಳ್ಳಲು ನೆನಪಿಸಲಾಗುತ್ತದೆ',
  T.dashboardAppointments: 'ಭೇಟಿಗಳು',
  T.dashboardAppointmentsHint: 'ನಿಮ್ಮ ಭೇಟಿಗಳನ್ನು ನೋಡಿ ಮತ್ತು ನಿರ್ವಹಿಸಿ',
  T.dashboardHealthSummary: 'ಆರೋಗ್ಯ ಸಾರಾಂಶ',
  T.dashboardHealthSummaryHint: 'ನಿಮ್ಮ ಆರೋಗ್ಯವನ್ನು ಒಂದೇ ಕಡೆ ನೋಡಿ',
  T.healthTitle: 'ನನ್ನ ಆರೋಗ್ಯ',
  T.healthLatestCheck: 'ಇತ್ತೀಚಿನ ಆರೋಗ್ಯ ಪರಿಶೀಲನೆ',
  T.healthRecordedOn: 'ದಾಖಲಿಸಿದ ದಿನಾಂಕ',
  T.healthVitalsHeading: 'ನಿಮ್ಮ ಇತ್ತೀಚಿನ ಸಮಾಲೋಚನೆಯ ಆರೋಗ್ಯ ಮಾಪನಗಳು',
  T.healthHeartRate: 'ಹೃದಯ ಬಡಿತ',
  T.healthBloodPressure: 'ರಕ್ತದೊತ್ತಡ',
  T.healthOxygen: 'ಆಮ್ಲಜನಕ ಮಟ್ಟ',
  T.healthTemperature: 'ದೇಹದ ತಾಪಮಾನ',
  T.healthWeight: 'ತೂಕ',
  T.healthHeight: 'ಎತ್ತರ',
  T.healthNotRecorded: 'ದಾಖಲಾಗಿಲ್ಲ',
  T.healthRecordedDuring: 'ನಿಮ್ಮ ಸಮಾಲೋಚನೆಯ ವೇಳೆ ದಾಖಲಿಸಲಾಗಿದೆ',
  T.healthLoading: 'ನಿಮ್ಮ ಇತ್ತೀಚಿನ ಆರೋಗ್ಯ ಮಾಹಿತಿಯನ್ನು ಲೋಡ್ ಮಾಡಲಾಗುತ್ತಿದೆ…',
  T.healthLoadError: 'ನಿಮ್ಮ ಆರೋಗ್ಯ ಮಾಹಿತಿಯನ್ನು ಲೋಡ್ ಮಾಡಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.',
  T.healthNoVitals: 'ಇನ್ನೂ ಯಾವುದೇ ಆರೋಗ್ಯ ಮಾಪನಗಳನ್ನು ದಾಖಲಿಸಲಾಗಿಲ್ಲ.',
  T.healthNoVitalsBody:
      'ವೈದ್ಯರ ಸಮಾಲೋಚನೆಯ ವೇಳೆ ಆರೋಗ್ಯ ಮಾಪನಗಳನ್ನು ದಾಖಲಿಸಿದ ನಂತರ ಅವು ಇಲ್ಲಿ ಕಾಣಿಸುತ್ತವೆ.',
  T.vitalsHistoryTitle: 'ಆರೋಗ್ಯ ಮಾಪನಗಳ ಇತಿಹಾಸ',
  T.vitalsHistoryButton: 'ಆರೋಗ್ಯ ಮಾಪನಗಳ ಇತಿಹಾಸ ನೋಡಿ',
  T.vitalsHistoryHint:
      'ವೈದ್ಯರ ಸಮಾಲೋಚನೆಯ ವೇಳೆ ದಾಖಲಿಸಲಾದ ನಿಮ್ಮ ಹಿಂದಿನ ಆರೋಗ್ಯ ಮಾಪನಗಳು.',
  T.vitalsHistoryEmpty: 'ಆರೋಗ್ಯ ಮಾಪನಗಳ ಇತಿಹಾಸ ಲಭ್ಯವಿಲ್ಲ.',
  T.vitalsHistoryEmptyBody:
      'ವೈದ್ಯರ ಸಮಾಲೋಚನೆಯ ನಂತರ ನಿಮ್ಮ ಹಿಂದಿನ ಆರೋಗ್ಯ ಮಾಪನಗಳು ಇಲ್ಲಿ ಕಾಣಿಸುತ್ತವೆ.',
  T.vitalsHistoryLoading: 'ಆರೋಗ್ಯ ಮಾಪನಗಳ ಇತಿಹಾಸ ಲೋಡ್ ಆಗುತ್ತಿದೆ…',
  T.vitalsHistoryError:
      'ನಿಮ್ಮ ಆರೋಗ್ಯ ಮಾಪನಗಳ ಇತಿಹಾಸವನ್ನು ಲೋಡ್ ಮಾಡಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.',
  T.dashboardEmergencyHint: 'ತಕ್ಷಣ ಸಹಾಯಕ್ಕಾಗಿ ಒತ್ತಿ',
  T.dashboardTodaysMedicine: 'ಇಂದಿನ ಔಷಧಿ',
  T.dashboardNoMedicineToday: 'ಇಂದು ಯಾವುದೇ ಔಷಧಿ ಇಲ್ಲ',
  T.greetingMorning: 'ಶುಭೋದಯ',
  T.greetingAfternoon: 'ಶುಭ ಮಧ್ಯಾಹ್ನ',
  T.greetingEvening: 'ಶುಭ ಸಂಜೆ',
  T.navHome: 'ಮುಖಪುಟ',
  T.navAppointments: 'ಭೇಟಿ',
  T.navMedicines: 'ಔಷಧಿ',
  T.navMore: 'ಇನ್ನಷ್ಟು',
  T.moreTitle: 'ಇನ್ನಷ್ಟು',
  T.moreGreeting: 'ನಮಸ್ಕಾರ!',
  T.moreGreetingBody:
      'ಆ್ಯಪ್ ಸೆಟ್ಟಿಂಗ್ ಬದಲಿಸಿ, ಸಹಾಯ ಪಡೆಯಿರಿ ಮತ್ತು ನಿಮ್ಮ ದಾಖಲೆ ನೋಡಿ.',
  T.supportTitle: 'ಬೆಂಬಲ',
  T.supportHint: 'ಸಹಾಯಕ್ಕಾಗಿ ನಿಮ್ಮ ಆಸ್ಪತ್ರೆಗೆ ಕರೆ ಮಾಡಿ',
  T.privacySecurityTitle: 'ಗೌಪ್ಯತೆ ಮತ್ತು ಸುರಕ್ಷತೆ',
  T.privacySecurityHint: 'ನಿಮ್ಮ ಮಾಹಿತಿಯನ್ನು ಯಾರು ನೋಡಬಹುದು',
  T.comingSoonTitle: 'ಶೀಘ್ರದಲ್ಲಿ ಬರಲಿದೆ',
  T.comingSoonBody:
      'ಆ್ಯಪ್‌ನ ಈ ಭಾಗ ಇನ್ನೂ ಸಿದ್ಧವಾಗುತ್ತಿದೆ. ಶೀಘ್ರದಲ್ಲೇ ಸಿದ್ಧವಾಗುತ್ತದೆ.',
  T.medicineTimesTitle: 'ಇಂದು ನೆನಪಿಸುವ ಸಮಯಗಳು',
  T.medicineTimesHint:
      'ಈ ಪ್ರತಿಯೊಂದು ಸಮಯದಲ್ಲೂ ಫೋನ್ ನಿಮಗೆ ನೆನಪಿಸುತ್ತದೆ ಮತ್ತು ಔಷಧಿಯ ಹೆಸರನ್ನು '
      'ಓದಿ ಹೇಳುತ್ತದೆ.',
  T.settingsTitle: 'ಸೆಟ್ಟಿಂಗ್',
  T.settingsHint: 'ಭಾಷೆ, ಅಕ್ಷರದ ಗಾತ್ರ, ಧ್ವನಿ ಮತ್ತು ಸಹಾಯ',
  T.settingsLanguageSection: 'ಭಾಷೆ',
  T.settingsTextSizeSection: 'ಅಕ್ಷರದ ಗಾತ್ರ',
  T.settingsTextSizeHint: 'ಈ ಆ್ಯಪ್‌ನ ಅಕ್ಷರಗಳನ್ನು ದೊಡ್ಡದಾಗಿ ಮಾಡಿ.',
  T.settingsTextSizeNormal: 'ಸಾಮಾನ್ಯ',
  T.settingsTextSizeLarge: 'ದೊಡ್ಡದು',
  T.settingsTextSizeLargest: 'ತುಂಬಾ ದೊಡ್ಡದು',
  T.settingsTextSizePreview: 'ಊಟದ ನಂತರ 1 ಮಾತ್ರೆ ತೆಗೆದುಕೊಳ್ಳಿ.',
  T.settingsAppearanceSection: 'ಪರದೆ ಮತ್ತು ಥೀಮ್',
  T.settingsThemeHint: 'ಈ ಫೋನ್‌ನಲ್ಲಿ ಆ್ಯಪ್ ಹೇಗೆ ಕಾಣಬೇಕು ಎಂದು ಆರಿಸಿ.',
  T.settingsThemeSystem: 'ಫೋನ್ ಸೆಟ್ಟಿಂಗ್ ಬಳಸಿ',
  T.settingsThemeLight: 'ಬೆಳಕು',
  T.settingsThemeDark: 'ಕತ್ತಲೆ',
  T.settingsBoldText: 'ದಪ್ಪ ಅಕ್ಷರ',
  T.settingsBoldTextHint: 'ಪದಗಳನ್ನು ದಪ್ಪವಾಗಿ ಮತ್ತು ಸುಲಭವಾಗಿ ಕಾಣುವಂತೆ ಮಾಡಿ.',
  T.settingsHighContrast: 'ಹೆಚ್ಚಿನ ಕಾಂಟ್ರಾಸ್ಟ್',
  T.settingsHighContrastHint:
      'ಗಡಿ ಮತ್ತು ಪಠ್ಯದ ಬಣ್ಣಗಳನ್ನು ಇನ್ನಷ್ಟು ಸ್ಪಷ್ಟಗೊಳಿಸಿ.',
  T.settingsVoiceSection: 'ಧ್ವನಿ',
  T.settingsVoiceHint: 'ಆ್ಯಪ್ ಎಷ್ಟು ವೇಗವಾಗಿ ಓದಿ ಹೇಳಬೇಕು.',
  T.settingsVoiceSlow: 'ನಿಧಾನ',
  T.settingsVoiceNormal: 'ಸಾಮಾನ್ಯ',
  T.settingsVoiceFast: 'ವೇಗ',
  T.settingsVoiceTry: 'ಧ್ವನಿ ಕೇಳಿ ನೋಡಿ',
  T.settingsVoiceSample: 'ಆ್ಯಪ್ ನಿಮಗೆ ಹೀಗೆ ಓದಿ ಹೇಳುತ್ತದೆ.',
  T.settingsTestReminder: 'ಔಷಧಿ ನೆನಪನ್ನು ಪರೀಕ್ಷಿಸಿ',
  T.settingsTestReminderHint: 'ನಿಮ್ಮ ಹೆಸರು, ಔಷಧಿ ಮತ್ತು ಕಾಯಿಲೆಯನ್ನು ಈಗ ಕೇಳಿ.',
  T.settingsHelpSection: 'ಈ ಆ್ಯಪ್ ಹೇಗೆ ಬಳಸುವುದು',
  T.settingsHelpStep1:
      'ಮೇಲಿನ ದೊಡ್ಡ ಹಸಿರು ಕಾರ್ಡ್ ಆಸ್ಪತ್ರೆಗೆ ಮತ್ತೆ ಯಾವಾಗ ಬರಬೇಕು ಎಂದು ತೋರಿಸುತ್ತದೆ.',
  T.settingsHelpStep2:
      'ಯಾವುದೇ ಕಾರ್ಡ್ ತೆರೆಯಲು ಅದನ್ನು ಒತ್ತಿ. ಹಿಂದೆ ಬರಲು ಎಡ ಮೇಲ್ಭಾಗದ ಬಾಣವನ್ನು '
      'ಒತ್ತಿ.',
  T.settingsHelpStep3: 'ಪರದೆಯನ್ನು ಓದಿ ಕೇಳಲು "ಕೇಳಿ" ಗುಂಡಿಯನ್ನು ಒತ್ತಿ.',
  T.settingsHelpStep4:
      'ಈಗಲೇ ಸಹಾಯ ಬೇಕಿದ್ದರೆ ಕೆಂಪು ತುರ್ತು ಕಾರ್ಡ್ ಒತ್ತಿ. ಕರೆ ಮಾಡುವ ಮೊದಲು ಅದು '
      'ಯಾವಾಗಲೂ ಒಮ್ಮೆ ಕೇಳುತ್ತದೆ.',
  T.settingsHelpListen: 'ಇದನ್ನು ಕೇಳಿ',
  T.settingsHospitalSection: 'ನಿಮ್ಮ ಆಸ್ಪತ್ರೆ',
  T.settingsHospitalReception: 'ಸ್ವಾಗತ ವಿಭಾಗ',
  T.settingsHospitalCallNote:
      'ತುರ್ತು ಅಲ್ಲದ ಯಾವುದೇ ವಿಷಯಕ್ಕೆ ಈ ಸಂಖ್ಯೆಗೆ ಸ್ವಾಗತ ವಿಭಾಗಕ್ಕೆ ಕರೆ ಮಾಡಿ.',
  T.settingsYourDetailsSection: 'ನಿಮ್ಮ ವಿವರ',
  T.settingsAboutSection: 'ಆ್ಯಪ್ ಬಗ್ಗೆ',
  T.settingsVersion: 'ಆ್ಯಪ್ ಆವೃತ್ತಿ',
  T.settingsPrivacyBody:
      'ನಿಮ್ಮ ಹೆಸರು, ನಿಮ್ಮ ಕಾಯಿಲೆ ಮತ್ತು ನಿಮ್ಮ ಔಷಧಿಗಳನ್ನು ನಿಮ್ಮ ಆಸ್ಪತ್ರೆ '
      'ಇಟ್ಟುಕೊಂಡಿರುತ್ತದೆ. ನಿಮಗೆ ಚಿಕಿತ್ಸೆ ನೀಡುವ ಸಿಬ್ಬಂದಿ ಮಾತ್ರ ಅವನ್ನು ನೋಡಬಹುದು. '
      'ಈ ಫೋನ್ ಅನ್ನು ಆಸ್ಪತ್ರೆ ಸಿಬ್ಬಂದಿ ಜೋಡಿಸಿದ್ದಾರೆ, ಅದನ್ನು ಅವರು ಮಾತ್ರ ಬದಲಾಯಿಸಬಹುದು '
      'ಅಥವಾ ತೆಗೆಯಬಹುದು.',
};
