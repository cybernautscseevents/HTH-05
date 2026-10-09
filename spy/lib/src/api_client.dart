import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

// ── Auth / Staff data classes ─────────────────────────────────────────────

class StaffInfo {
  final int id;
  final String username;
  final String role;

  StaffInfo({required this.id, required this.username, required this.role});

  /// Backend returns {id, username, role} — note: 'username' not 'fullName'.
  factory StaffInfo.fromJson(Map<String, dynamic> json) {
    return StaffInfo(
      id: json['id'] as int,
      username: json['username'] as String,
      role: json['role'] as String,
    );
  }
}

class LoginResponse {
  final String accessToken;
  final StaffInfo staff;

  LoginResponse({required this.accessToken, required this.staff});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] as String,
      staff: StaffInfo.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

// ── Patient data classes matching the real backend ────────────────────────

class PatientInfo {
  final String fullName;
  final String? dateOfBirth;
  final String? diseaseCondition;
  final String preferredLanguage;
  final String? emergencyContact;

  PatientInfo({
    required this.fullName,
    this.dateOfBirth,
    this.diseaseCondition,
    this.preferredLanguage = 'English',
    this.emergencyContact,
  });
}

class RegisterPatientResponse {
  final bool isMock;
  final PatientInfo patient;

  final int? patientId;
  final String? registrationNo;
  final String? serverMessage;

  // Mock-mode only
  final String? patientUid;
  final String? activationCode;
  final String? qrPayload;

  RegisterPatientResponse({
    this.isMock = false,
    required this.patient,
    this.patientId,
    this.registrationNo,
    this.serverMessage,
    this.patientUid,
    this.activationCode,
    this.qrPayload,
  });
}

class PatientSearchResult {
  final int patientId;
  final String registrationNo;
  final String name;
  final String? dateOfBirth;
  final String? diseaseCondition;
  final String preferredLanguage;

  PatientSearchResult({
    required this.patientId,
    required this.registrationNo,
    required this.name,
    this.dateOfBirth,
    this.diseaseCondition,
    this.preferredLanguage = 'English',
  });

  factory PatientSearchResult.fromJson(Map<String, dynamic> json) {
    return PatientSearchResult(
      patientId: json['patient_id'] as int,
      registrationNo: json['registration_no'] as String,
      name: json['name'] as String,
      dateOfBirth: json['date_of_birth'] as String?,
      diseaseCondition: json['disease_condition'] as String?,
      preferredLanguage: (json['preferred_language'] as String?) ?? 'English',
    );
  }
}

class DoctorInfo {
  final int staffId;
  final String name;
  final String? department;
  final String? specialization;
  const DoctorInfo({
    required this.staffId,
    required this.name,
    this.department,
    this.specialization,
  });
  factory DoctorInfo.fromJson(Map<String, dynamic> json) => DoctorInfo(
    staffId: json['staff_id'] as int,
    name: json['name'] as String,
    department: json['department'] as String?,
    specialization: json['specialization'] as String?,
  );
}

class DoctorAssignment {
  final bool assigned;
  final int patientId;
  final int? doctorId;
  final String? doctorName;
  final String? department;
  final String? specialization;
  final String? assignedAt;
  const DoctorAssignment({
    required this.patientId,
    required this.assigned,
    this.doctorId,
    this.doctorName,
    this.department,
    this.specialization,
    this.assignedAt,
  });
  factory DoctorAssignment.fromJson(Map<String, dynamic> json) {
    final assigned = json['assigned'] as bool? ?? (json['doctor_id'] != null);
    final doctor = json['doctor'] as Map<String, dynamic>?;
    final source = doctor ?? json;
    return DoctorAssignment(
      patientId: json['patient_id'] as int,
      assigned: assigned,
      doctorId: source['doctor_id'] as int? ?? source['id'] as int?,
      doctorName: source['doctor_name'] as String? ?? source['name'] as String?,
      department: source['department'] as String?,
      specialization: source['specialization'] as String?,
      assignedAt: source['assigned_at'] as String?,
    );
  }
}

/// Matches GET /patients/{patient_id}/devices
class PatientDevice {
  final int deviceId;
  final int patientId;
  final String deviceIdentifier;
  final String status; // pending | active | revoked
  final DateTime? linkedAt;
  final DateTime? revokedAt;

  PatientDevice({
    required this.deviceId,
    required this.patientId,
    required this.deviceIdentifier,
    required this.status,
    this.linkedAt,
    this.revokedAt,
  });

  factory PatientDevice.fromJson(Map<String, dynamic> json) {
    return PatientDevice(
      deviceId: json['device_id'] as int,
      patientId: json['patient_id'] as int,
      deviceIdentifier: json['device_identifier'] as String,
      status: json['status'] as String,
      linkedAt: json['linked_at'] != null
          ? DateTime.tryParse(json['linked_at'] as String)
          : null,
      revokedAt: json['revoked_at'] != null
          ? DateTime.tryParse(json['revoked_at'] as String)
          : null,
    );
  }
}

