import 'dart:math';
import 'api_client.dart';
import 'models/doctor_models.dart';

/// A mock implementation of the API client for demo purposes.
/// Returns realistic fake data without needing a running backend.
class MockApiClient {
  final String baseUrl;

  MockApiClient({this.baseUrl = 'http://mock'});

  // Shared in-memory patient list — registerPatient() appends to this,
  // searchPatients() reads from it, so newly registered patients are
  // immediately findable within the same app session.
  final List<PatientSearchResult> _patients = [
    PatientSearchResult(
      patientId: 1,
      registrationNo: 'MA-2026-000001',
      name: 'Rahul Verma',
      dateOfBirth: '1985-03-15',
      diseaseCondition: 'Type 2 Diabetes',
      preferredLanguage: 'Hindi',
    ),
    PatientSearchResult(
      patientId: 2,
      registrationNo: 'MA-2026-000002',
      name: 'Priya Sharma',
      dateOfBirth: '1992-07-22',
      diseaseCondition: 'Hypertension',
      preferredLanguage: 'English',
    ),
    PatientSearchResult(
      patientId: 3,
      registrationNo: 'MA-2026-000003',
      name: 'Amit Kumar Singh',
      dateOfBirth: '1978-11-04',
      diseaseCondition: 'Asthma',
      preferredLanguage: 'Hindi',
    ),
    PatientSearchResult(
      patientId: 4,
      registrationNo: 'MA-2026-000004',
      name: 'Sneha Patel',
      dateOfBirth: '2000-01-30',
      diseaseCondition: 'Migraine',
      preferredLanguage: 'Gujarati',
    ),
    PatientSearchResult(
      patientId: 5,
      registrationNo: 'MA-2026-000005',
      name: 'Rajesh Gupta',
      dateOfBirth: '1965-09-12',
      diseaseCondition: 'Arthritis',
      preferredLanguage: 'English',
    ),
  ];

  // ── Authentication ──────────────────────────────────────────────────────

  Future<LoginResponse> login(String username, String password) async {
    await Future.delayed(const Duration(milliseconds: 100));

    final trimmedUser = username.trim();
    if (trimmedUser.isEmpty || password.isEmpty) {
      throw ApiException('Invalid credentials', statusCode: 401);
    }

    final lowerUser = trimmedUser.toLowerCase();
    String role = 'receptionist';
    int id = 3;
    if (lowerUser.contains('doctor')) {
      role = 'doctor';
      id = 2;
    } else if (lowerUser.contains('admin')) {
      role = 'admin';
      id = 1;
    }

    return LoginResponse(
      accessToken: 'mock_token_${lowerUser}_${DateTime.now().millisecondsSinceEpoch}',
      staff: StaffInfo(id: id, username: trimmedUser, role: role),
    );
  }

  // ── Patient Registration (mock — returns demo QR/activation data) ───────

  Future<RegisterPatientResponse> registerPatient({
    required String name,
    String? dateOfBirth,
    String? diseaseCondition,
    String preferredLanguage = 'English',
    String? emergencyContact,
    int? assignedDoctorId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    final uid = 'PT-${DateTime.now().millisecondsSinceEpoch}';
    final code =
        '${1000 + Random().nextInt(9000)}-${1000 + Random().nextInt(9000)}';

    // Give the new patient its own registration number, following the
    // same MA-YYYY-###### pattern the real backend uses, so it looks
    // consistent with the seeded demo patients above.
    final nextNumber = _patients.length + 1;
    final registrationNo =
        'MA-${DateTime.now().year}-${nextNumber.toString().padLeft(6, '0')}';

    _patients.add(
      PatientSearchResult(
        patientId: nextNumber,
        registrationNo: registrationNo,
        name: name,
        dateOfBirth: dateOfBirth,
        diseaseCondition: diseaseCondition,
        preferredLanguage: preferredLanguage,
      ),
    );

    final qrPayload = 'saathi://activate?uid=$uid&code=$code';

    _activationDataByPatient[registrationNo] = {
      'uid': uid,
      'code': code,
      'qrPayload': qrPayload,
    };

    return RegisterPatientResponse(
      isMock: true,
      patient: PatientInfo(
        fullName: name,
        dateOfBirth: dateOfBirth,
        diseaseCondition: diseaseCondition,
        preferredLanguage: preferredLanguage,
        emergencyContact: emergencyContact,
      ),
      patientId: nextNumber,
      registrationNo: registrationNo,
      patientUid: uid,
      activationCode: code,
      qrPayload: qrPayload,
    );
  }

  // ── Patient Search (mock — reads from the shared in-memory list) ────────

  Future<List<PatientSearchResult>> searchPatients(String query) async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (query.trim().isEmpty) {
      return List.unmodifiable(_patients.reversed);
    }

    final lowerQuery = query.trim().toLowerCase();
    return _patients.reversed.where((p) {
      return p.name.toLowerCase().contains(lowerQuery) ||
          p.registrationNo.toLowerCase().contains(lowerQuery) ||
          (p.diseaseCondition?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  // ── Device Management (mock — fake devices per patient registration_no) ─

  // Keyed by patient registrationNo, so each patient keeps its own devices
  // across calls within the same app session.
  final Map<String, List<PatientDevice>> _devicesByPatient = {
    'MA-2026-000001': [
      PatientDevice(
        deviceId: 1,
        patientId: 1,
        deviceIdentifier: "Rahul's Phone (Redmi Note 12)",
        status: 'active',
        linkedAt: DateTime.now().subtract(const Duration(days: 14)),
        revokedAt: null,
      ),
    ],
    'MA-2026-000002': [
      PatientDevice(
        deviceId: 2,
        patientId: 2,
        deviceIdentifier: "Priya's Phone (iPhone 13)",
        status: 'active',
        linkedAt: DateTime.now().subtract(const Duration(days: 30)),
        revokedAt: null,
      ),
    ],
    'MA-2026-000003': [], // no devices linked yet — exercises the empty state
  };

  Future<List<PatientDevice>> listPatientDevices(String patientUid) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _devicesByPatient[patientUid] ?? [];
  }

  Future<bool> revokeDevice(String patientUid, int deviceId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _devicesByPatient[patientUid]
        ?.removeWhere((d) => d.deviceId == deviceId);
    return true;
  }

  final Map<String, Map<String, String>> _activationDataByPatient = {
    'MA-2026-000003': {
      'uid': 'PT-1700000000003',
      'code': '4821-9923',
      'qrPayload': '{"patient_id": 3, "device_identifier": "Patient Primary Device", "activation_code": "4821-9923"}',
    },
  };

  Future<Map<String, String>?> getPatientActivation(String registrationNo) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _activationDataByPatient[registrationNo];
  }

  // ── Dashboard Data (fixed realistic mock values for Phase 1) ─────────────

  Future<Map<String, dynamic>> getDashboardStats() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'totalPatients': 142,
      'activeDevices': 98,
      'registeredToday': 5,
      'pendingSetup': 3,
    };
  }

