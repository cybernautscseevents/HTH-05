import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import 'api_client.dart';
// ⚠️ TEST-ONLY — delete with the three testLogin* guards below. See
// lib/src/data/test_login.dart for removal instructions.
import 'data/test_login.dart';
import 'l10n/app_text.dart';
import 'models.dart';
import 'services/reminder_service.dart';
import 'settings.dart';
import 'utils/camera_lifecycle.dart';

/// [offline] is distinct from [unlinked] on purpose.
///
/// Previously any failure while restoring the session — including a dropped
/// mobile signal — landed the patient back on the "ask reception to link this
/// phone" welcome screen, as though their device had been unlinked. For an
/// elderly patient that reads as "the hospital has removed me", and the only
/// apparent fix is a trip to the hospital. Only a real 401 (staff revoked the
/// device) now clears the token; everything else keeps the session and offers
/// a retry.
enum AppStatus { loading, unlinked, patientLinked, offline }

class AppController extends ChangeNotifier {
  AppController({ApiClient? api, FlutterSecureStorage? storage})
    : api = api ?? ApiClient(),
      _storage = storage ?? const FlutterSecureStorage();

  static const _deviceTokenKey = 'patient_device_token';
  static const _patientIdKey = 'patient_id';
  static const _languageKey = 'patient_language';
  static const _textSizeKey = 'patient_text_size';
  static const _voiceSpeedKey = 'patient_voice_speed';
  static const _themeModeKey = 'patient_theme_mode';
  static const _boldTextKey = 'patient_bold_text';
  static const _highContrastKey = 'patient_high_contrast';
  static const _listenBallXKey = 'patient_listen_ball_x';
  static const _listenBallYKey = 'patient_listen_ball_y';

  final ApiClient api;
  final FlutterSecureStorage _storage;

  AppStatus status = AppStatus.loading;
  Patient? patient;

  /// The patient's chosen language. Persisted on the device, so the app opens
  /// in their language every time without them having to set it again.
  AppLanguage language = AppLanguage.english;

  /// How large the app draws its own text, on top of the phone's system font
  /// setting.
  PatientTextSize textSize = PatientTextSize.normal;

  /// How fast the app speaks.
  VoiceSpeed voiceSpeed = VoiceSpeed.normal;

  SaathiThemeMode themeMode = SaathiThemeMode.system;
  bool boldText = false;
  bool highContrast = false;

  double? listenBallX;
  double? listenBallY;

  Future<void> setListenBallPosition(double x, double y) async {
    listenBallX = x;
    listenBallY = y;
    await _storage.write(key: _listenBallXKey, value: x.toString());
    await _storage.write(key: _listenBallYKey, value: y.toString());
  }

  Future<void> setLanguage(AppLanguage next) async {
    if (next == language) return;
    language = next;
    notifyListeners();
    await _storage.write(key: _languageKey, value: next.code);
  }

  Future<void> setTextSize(PatientTextSize next) async {
    if (next == textSize) return;
    textSize = next;
    notifyListeners();
    await _storage.write(key: _textSizeKey, value: next.name);
  }

  Future<void> setVoiceSpeed(VoiceSpeed next) async {
    if (next == voiceSpeed) return;
    voiceSpeed = next;
    ReminderService.instance.speechRate = next.rate;
    notifyListeners();
    await _storage.write(key: _voiceSpeedKey, value: next.name);
  }

  Future<void> setThemeMode(SaathiThemeMode next) async {
    if (next == themeMode) return;
    themeMode = next;
    notifyListeners();
    await _storage.write(key: _themeModeKey, value: next.name);
  }

  Future<void> setBoldText(bool next) async {
    if (next == boldText) return;
    boldText = next;
    notifyListeners();
    await _storage.write(key: _boldTextKey, value: next.toString());
  }

  Future<void> setHighContrast(bool next) async {
    if (next == highContrast) return;
    highContrast = next;
    notifyListeners();
    await _storage.write(key: _highContrastKey, value: next.toString());
  }