/// Returned by POST /patients/{patient_id}/activation
class ActivationResult {
  final int patientId;
  final int deviceId;
  final String deviceIdentifier;
  final String activationCode;
  final String? expiresAt;

  /// Set when the activation has already been consumed by the patient.
  /// When non-null, the QR/code should not be shown as scannable again.
  final String? usedAt;

  /// The qr_payload is a JSON object with patient_id, device_identifier, activation_code.
  /// Encode it as JSON string for the QR.
  final Map<String, dynamic>? qrPayload;

  /// True when the activation has been consumed (patient scanned successfully).
  bool get isUsed => usedAt != null;

  ActivationResult({
    required this.patientId,
    required this.deviceId,
    required this.deviceIdentifier,
    required this.activationCode,
    this.expiresAt,
    this.usedAt,
    required this.qrPayload,
  });

  factory ActivationResult.fromJson(Map<String, dynamic> json) {
    return ActivationResult(
      patientId: json['patient_id'] as int,
      deviceId: json['device_id'] as int,
      deviceIdentifier: json['device_identifier'] as String,
      activationCode: json['activation_code'] as String,
      expiresAt: json['expires_at'] as String?,
      usedAt: json['used_at'] as String?,
      qrPayload: json['qr_payload'] as Map<String, dynamic>?,
    );
  }

  /// JSON string to encode in the QR code widget.
  String get qrJsonString => jsonEncode(qrPayload ?? {});
}

/// Matches GET /patients/{patient_id}/medical-history
class ApiMedicalHistory {
  final int historyId;
  final int patientId;
  final String? medicineName;
  final String? medicineType;
  final String? dosage;
  final String? frequency;
  final String? startDate;
  final String? endDate;
  final String? reason;
  final String? notes;
  final int? visitId;
  final String? createdAt;

  const ApiMedicalHistory({
    required this.historyId,
    required this.patientId,
    this.medicineName,
    this.medicineType,
    this.dosage,
    this.frequency,
    this.startDate,
    this.endDate,
    this.reason,
    this.notes,
    this.visitId,
    this.createdAt,
  });

  factory ApiMedicalHistory.fromJson(Map<String, dynamic> json) {
    return ApiMedicalHistory(
      historyId: json['history_id'] as int,
      patientId: json['patient_id'] as int,
      medicineName: json['medicine_name'] as String?,
      medicineType: json['medicine_type'] as String?,
      dosage: json['dosage'] as String?,
      frequency: json['frequency'] as String?,
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      reason: json['reason'] as String?,
      notes: json['notes'] as String?,
      visitId: json['visit_id'] as int?,
      createdAt: json['created_at'] as String?,
    );
  }
}

/// Matches GET /patients/{patient_id}/visits
class ApiVisit {
  final int visitId;
  final int patientId;
  final int? doctorId;
  final String? visitDate;
  final String visitType;
  final String admissionStatus;
  final String? dischargeStatus;
  final int? assignedDoctorId;
  final String? assignedDoctorName;
  final String status;
  final String? reason;
  final String? notes;
  final String? temperature;
  final String? bloodPressure;
  final String? pulse;
  final String? spo2;
  final String? weight;
  final String? height;
  final String? createdAt;

  const ApiVisit({
    required this.visitId,
    required this.patientId,
    this.doctorId,
    this.visitDate,
    this.visitType = 'consultation',
    this.admissionStatus = 'not_admitted',
    this.dischargeStatus,
    this.assignedDoctorId,
    this.assignedDoctorName,
    this.status = 'completed',
    this.reason,
    this.notes,
    this.temperature,
    this.bloodPressure,
    this.pulse,
    this.spo2,
    this.weight,
    this.height,
    this.createdAt,
  });