  Future<List<PatientSearchResult>> getRecentPatients() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_patients.reversed.take(5));
  }

  // ── Doctor Portal Data (deterministic mock values) ───────────────────────

  Future<Map<String, dynamic>> getDoctorDashboardStats() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'myPatients': 28,
      'todayVisits': 6,
      'pendingReports': 3,
      'recentPatients': 5,
    };
  }

  Future<List<PatientSearchResult>> getDoctorRecentPatients() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_patients.take(5));
  }

  final Map<String, List<MockMedicalHistoryEntry>> _patientHistoryStore = {};

  Future<List<MockMedicalHistoryEntry>> getPatientMedicalHistory(String registrationNo) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_patientHistoryStore.containsKey(registrationNo)) {
      return List.of(_patientHistoryStore[registrationNo]!);
    }

    final initialList = [
      const MockMedicalHistoryEntry(
        date: '12 Aug 2026',
        title: 'Routine follow-up',
        description: 'Patient reported stable vitals and good adherence to daily routine.',
        status: 'Completed',
      ),
      const MockMedicalHistoryEntry(
        date: '05 Jun 2026',
        title: 'Medication review',
        description: 'Periodic review of prescribed care regimen. Tolerance noted as good.',
        status: 'Completed',
      ),
      const MockMedicalHistoryEntry(
        date: '12 Mar 2026',
        title: 'Initial consultation',
        description: 'Comprehensive health baseline recorded upon hospital enrollment.',
        status: 'Completed',
      ),
    ];

    _patientHistoryStore[registrationNo] = List.of(initialList);
    return List.of(initialList);
  }

  void addPatientMedicalHistoryEntry(String registrationNo, MockMedicalHistoryEntry entry) {
    if (!_patientHistoryStore.containsKey(registrationNo)) {
      _patientHistoryStore[registrationNo] = [];
    }
    _patientHistoryStore[registrationNo]!.insert(0, entry);
  }

  Future<List<MockVisit>> getPatientVisits(String registrationNo) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      const MockVisit(
        date: '15 August 2026',
        visitType: 'Routine consultation',
        doctorName: 'Dr. Sharma',
        status: 'Completed',
        notes: 'General checkup completed. Vitals within expected normal ranges.',
      ),
      const MockVisit(
        date: '08 August 2026',
        visitType: 'Follow-up consultation',
        doctorName: 'Dr. Sharma',
        status: 'Completed',
        notes: 'Reviewed symptom diary. Recommended continuing standard activity plan.',
      ),
      const MockVisit(
        date: '20 July 2026',
        visitType: 'Clinical Assessment',
        doctorName: 'Dr. Sharma',
        status: 'Completed',
        notes: 'Baseline check and physiological monitoring review.',
      ),
    ];
  }

  Future<List<MockReport>> getPatientReports(String registrationNo) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      const MockReport(
        id: 'rep-001',
        title: 'Blood Test Panel',
        date: '12 August 2026',
        reportType: 'Laboratory Test',
        summary: 'Standard diagnostic metabolic profile and routine blood analysis.',
      ),
      const MockReport(
        id: 'rep-002',
        title: 'Clinical Summary Report',
        date: '05 August 2026',
        reportType: 'Clinical Examination',
        summary: 'Periodic health evaluation summary and physiological baseline recording.',
      ),
      const MockReport(
        id: 'rep-003',
        title: 'Vital Signs Trend Assessment',
        date: '20 July 2026',
        reportType: 'Diagnostic Review',
        summary: 'Monthly consolidated vital readings and observation notes.',
      ),
    ];
  }

  Future<void> updateStaffPassword(
    int staffId, {
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }
}