  Future<void> initialize() async {
    language = AppLanguage.fromCode(await _storage.read(key: _languageKey));
    textSize = PatientTextSize.fromName(await _storage.read(key: _textSizeKey));
    voiceSpeed = VoiceSpeed.fromName(await _storage.read(key: _voiceSpeedKey));
    themeMode = SaathiThemeMode.fromName(
      await _storage.read(key: _themeModeKey),
    );
    boldText = await _storage.read(key: _boldTextKey) == 'true';
    highContrast = await _storage.read(key: _highContrastKey) == 'true';
    listenBallX = double.tryParse(
      await _storage.read(key: _listenBallXKey) ?? '',
    );
    listenBallY = double.tryParse(
      await _storage.read(key: _listenBallYKey) ?? '',
    );
    ReminderService.instance.speechRate = voiceSpeed.rate;

    // Request notification and exact alarm permissions on start/install so alarms
    // and heads-up home-screen pop-ups function immediately.
    try {
      await ReminderService.instance.requestPermissions();
    } catch (_) {}

    // Hook up notification action callback so tapping "Mark as Taken" on the
    // popup notification directly records adherence in the background.
    ReminderService.instance.onAdherenceAction = (itemId, actionStatus) async {
      try {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await recordAdherence(
          prescriptionItemId: itemId,
          scheduledDate: today,
          timeSlot: 'doctor_prescribed',
          status: actionStatus,
        );
      } catch (_) {}
    };

    final token = await _storage.read(key: _deviceTokenKey);
    final patientIdStr = await _storage.read(key: _patientIdKey);
    final patientId = patientIdStr != null ? int.tryParse(patientIdStr) : null;

    if (token == null || patientId == null) {
      status = AppStatus.unlinked;
      notifyListeners();
      return;
    }

    // ⚠️ TEST-ONLY GUARD 1 of 3 — delete with lib/src/data/test_login.dart.
    if (testLoginMatchesStoredToken(token)) {
      patient = kTestPatient;
      status = AppStatus.patientLinked;
      notifyListeners();
      return;
    }

    try {
      patient = await api.patientMe(token, patientId);
      status = AppStatus.patientLinked;
      startClinicalRecordsSync();
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _storage.delete(key: _deviceTokenKey);
        await _storage.delete(key: _patientIdKey);
        status = AppStatus.unlinked;
      } else {
        status = AppStatus.offline;
      }
    } catch (_) {
      status = AppStatus.offline;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Clinical data helpers — all propagate errors so screens can show retry UI.
  // ---------------------------------------------------------------------------

  Future<(String, int)?> _tokenAndId() async {
    final token = await _storage.read(key: _deviceTokenKey);
    final patientIdStr = await _storage.read(key: _patientIdKey);
    final patientId = patientIdStr != null ? int.tryParse(patientIdStr) : null;
    if (token == null || patientId == null) return null;
    return (token, patientId);
  }

  Future<Map<String, dynamic>> summarizeDischargeDocument(
    String fileName,
    List<int> bytes,
  ) async {
    final credentials = await _tokenAndId();
    if (credentials == null || testLoginMatchesStoredToken(credentials.$1)) {
      throw const ApiException(
        'Link your patient account to analyze a document',
      );
    }
    return api.summarizeDischargeDocument(
      token: credentials.$1,
      fileName: fileName,
      bytes: bytes,
    );
  }

  Future<Map<String, dynamic>> saveDischargeReport(
    Map<String, dynamic> analysis,
    String fileName,
  ) async {
    final credentials = await _tokenAndId();
    if (credentials == null || testLoginMatchesStoredToken(credentials.$1)) {
      throw const ApiException('Link your patient account to save a report');
    }
    final extracted = Map<String, dynamic>.from(analysis['extracted'] as Map);
    final source = Map<String, dynamic>.from(analysis['source'] as Map);
    return api.saveDischargeReport(
      token: credentials.$1,
      report: {
        'original_filename': fileName,
        'content_type': source['type'],
        'document_reference': source['document_reference'],
        'extracted_text': analysis['extracted_text'],
        'structured_data': extracted,
        'summary': analysis['summary'],
        'hospital_name': extracted['hospital'],
        'doctor_name': extracted['doctor'],
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchDischargeReports() async {
    final credentials = await _tokenAndId();
    if (credentials == null || testLoginMatchesStoredToken(credentials.$1)) {
      return [];
    }
    return api.getDischargeReports(credentials.$1);
  }

  Future<Map<String, dynamic>> askDischargeQuestion({
    required int reportId,
    required String question,
    required String language,
  }) async {
    final credentials = await _tokenAndId();
    if (credentials == null || testLoginMatchesStoredToken(credentials.$1)) {
      throw const ApiException(
        'Link your patient account to ask about a report',
      );
    }
    return api.askDischargeQuestion(
      token: credentials.$1,
      reportId: reportId,
      question: question,
      language: language,
    );
  }

  Future<List<PatientVisit>> fetchVisits() async {
    final creds = await _tokenAndId();
    if (creds == null) return [];
    // ⚠️ TEST-ONLY GUARD
    if (testLoginMatchesStoredToken(creds.$1)) return [];
    return api.getVisits(creds.$1, creds.$2);
  }

  Future<HealthSummary> fetchHealthSummary() async {
    final creds = await _tokenAndId();
    if (creds == null || testLoginMatchesStoredToken(creds.$1)) {
      return const HealthSummary(hasData: false);
    }
    return api.getHealthSummary(creds.$1);
  }

  Future<VitalHistoryPage> fetchVitalsHistory({
    int limit = 10,
    int offset = 0,
    int days = 0,
    bool oldest = false,
  }) async {
    final creds = await _tokenAndId();
    if (creds == null || testLoginMatchesStoredToken(creds.$1)) {
      return const VitalHistoryPage(items: [], hasMore: false, offset: 0);
    }
    return api.getVitalsHistory(
      creds.$1,
      limit: limit,
      offset: offset,
      days: days,
      oldest: oldest,
    );
  }

  Future<List<PatientReport>> fetchReports() async {
    final creds = await _tokenAndId();
    if (creds == null) return [];
    if (testLoginMatchesStoredToken(creds.$1)) return [];
    return api.getReports(creds.$1, creds.$2);
  }

  Future<List<PatientMedicalHistory>> fetchMedicalHistory() async {
    final creds = await _tokenAndId();
    if (creds == null) return [];
    if (testLoginMatchesStoredToken(creds.$1)) return [];
    return api.getMedicalHistory(creds.$1, creds.$2);
  }

  List<ClinicalVisit> clinicalVisits = [];
  PatientAppointment? nextAppointment;
  Timer? _clinicalSyncTimer;

  ClinicalVisit? get latestReportVisit {
    for (final cv in clinicalVisits) {
      if (cv.reportDatetime != null ||
          cv.diagnosis != null ||
          cv.reportNotes != null) {
        return cv;
      }
    }
    return null;
  }

  void startClinicalRecordsSync() {
    _clinicalSyncTimer?.cancel();
    fetchClinicalVisits(
      notify: true,
    ).catchError((Object _) => <ClinicalVisit>[]);
    fetchNextAppointment().catchError((Object _) => null);
    _tokenAndId().then((creds) {
      if (creds == null || testLoginMatchesStoredToken(creds.$1)) return;
      _clinicalSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        fetchClinicalVisits(
          notify: true,
        ).catchError((Object _) => <ClinicalVisit>[]);
        fetchNextAppointment().catchError((Object _) => null);
      });
    });
  }

  void stopClinicalRecordsSync() {
    _clinicalSyncTimer?.cancel();
    _clinicalSyncTimer = null;
  }

  /// Fetches doctor records independently from appointments and uploaded reports.
  ///
  /// Throws [ApiException] on network/auth errors so callers can show a
  /// proper error state with retry rather than silently showing nothing.
  Future<List<ClinicalVisit>> fetchClinicalVisits({bool notify = false}) async {
    final creds = await _tokenAndId();
    if (creds == null) return [];
    // ⚠️ TEST-ONLY GUARD — test login has no real patient_id
    if (testLoginMatchesStoredToken(creds.$1)) return [];
    final records = await api.getClinicalRecords(creds.$1, creds.$2);

    final countChanged = records.length != clinicalVisits.length;
    final latestNewId = records.isNotEmpty ? records.first.visit.visitId : null;
    final latestOldId = clinicalVisits.isNotEmpty
        ? clinicalVisits.first.visit.visitId
        : null;
    final latestNewDiag = records.isNotEmpty ? records.first.diagnosis : null;
    final latestOldDiag = clinicalVisits.isNotEmpty
        ? clinicalVisits.first.diagnosis
        : null;
    clinicalVisits = records;

    if (notify &&
        (countChanged ||
            latestNewId != latestOldId ||
            latestNewDiag != latestOldDiag)) {
      notifyListeners();
    }
    return records;
  }

  Future<PatientAppointment?> fetchNextAppointment() async {
    final creds = await _tokenAndId();
    if (creds == null) return null;
    if (testLoginMatchesStoredToken(creds.$1)) return null;
    final appt = await api.getNextAppointment(creds.$1, creds.$2);
    if (appt != null) {
      unawaited(
        ReminderService.instance
            .refreshAppointmentReminder(
              appointmentId: appt.appointmentId,
              appointmentTime: appt.date,
              body: 'Dr. ${appt.doctorName} • ${appt.hospitalName}',
            )
            .catchError((Object _) {}),
      );
    }
    if (appt?.appointmentId != nextAppointment?.appointmentId ||
        appt?.appointmentDatetime != nextAppointment?.appointmentDatetime ||
        appt?.rescheduleRequest?.requestId !=
            nextAppointment?.rescheduleRequest?.requestId ||
        appt?.rescheduleRequest?.status !=
            nextAppointment?.rescheduleRequest?.status) {
      nextAppointment = appt;
      notifyListeners();
    }
    return appt;
  }

  Future<void> cancelAppointment(int appointmentId) async {
    final creds = await _tokenAndId();
    if (creds == null) throw ApiException('Session expired');
    await api.cancelAppointment(creds.$1, appointmentId);
    await fetchNextAppointment();
  }

  Future<void> requestAppointmentReschedule(
    int appointmentId,
    DateTime preferred,
    String? reason,
  ) async {
    final creds = await _tokenAndId();
    if (creds == null) throw ApiException('Session expired');
    await api.requestAppointmentReschedule(
      creds.$1,
      appointmentId,
      preferred,
      reason,
    );
    await fetchNextAppointment();
  }

  Future<void> recordAdherence({
    required int prescriptionItemId,
    required String scheduledDate,
    required String timeSlot,
    required String status,
  }) async {
    final creds = await _tokenAndId();
    if (creds == null) return;
    if (testLoginMatchesStoredToken(creds.$1)) return;
    await api.recordAdherence(
      creds.$1,
      creds.$2,
      prescriptionItemId: prescriptionItemId,
      scheduledDate: scheduledDate,
      timeSlot: timeSlot,
      status: status,
    );
  }

  Future<Map<String, dynamic>> fetchAdherence() async {
    final creds = await _tokenAndId();
    if (creds == null) return {};
    if (testLoginMatchesStoredToken(creds.$1)) return {};
    return api.getAdherence(creds.$1, creds.$2);
  }

  // ---------------------------------------------------------------------------
  // Retry after an [AppStatus.offline] state.
  // ---------------------------------------------------------------------------

  Future<void> retry() async {
    status = AppStatus.loading;
    notifyListeners();
    await initialize();
  }

  Future<void> linkWithQr(String scannedValue) async {
    int? patientId;
    String? deviceIdentifier;
    String? activationCode;

    try {
      final decoded = jsonDecode(scannedValue);
      if (decoded is Map<String, dynamic>) {
        patientId = decoded['patient_id'] is int
            ? decoded['patient_id'] as int
            : int.tryParse(decoded['patient_id'].toString());
        deviceIdentifier = decoded['device_identifier'] as String?;
        activationCode = decoded['activation_code'] as String?;
      }
    } catch (_) {}

    if (patientId == null ||
        deviceIdentifier == null ||
        activationCode == null) {
      final uri = Uri.tryParse(scannedValue);
      if (uri != null) {
        patientId = int.tryParse(
          uri.queryParameters['patient_id'] ??
              uri.queryParameters['patientId'] ??
              '',
        );
        deviceIdentifier =
            uri.queryParameters['identifier'] ??
            uri.queryParameters['device_identifier'];
        activationCode =
            uri.queryParameters['code'] ??
            uri.queryParameters['activation_code'];

        final testToken = uri.queryParameters['token'];
        if (testToken != null && testLoginMatchesQrToken(testToken)) {
          await _completeTestLogin();
          return;
        }
      }
    }

    if (patientId == null ||
        deviceIdentifier == null ||
        activationCode == null ||
        activationCode.isEmpty) {
      throw const ApiException(
        'This is not a valid Saathi activation QR code.',
      );
    }

    await _link(
      patientId: patientId,
      deviceIdentifier: deviceIdentifier,
      activationCode: activationCode,
    );
  }

  Future<void> linkManually({
    int? patientId,
    String? registrationNo,
    required String deviceIdentifier,
    required String activationCode,
  }) async {
    // ⚠️ TEST-ONLY GUARD 3 of 3 — delete with lib/src/data/test_login.dart.
    final idStr = patientId?.toString() ?? registrationNo ?? '';
    if (testLoginMatchesCredentials(idStr, activationCode)) {
      await _completeTestLogin();
      return;
    }

    await _link(
      patientId: patientId,
      registrationNo: registrationNo,
      deviceIdentifier: deviceIdentifier,
      activationCode: activationCode,
    );
  }

  /// ⚠️ TEST-ONLY — delete with lib/src/data/test_login.dart.
  Future<void> _completeTestLogin() async {
    await _storage.write(key: _deviceTokenKey, value: kTestDeviceToken);
    await _storage.write(key: _patientIdKey, value: '1');
    patient = kTestPatient;
    status = AppStatus.patientLinked;
    stopCameraHardware();
    notifyListeners();
  }

  Future<void> _link({
    int? patientId,
    String? registrationNo,
    required String deviceIdentifier,
    required String activationCode,
  }) async {
    final result = await api.linkPatient(
      patientId: patientId,
      registrationNo: registrationNo,
      deviceIdentifier: deviceIdentifier,
      activationCode: activationCode,
    );
    final token = result.$1;
    final returnedPatientId = result.$2;

    await _storage.write(key: _deviceTokenKey, value: token);
    await _storage.write(
      key: _patientIdKey,
      value: returnedPatientId.toString(),
    );

    patient = await api.patientMe(token, returnedPatientId);
    status = AppStatus.patientLinked;
    startClinicalRecordsSync();
    stopCameraHardware();
    notifyListeners();
  }
}