  factory ApiVisit.fromJson(Map<String, dynamic> json) {
    return ApiVisit(
      visitId: json['visit_id'] as int,
      patientId: json['patient_id'] as int,
      doctorId: json['doctor_id'] as int?,
      visitDate: json['visit_date'] as String?,
      visitType: (json['visit_type'] as String?) ?? 'consultation',
      admissionStatus: (json['admission_status'] as String?) ?? 'not_admitted',
      dischargeStatus: json['discharge_status'] as String?,
      assignedDoctorId: json['assigned_doctor_id'] as int?,
      assignedDoctorName: json['assigned_doctor_name'] as String?,
      status: (json['status'] as String?) ?? 'completed',
      reason: json['reason'] as String?,
      notes: json['notes'] as String?,
      temperature: json['temperature'] as String?,
      bloodPressure: json['blood_pressure'] as String?,
      pulse: json['pulse'] as String?,
      spo2: json['spo2'] as String?,
      weight: json['weight'] as String?,
      height: json['height'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

/// Matches GET /patients/{patient_id}/reports
class ApiReport {
  final int reportId;
  final int patientId;
  final int? visitId;
  final int? doctorId;
  final int versionNo;
  final String diagnosis;
  final String? clinicalNotes;
  final String? voiceTranscript;
  final String? reportDatetime;
  final bool isFinal;
  final String? createdAt;

  const ApiReport({
    required this.reportId,
    required this.patientId,
    this.visitId,
    this.doctorId,
    this.versionNo = 1,
    required this.diagnosis,
    this.clinicalNotes,
    this.voiceTranscript,
    this.reportDatetime,
    this.isFinal = true,
    this.createdAt,
  });

  factory ApiReport.fromJson(Map<String, dynamic> json) {
    return ApiReport(
      reportId: json['report_id'] as int,
      patientId: json['patient_id'] as int,
      visitId: json['visit_id'] as int?,
      doctorId: json['doctor_id'] as int?,
      versionNo: (json['version_no'] as int?) ?? 1,
      diagnosis: json['diagnosis'] as String,
      clinicalNotes: json['clinical_notes'] as String?,
      voiceTranscript: json['voice_transcript'] as String?,
      reportDatetime: json['report_datetime'] as String?,
      isFinal: (json['is_final'] as bool?) ?? true,
      createdAt: json['created_at'] as String?,
    );
  }
}

// ── API Client ────────────────────────────────────────────────────────────

class ApiClient {
  final String baseUrl;

  ApiClient({
    this.baseUrl = const String.fromEnvironment(
      'API_URL',
      defaultValue: 'http://localhost:8000',
    ),
  });

  Map<String, String> _headers({String? token}) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  // ── Authentication ────────────────────────────────────────────────────

  /// Backend POST /auth/login expects application/x-www-form-urlencoded
  Future<LoginResponse> login(String username, String password) async {
    debugPrint('[ApiClient.login] Attempting login for user: $username');
    debugPrint('[ApiClient.login] POST $baseUrl/auth/login');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': username, 'password': password},
      );
      debugPrint('[ApiClient.login] HTTP ${response.statusCode}');
      // Log response body structure (keys only) — NEVER log access_token value
      try {
        final preview = jsonDecode(response.body);
        if (preview is Map) {
          debugPrint(
            '[ApiClient.login] Response keys: ${preview.keys.toList()}',
          );
          if (preview.containsKey('user') && preview['user'] is Map) {
            final user = preview['user'] as Map;
            debugPrint('[ApiClient.login] user keys: ${user.keys.toList()}');
            debugPrint('[ApiClient.login] user.role: ${user['role']}');
          }
        }
      } catch (_) {
        debugPrint('[ApiClient.login] Response body is not JSON');
      }
      final result = _handleResponse(
        response,
        (data) => LoginResponse.fromJson(data),
      );
      debugPrint(
        '[ApiClient.login] LoginResponse parsed OK, role=${result.staff.role}',
      );
      return result;
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('[ApiClient.login] Exception type: ${e.runtimeType}');
      debugPrint('[ApiClient.login] Exception message: $e');
      // Distinguish network/connection errors from other failures
      final msg = e.toString().toLowerCase();
      if (msg.contains('socketexception') ||
          msg.contains('connection refused') ||
          msg.contains('network is unreachable') ||
          msg.contains('no route to host') ||
          msg.contains('failed host lookup')) {
        throw ApiException(
          'Network is unreachable. Please check your connection.',
        );
      }
      if (msg.contains('clientexception') ||
          msg.contains('connection closed') ||
          msg.contains('xmlhttprequest error')) {
        throw ApiException(
          'Unable to connect to the server. Is the backend running at $baseUrl?',
        );
      }
      throw ApiException('Login failed: ${e.runtimeType} — $e');
    }
  }

  // ── Patient Registration ──────────────────────────────────────────────

  Future<RegisterPatientResponse> registerPatient({
    required String name,
    String? dateOfBirth,
    String? diseaseCondition,
    String preferredLanguage = 'English',
    String? emergencyContact,
    int? assignedDoctorId,
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/patients/register'),
        headers: _headers(token: token),
        body: jsonEncode({
          'name': name,
          if (dateOfBirth != null && dateOfBirth.isNotEmpty)
            'date_of_birth': dateOfBirth,
          if (diseaseCondition != null && diseaseCondition.isNotEmpty)
            'disease_condition': diseaseCondition,
          'preferred_language': preferredLanguage,
          if (emergencyContact != null && emergencyContact.isNotEmpty)
            'emergency_contact': emergencyContact,
          if (assignedDoctorId != null) 'assigned_doctor_id': assignedDoctorId,
        }),
      );

      final data = _handleResponse(response, (d) => d);

      return RegisterPatientResponse(
        isMock: false,
        patient: PatientInfo(
          fullName: name,
          dateOfBirth: dateOfBirth,
          diseaseCondition: diseaseCondition,
          preferredLanguage: preferredLanguage,
          emergencyContact: emergencyContact,
        ),
        patientId: data['patient_id'] as int?,
        registrationNo: data['registration_no'] as String?,
        serverMessage: data['message'] as String?,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _wrapException('Registration failed', e);
    }
  }

  // ── Notifications ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getNotifications(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications'),
        headers: _headers(token: token),
      );
      final data = _handleResponse(response, (d) => d);
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> markNotificationRead(
    int notificationId, {
    required String token,
  }) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
        headers: _headers(token: token),
      );
    } catch (_) {}
  }

  Future<void> markAllNotificationsRead({required String token}) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/notifications/read-all'),
        headers: _headers(token: token),
      );
    } catch (_) {}
  }

  // ── Patient Search ────────────────────────────────────────────────────

  Future<List<PatientSearchResult>> searchPatients(
    String query, {
    required String token,
  }) async {
    try {
      final trimmed = query.trim();
      final uri = trimmed.isEmpty
          ? Uri.parse('$baseUrl/patients/search')
          : Uri.parse(
              '$baseUrl/patients/search?search=${Uri.encodeComponent(trimmed)}',
            );
      final response = await http.get(uri, headers: _headers(token: token));

      final data = _handleResponse(response, (d) => d);

      if (data is List) {
        return data
            .cast<Map<String, dynamic>>()
            .map(PatientSearchResult.fromJson)
            .toList();
      }
      return [];
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _wrapException('Search failed', e);
    }
  }

  Future<List<DoctorInfo>> getDoctors({required String token}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/doctors'),
      headers: _headers(token: token),
    );
    final data = _handleResponse(response, (d) => d);
    return data is List
        ? data.cast<Map<String, dynamic>>().map(DoctorInfo.fromJson).toList()
        : [];
  }

  Future<DoctorAssignment> getAssignedDoctor(
    int patientId, {
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/patients/$patientId/assigned-doctor'),
      headers: _headers(token: token),
    );
    return _handleResponse(
      response,
      (d) => DoctorAssignment.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<DoctorAssignment> assignDoctor(
    int patientId,
    int doctorId, {
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/patients/$patientId/assign-doctor'),
      headers: _headers(token: token),
      body: jsonEncode({'doctor_id': doctorId}),
    );
    return _handleResponse(
      response,
      (d) => DoctorAssignment.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<List<PatientSearchResult>> getMyAssignedPatients({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/doctors/me/patients'),
      headers: _headers(token: token),
    );
    final data = _handleResponse(response, (d) => d);
    return data is List
        ? data
              .cast<Map<String, dynamic>>()
              .map(PatientSearchResult.fromJson)
              .toList()
        : [];
  }

  Future<List<PendingReportItem>> getPendingReports({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/doctors/me/pending-reports'),
      headers: _headers(token: token),
    );
    final data = _handleResponse(response, (d) => d);
    return data is List
        ? data
              .cast<Map<String, dynamic>>()
              .map(PendingReportItem.fromJson)
              .toList()
        : [];
  }

  Future<void> finalizeReport(int reportId, {required String token}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reports/$reportId/finalize'),
      headers: _headers(token: token),
    );
    _handleResponse(response, (d) => d);
  }

  // ── Device Management ─────────────────────────────────────────────────

  Future<List<PatientDevice>> listPatientDevices(
    int patientId, {
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/patients/$patientId/devices'),
        headers: _headers(token: token),
      );
      final data = _handleResponse(response, (d) => d);
      if (data is List) {
        return data
            .cast<Map<String, dynamic>>()
            .map(PatientDevice.fromJson)
            .toList();
      }
      return [];
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _wrapException('Failed to load devices', e);
    }
  }

  Future<void> revokeDevice(int deviceId, {required String token}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/devices/$deviceId/revoke'),
        headers: _headers(token: token),
      );
      _handleResponse(response, (d) => d);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _wrapException('Failed to revoke device', e);
    }
  }

  Future<ActivationResult> createActivation(
    int patientId, {
    required String deviceIdentifier,
    int expiresInMinutes = 30,
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/patients/$patientId/activation'),
        headers: _headers(token: token),
        body: jsonEncode({
          'device_identifier': deviceIdentifier,
          'expires_in_minutes': expiresInMinutes,
        }),
      );
      final result = _handleResponse(
        response,
        (data) => ActivationResult.fromJson(data),
      );
      return result;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _wrapException('Failed to create activation', e);
    }
  }

  Future<ActivationResult?> getPatientActivation(
    int patientId, {
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/patients/$patientId/activation'),
        headers: _headers(token: token),
      );
      final data = _handleResponse(response, (d) => d);
      if (data is Map<String, dynamic> && data['has_activation'] == true) {
        return ActivationResult.fromJson(data);
      }
      return null;
    } on ApiException {
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Doctor — Clinical Data ────────────────────────────────────────────

  Future<List<ApiMedicalHistory>> getMedicalHistory(
    int patientId, {
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/patients/$patientId/medical-history'),
        headers: _headers(token: token),
      );
      final data = _handleResponse(response, (d) => d);
      if (data is List) {
        return data
            .cast<Map<String, dynamic>>()
            .map(ApiMedicalHistory.fromJson)
            .toList();
      }
      return [];
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to load medical history: ${e.toString()}');
    }
  }

  Future<List<ApiVisit>> getPatientVisits(
    int patientId, {
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/patients/$patientId/visits'),
        headers: _headers(token: token),
      );
      final data = _handleResponse(response, (d) => d);
      if (data is List) {
        return data
            .cast<Map<String, dynamic>>()
            .map(ApiVisit.fromJson)
            .toList();
      }
      return [];
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to load visits: ${e.toString()}');
    }
  }

  Future<List<ApiReport>> getPatientReports(
    int patientId, {
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/patients/$patientId/reports'),
        headers: _headers(token: token),
      );
      final data = _handleResponse(response, (d) => d);
      if (data is List) {
        return data
            .cast<Map<String, dynamic>>()
            .map(ApiReport.fromJson)
            .toList();
      }
      return [];
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to load reports: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getAdmissionOptions(
    int patientId, {
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/patients/$patientId/admission-options'),
        headers: _headers(token: token),
      );
      return await _handleResponse(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw _wrapException('Failed to load admission status', e);
    }
  }

  Future<Map<String, dynamic>> createPatientAdmission(
    int patientId, {
    required int visitId,
    required String wardType,
    required String token,
  }) async {
    try {
      final request =
          http.MultipartRequest(
              'POST',
              Uri.parse('$baseUrl/patients/$patientId/admission'),
            )
            ..headers['Authorization'] = 'Bearer $token'
            ..fields['visit_id'] = '$visitId'
            ..fields['ward_type'] = wardType;
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return await _handleResponse(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw _wrapException('Failed to admit patient', e);
    }
  }

  Future<Map<String, dynamic>> getDischargeSummary(
    int patientId, {
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/patients/$patientId/discharge-summary'),
        headers: _headers(token: token),
      );
      return await _handleResponse(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw _wrapException('Failed to load discharge summary', e);
    }
  }

  Future<ApiVisit> createVisit(
    int patientId, {
    String? visitType,
    String? reason,
    String? notes,
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/patients/$patientId/visits'),
        headers: _headers(token: token),
        body: jsonEncode({
          if (visitType != null) 'visit_type': visitType,
          if (reason != null) 'reason': reason,
          if (notes != null) 'notes': notes,
        }),
      );
      final data = _handleResponse(response, (d) => d);
      return ApiVisit(
        visitId: data['visit_id'] as int,
        patientId: data['patient_id'] as int,
        doctorId: data['doctor_id'] as int?,
        visitType: visitType ?? 'consultation',
        status: 'completed',
        reason: reason,
        notes: notes,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to create visit: ${e.toString()}');
    }
  }

  Future<void> createReport(
    int patientId, {
    required int visitId,
    required String diagnosis,
    String? clinicalNotes,
    String? voiceTranscript,
    bool isFinal = true,
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/patients/$patientId/reports'),
        headers: _headers(token: token),
        body: jsonEncode({
          'visit_id': visitId,
          'diagnosis': diagnosis,
          if (clinicalNotes != null) 'clinical_notes': clinicalNotes,
          if (voiceTranscript != null) 'voice_transcript': voiceTranscript,
          'is_final': isFinal,
        }),
      );
      _handleResponse(response, (d) => d);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to create report: ${e.toString()}');
    }
  }

  // ── Shared response handler ───────────────────────────────────────────

  T _handleResponse<T>(http.Response response, T Function(dynamic) parser) {
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (e) {
      debugPrint('[_handleResponse] JSON decode failed: ${e.runtimeType}');
      throw ApiException(
        'Invalid server response format (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return parser(data);
      } catch (e) {
        debugPrint('[_handleResponse] Parser failed: ${e.runtimeType} — $e');
        rethrow;
      }
    } else {
      String errorMessage = '';
      if (data is Map<String, dynamic>) {
        if (data['detail'] != null) {
          final detail = data['detail'];
          if (detail is List) {
            errorMessage = detail
                .map((e) => (e['msg'] ?? e).toString())
                .join('; ');
          } else {
            errorMessage = detail.toString();
          }
        } else if (data['message'] != null) {
          errorMessage = data['message'].toString();
        } else if (data['error'] != null) {
          errorMessage = data['error'].toString();
        }
      }

      if (errorMessage.isEmpty) {
        switch (response.statusCode) {
          case 401:
            errorMessage =
                'Authentication failed. Please check your credentials.';
            break;
          case 403:
            errorMessage =
                'Access denied. You do not have permission for this action.';
            break;
          case 404:
            errorMessage = 'The requested resource was not found.';
            break;
          case 409:
            errorMessage = 'A conflict occurred with existing records.';
            break;
          case 422:
            errorMessage = 'Validation error: Please check highlighted fields.';
            break;
          case 500:
            errorMessage = 'Server error. Please try again later.';
            break;
          default:
            errorMessage =
                'Request failed with HTTP status ${response.statusCode}.';
        }
      }

      debugPrint(
        '[_handleResponse] HTTP ${response.statusCode}: $errorMessage',
      );
      throw ApiException(errorMessage, statusCode: response.statusCode);
    }
  }

  /// Wraps a non-[ApiException] into an [ApiException] with a web-compatible
  /// message, inspecting the error string to distinguish network issues from
  /// other failures. Replaces the previous `on SocketException` /
  /// `on http.ClientException` pattern that required dart:io.
  ApiException _wrapException(String context, Object error) {
    debugPrint('[ApiClient] $context — ${error.runtimeType}: $error');
    final msg = error.toString().toLowerCase();
    if (msg.contains('socketexception') ||
        msg.contains('connection refused') ||
        msg.contains('network is unreachable') ||
        msg.contains('no route to host') ||
        msg.contains('failed host lookup')) {
      return ApiException(
        'Network is unreachable. Please check your connection.',
      );
    }
    if (msg.contains('clientexception') ||
        msg.contains('connection closed') ||
        msg.contains('xmlhttprequest error')) {
      return ApiException(
        'Unable to connect to the server. Is the backend running at $baseUrl?',
      );
    }
    return ApiException('$context: ${error.runtimeType}');
  }

  // ── Dashboard Stats ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/stats'),
        headers: _headers(token: token),
      );
      final data = _handleResponse(response, (d) => d);
      return data as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _wrapException('Failed to load dashboard stats', e);
    }
  }

  // ── Admin Staff Management ───────────────────────────────────────────

  Future<List<StaffMember>> getStaffList(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/staff'),
        headers: _headers(token: token),
      );
      final data = _handleResponse(response, (d) => d);
      if (data is List) {
        return data
            .cast<Map<String, dynamic>>()
            .map(StaffMember.fromJson)
            .toList();
      }
      return [];
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _wrapException('Failed to load staff list', e);
    }
  }

  Future<void> createStaff({
    required String username,
    required String password,
    required String role,
    required String name,
    String? department,
    String? specialization,
    String? phone,
    String? email,
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/staff'),
        headers: _headers(token: token),
        body: jsonEncode({
          'username': username,
          'password': password,
          'role': role,
          'name': name,
          if (department != null && department.isNotEmpty)
            'department': department,
          if (specialization != null && specialization.isNotEmpty)
            'specialization': specialization,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (email != null && email.isNotEmpty) 'email': email,
        }),
      );
      _handleResponse(response, (d) => d);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _wrapException('Failed to create staff', e);
    }
  }

  Future<void> updateStaff(
    int staffId, {
    required String name,
    String? department,
    String? specialization,
    String? phone,
    String? email,
    String? role,
    required String token,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/staff/$staffId'),
        headers: _headers(token: token),
        body: jsonEncode({
          'name': name,
          if (department != null) 'department': department,
          if (specialization != null) 'specialization': specialization,
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
          if (role != null) 'role': role,
        }),
      );
      _handleResponse(response, (d) => d);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _wrapException('Failed to update staff member', e);
    }
  }

  Future<Map<String, dynamic>> getAdherence(
    int patientId, {
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/patients/$patientId/adherence'),
        headers: _headers(token: token),
      );
      final res = _handleResponse(response, (d) => d as Map<String, dynamic>);
      return res;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _wrapException('Failed to fetch patient adherence', e);
    }
  }

  Future<void> updateStaffStatus(
    int staffId, {
    required bool active,
    required String token,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/staff/$staffId/status'),
        headers: _headers(token: token),
        body: jsonEncode({'active': active}),
      );
      _handleResponse(response, (d) => d);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _wrapException('Failed to update staff status', e);
    }
  }

  Future<void> updateStaffPassword(
    int staffId, {
    required String newPassword,
    required String token,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/staff/$staffId/password'),
        headers: _headers(token: token),
        body: jsonEncode({'new_password': newPassword}),
      );
      _handleResponse(response, (d) => d);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _wrapException('Failed to update password', e);
    }
  }

  Future<void> deleteStaff(int staffId, {required String token}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/staff/$staffId'),
        headers: _headers(token: token),
      );
      _handleResponse(response, (d) => d);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _wrapException('Failed to delete staff member', e);
    }
  }

  Future<void> deletePatient(int patientId, {required String token}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/patients/$patientId'),
        headers: _headers(token: token),
      );
      _handleResponse(response, (d) => d);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _wrapException('Failed to delete patient', e);
    }
  }

  // ── Unified Consultation Transaction ───────────────────────────────

  Future<Map<String, dynamic>> createConsultation(
    int patientId, {
    String? visitType,
    String? admissionStatus = 'not_admitted',
    String? dischargeStatus,
    int? assignedDoctorId,
    String? reason,
    String? notes,
    String? temperature,
    String? bloodPressure,
    String? pulse,
    String? spo2,
    String? weight,
    String? height,
    required String diagnosis,
    String? clinicalNotes,
    String? voiceTranscript,
    bool isFinal = true,
    required List<PrescriptionItemInput> medicines,
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/patients/$patientId/consultations'),
        headers: _headers(token: token),
        body: jsonEncode({
          'visit_type': visitType,
          if (admissionStatus != null) 'admission_status': admissionStatus,
          if (dischargeStatus != null) 'discharge_status': dischargeStatus,
          'assigned_doctor_id': assignedDoctorId,
          'reason': reason,
          'notes': notes,
          'temperature': temperature,
          'blood_pressure': bloodPressure,
          'pulse': pulse,
          'spo2': spo2,
          'weight': weight,
          'height': height,
          'diagnosis': diagnosis,
          'clinical_notes': clinicalNotes,
          'voice_transcript': voiceTranscript,
          'is_final': isFinal,
          'medicines': medicines.map((m) => m.toJson()).toList(),
        }),
      );
      final data = _handleResponse(response, (d) => d);
      return data as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to save consultation: ${e.toString()}');
    }
  }

  Future<List<MedicineCatalogueItem>> searchMedicines(
    String query, {
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/medicines?search=${Uri.encodeQueryComponent(query)}',
        ),
        headers: _headers(token: token),
      );
      final data = _handleResponse(response, (d) => d);
      return (data as List)
          .cast<Map<String, dynamic>>()
          .map(MedicineCatalogueItem.fromJson)
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw _wrapException('Failed to search medicine catalogue', e);
    }
  }

  Future<Map<String, dynamic>> extractVoiceConsultation(
    String transcript, {
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/consultations/voice-extraction'),
        headers: _headers(token: token),
        body: jsonEncode({'transcript': transcript}),
      );
      final res = _handleResponse(response, (d) => d as Map<String, dynamic>);
      return res;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw _wrapException('Failed to process voice dictation', e);
    }
  }

  Future<Map<String, dynamic>> createAppointment(
    int patientId, {
    required String appointmentDatetime,
    String? reason,
    String? notes,
    int? doctorId,
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/patients/$patientId/appointments'),
        headers: _headers(token: token),
        body: jsonEncode({
          'appointment_datetime': appointmentDatetime,
          if (reason != null) 'reason': reason,
          if (notes != null) 'notes': notes,
          if (doctorId != null) 'doctor_id': doctorId,
        }),
      );
      final res = _handleResponse(response, (d) => d as Map<String, dynamic>);
      return res;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw _wrapException('Failed to schedule appointment', e);
    }
  }

  Future<List<PortalAppointment>> getPatientAppointments(
    int patientId, {
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/patients/$patientId/appointments'),
        headers: _headers(token: token),
      );
      final res = _handleResponse(
        response,
        (d) => (d as List).cast<Map<String, dynamic>>(),
      );
      return res.map(PortalAppointment.fromJson).toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw _wrapException('Failed to fetch patient appointments', e);
    }
  }

  Future<void> decideRescheduleRequest(
    int requestId, {
    required bool approve,
    required String token,
  }) async {
    try {
      final action = approve ? 'approve' : 'reject';
      final response = await http.patch(
        Uri.parse(
          '$baseUrl/appointment-reschedule-requests/$requestId/$action',
        ),
        headers: _headers(token: token),
      );
      _handleResponse(response, (d) => d as Map<String, dynamic>);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw _wrapException('Failed to update reschedule request', e);
    }
  }
}

