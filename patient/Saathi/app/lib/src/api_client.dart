import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

String normalizeApiBaseUrl(String value) =>
    value.trim().replaceFirst(RegExp(r'/+$'), '');

/// Talks to the shared FastAPI backend on behalf of the patient app.
class ApiClient {
  ApiClient({http.Client? client})
    : _client = _TimedClient(client ?? http.Client());

  final http.Client _client;

  Future<Map<String, dynamic>> summarizeDischargeDocument({
    required String token,
    required String fileName,
    required List<int> bytes,
  }) async {
    final extension = fileName.split('.').last.toLowerCase();
    final mediaType = switch (extension) {
      'pdf' => MediaType('application', 'pdf'),
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'png' => MediaType('image', 'png'),
      _ => throw const ApiException('Choose a PDF, JPG, or PNG document'),
    };
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/patients/me/discharge-summary'),
    )..headers.addAll({'Authorization': 'Bearer $token'});
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: mediaType,
      ),
    );
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);
    return _object(response);
  }

  Future<Map<String, dynamic>> saveDischargeReport({
    required String token,
    required Map<String, dynamic> report,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/patients/me/discharge-reports'),
      headers: _headers(token: token),
      body: jsonEncode(report),
    );
    return _object(response);
  }

  Future<List<Map<String, dynamic>>> getDischargeReports(String token) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/patients/me/discharge-reports'),
      headers: _headers(token: token),
    );
    return _list(
      response,
    ).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<Map<String, dynamic>> askDischargeQuestion({
    required String token,
    required int reportId,
    required String question,
    required String language,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/patients/me/discharge-chat'),
      headers: _headers(token: token),
      body: jsonEncode({
        'report_id': reportId,
        'question': question,
        'language': language,
      }),
    );
    return _object(response);
  }

  static String get baseUrl {
    const configured = String.fromEnvironment(
      'API_URL',
      defaultValue: 'https://saathi-api-v2-x5at.onrender.com',
    );
    return normalizeApiBaseUrl(configured);
  }

  Map<String, String> _headers({String? token}) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  /// Parses a non-2xx response or throws [ApiException].
  Map<String, dynamic> _object(http.Response response) {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        body['detail']?.toString() ?? 'Something went wrong',
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  /// Parses a list response, throwing [ApiException] on non-2xx.
  List<dynamic> _list(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        body['detail']?.toString() ?? 'Something went wrong',
        statusCode: response.statusCode,
      );
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  /// GET /patients/{patient_id} with Bearer token
  Future<Patient> patientMe(String token, int patientId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/patients/$patientId'),
      headers: _headers(token: token),
    );
    return Patient.fromJson(_object(response));
  }

  /// POST /patient/devices/activate
  /// Returns (access_token, patient_id)
  Future<(String, int)> linkPatient({
    int? patientId,
    String? registrationNo,
    required String deviceIdentifier,
    required String activationCode,
  }) async {
    final payload = <String, dynamic>{
      ...?(patientId == null ? null : {'patient_id': patientId}),
      ...?(registrationNo == null || registrationNo.isEmpty
          ? null
          : {'registration_no': registrationNo}),
      'device_identifier': deviceIdentifier.trim(),
      'activation_code': activationCode.trim(),
    };
    final response = await _client.post(
      Uri.parse('$baseUrl/patient/devices/activate'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    final json = _object(response);
    final user = json['user'] as Map<String, dynamic>?;
    final returnedPatientId = (user?['patient_id'] as int?) ?? (patientId ?? 0);
    final token = json['access_token'] as String;
    return (token, returnedPatientId);
  }

  /// GET /patients/{patient_id}/visits — flat list of visits (no prescriptions)
  Future<List<PatientVisit>> getVisits(String token, int patientId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/patients/$patientId/visits'),
      headers: _headers(token: token),
    );
    return _list(
      response,
    ).cast<Map<String, dynamic>>().map(PatientVisit.fromJson).toList();
  }

  /// GET /patients/me/health-summary — identity comes solely from the token.
  Future<HealthSummary> getHealthSummary(String token) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/patients/me/health-summary'),
      headers: _headers(token: token),
    );
    return HealthSummary.fromJson(_object(response));
  }

  Future<VitalHistoryPage> getVitalsHistory(
    String token, {
    int limit = 10,
    int offset = 0,
    int days = 0,
    bool oldest = false,
  }) async {
    final response = await _client.get(
      Uri.parse(
        '$baseUrl/patients/me/vitals-history?limit=$limit&offset=$offset&days=$days&sort=${oldest ? 'asc' : 'desc'}',
      ),
      headers: _headers(token: token),
    );
    return VitalHistoryPage.fromJson(_object(response));
  }

  /// GET /patients/{patient_id}/reports — flat list of reports
  Future<List<PatientReport>> getReports(String token, int patientId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/patients/$patientId/reports'),
      headers: _headers(token: token),
    );
    return _list(
      response,
    ).cast<Map<String, dynamic>>().map(PatientReport.fromJson).toList();
  }

  /// GET /patients/{patient_id}/medical-history
  Future<List<PatientMedicalHistory>> getMedicalHistory(
    String token,
    int patientId,
  ) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/patients/$patientId/medical-history'),
      headers: _headers(token: token),
    );
    return _list(
      response,
    ).cast<Map<String, dynamic>>().map(PatientMedicalHistory.fromJson).toList();
  }

  /// GET /patients/{patient_id}/clinical-records
  ///
  /// Returns nested visits → vitals → report → prescription → items.
  /// This is the primary patient read endpoint; authorization is enforced
  /// server-side — a patient token only resolves their own patient_id.
  Future<List<ClinicalVisit>> getClinicalRecords(
    String token,
    int patientId,
  ) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/patients/$patientId/clinical-records'),
      headers: _headers(token: token),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        body['detail']?.toString() ?? 'Unable to load clinical records',
        statusCode: response.statusCode,
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ((body['visits'] as List?) ?? [])
        .whereType<Map>()
        .map((item) => ClinicalVisit.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// POST /patients/{patient_id}/adherence
  Future<Map<String, dynamic>> recordAdherence(
    String token,
    int patientId, {
    required int prescriptionItemId,
    required String scheduledDate,
    required String timeSlot,
    required String status,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/patients/$patientId/adherence'),
      headers: _headers(token: token),
      body: jsonEncode({
        'prescription_item_id': prescriptionItemId,
        'scheduled_date': scheduledDate,
        'time_slot': timeSlot,
        'status': status,
      }),
    );
    return _object(response);
  }

  /// GET /patients/{patient_id}/adherence
  Future<Map<String, dynamic>> getAdherence(String token, int patientId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/patients/$patientId/adherence'),
      headers: _headers(token: token),
    );
    return _object(response);
  }

  /// GET /patients/{patient_id}/appointments/next
  Future<PatientAppointment?> getNextAppointment(
    String token,
    int patientId,
  ) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/patients/$patientId/appointments/next'),
      headers: _headers(token: token),
    );
    final map = _object(response);
    if (map['has_appointment'] == true && map['appointment'] is Map) {
      return PatientAppointment.fromJson(
        Map<String, dynamic>.from(map['appointment'] as Map),
      );
    }
    return null;
  }

  Future<void> cancelAppointment(String token, int appointmentId) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/patients/me/appointments/$appointmentId/cancel'),
      headers: _headers(token: token),
    );
    _object(response);
  }

  Future<void> requestAppointmentReschedule(
    String token,
    int appointmentId,
    DateTime preferred,
    String? reason,
  ) async {
    final response = await _client.post(
      Uri.parse(
        '$baseUrl/patients/me/appointments/$appointmentId/reschedule-request',
      ),
      headers: _headers(token: token),
      body: jsonEncode({
        'preferred_datetime': preferred.toIso8601String(),
        if (reason?.trim().isNotEmpty == true) 'reason': reason!.trim(),
      }),
    );
    _object(response);
  }
}

class _TimedClient extends http.BaseClient {
  _TimedClient(this._inner);
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final limit = request is http.MultipartRequest
        ? const Duration(seconds: 60)
        : const Duration(seconds: 15);
    try {
      final response = await _inner.send(request).timeout(limit);
      return http.StreamedResponse(
        response.stream.timeout(limit),
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Please retry.',
      );
    }
  }
}