class AppointmentRescheduleInfo {
  const AppointmentRescheduleInfo({
    required this.requestId,
    required this.status,
    required this.preferredDatetime,
    this.reason,
  });

  final int requestId;
  final String status;
  final DateTime preferredDatetime;
  final String? reason;

  factory AppointmentRescheduleInfo.fromJson(Map<String, dynamic> json) =>
      AppointmentRescheduleInfo(
        requestId: (json['request_id'] as num).toInt(),
        status: json['status']?.toString() ?? 'pending',
        preferredDatetime:
            DateTime.tryParse(json['preferred_datetime']?.toString() ?? '') ??
            DateTime.now(),
        reason: json['reason']?.toString(),
      );
}

class PortalAppointment {
  const PortalAppointment({
    required this.appointmentId,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.appointmentDatetime,
    required this.status,
    this.reason,
    this.notes,
    this.cancelledBy,
    this.rescheduleRequest,
  });

  final int appointmentId;
  final int patientId;
  final String patientName;
  final int doctorId;
  final String doctorName;
  final DateTime appointmentDatetime;
  final String status;
  final String? reason;
  final String? notes;
  final String? cancelledBy;
  final AppointmentRescheduleInfo? rescheduleRequest;

  factory PortalAppointment.fromJson(Map<String, dynamic> json) {
    final request = json['reschedule_request'];
    return PortalAppointment(
      appointmentId: (json['appointment_id'] as num).toInt(),
      patientId: (json['patient_id'] as num).toInt(),
      patientName: json['patient_name']?.toString() ?? 'Patient',
      doctorId: (json['doctor_id'] as num).toInt(),
      doctorName: json['doctor_name']?.toString() ?? 'Doctor',
      appointmentDatetime:
          DateTime.tryParse(json['appointment_datetime']?.toString() ?? '') ??
          DateTime.now(),
      status: json['status']?.toString() ?? 'scheduled',
      reason: json['reason']?.toString(),
      notes: json['notes']?.toString(),
      cancelledBy: json['cancelled_by']?.toString(),
      rescheduleRequest: request is Map
          ? AppointmentRescheduleInfo.fromJson(
              Map<String, dynamic>.from(request),
            )
          : null,
    );
  }
}

class MedicineCatalogueItem {
  final int medicineId;
  final String name;
  final String? genericName;
  final String? medicineType;
  final String? strength;
  const MedicineCatalogueItem({
    required this.medicineId,
    required this.name,
    this.genericName,
    this.medicineType,
    this.strength,
  });
  factory MedicineCatalogueItem.fromJson(Map<String, dynamic> json) =>
      MedicineCatalogueItem(
        medicineId: json['medicine_id'] as int,
        name: json['name'] as String,
        genericName: json['generic_name'] as String?,
        medicineType: json['medicine_type'] as String?,
        strength: json['strength'] as String?,
      );
}

class StaffMember {
  final int staffId;
  final int userId;
  final String username;
  final String role;
  final String name;
  final String? department;
  final String? specialization;
  final String? phone;
  final String? email;
  final bool active;

  StaffMember({
    required this.staffId,
    required this.userId,
    required this.username,
    required this.role,
    required this.name,
    this.department,
    this.specialization,
    this.phone,
    this.email,
    required this.active,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      staffId: json['staff_id'] as int,
      userId: json['user_id'] as int,
      username: json['username'] as String,
      role: json['role'] as String,
      name: json['name'] as String,
      department: json['department'] as String?,
      specialization: json['specialization'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      active: json['active'] as bool,
    );
  }
}

class PrescriptionItemInput {
  final int medicineId;
  final String medicineName;
  final String? genericName;
  final String? medicineType;
  final String? strength;
  final String? dosage;
  final String? frequency;
  final String? duration;
  final String? instructions;
  final String? route;
  final String? foodTiming;
  final String? startDate;
  final String? endDate;
  final List<String> reminderTimes;

  PrescriptionItemInput({
    this.medicineId = 0,
    required this.medicineName,
    this.genericName,
    this.medicineType,
    this.strength,
    this.dosage,
    this.frequency,
    this.duration,
    this.instructions,
    this.route,
    this.foodTiming,
    this.startDate,
    this.endDate,
    this.reminderTimes = const [],
  });

  Map<String, dynamic> toJson() => {
    if (medicineId > 0) 'medicine_id': medicineId,
    'medicine_name': medicineName,
    if (genericName != null && genericName!.isNotEmpty)
      'generic_name': genericName,
    if (medicineType != null && medicineType!.isNotEmpty)
      'medicine_type': medicineType,
    if (strength != null && strength!.isNotEmpty) 'strength': strength,
    'dosage': (dosage != null && dosage!.trim().isNotEmpty)
        ? dosage!.trim()
        : '1 tablet',
    'frequency': (frequency != null && frequency!.trim().isNotEmpty)
        ? frequency!.trim()
        : 'Once daily',
    'duration': (duration != null && duration!.trim().isNotEmpty)
        ? duration!.trim()
        : '5 days',
    if (instructions != null && instructions!.isNotEmpty)
      'instructions': instructions,
    if (route != null && route!.isNotEmpty) 'route': route,
    if (foodTiming != null && foodTiming!.isNotEmpty) 'food_timing': foodTiming,
    if (startDate != null && startDate!.isNotEmpty) 'start_date': startDate,
    if (endDate != null && endDate!.isNotEmpty) 'end_date': endDate,
    if (reminderTimes.isNotEmpty) 'reminder_times': reminderTimes,
  };
}

class PendingReportItem {
  final int reportId;
  final int patientId;
  final String patientName;
  final String registrationNo;
  final int visitId;
  final String diagnosis;
  final String? clinicalNotes;
  final String? reportDatetime;
  final bool isFinal;

  PendingReportItem({
    required this.reportId,
    required this.patientId,
    required this.patientName,
    required this.registrationNo,
    required this.visitId,
    required this.diagnosis,
    this.clinicalNotes,
    this.reportDatetime,
    required this.isFinal,
  });

  factory PendingReportItem.fromJson(Map<String, dynamic> json) {
    return PendingReportItem(
      reportId: json['report_id'] as int,
      patientId: json['patient_id'] as int,
      patientName: json['patient_name'] as String? ?? 'Patient',
      registrationNo: json['registration_no'] as String? ?? '',
      visitId: json['visit_id'] as int,
      diagnosis: json['diagnosis'] as String? ?? '',
      clinicalNotes: json['clinical_notes'] as String?,
      reportDatetime: json['report_datetime'] as String?,
      isFinal: json['is_final'] as bool? ?? false,
    );
  }
}
