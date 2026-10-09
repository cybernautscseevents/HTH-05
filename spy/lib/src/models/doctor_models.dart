// Mock models — still used by MockApiClient for demo mode.

class MockMedicalHistoryEntry {
  final String date;
  final String title;
  final String description;
  final String status;

  const MockMedicalHistoryEntry({
    required this.date,
    required this.title,
    required this.description,
    this.status = 'Completed',
  });
}

class MockVisit {
  final int? visitId;
  final String date;
  final String visitType;
  final String admissionStatus;
  final String? dischargeStatus;
  final String? assignedDoctorName;
  final String doctorName;
  final String status;
  final String? reason;
  final String? notes;
  final String? temperature;
  final String? bloodPressure;
  final String? pulse;
  final String? spo2;
  final String? weight;
  final String? height;

  const MockVisit({
    this.visitId,
    required this.date,
    required this.visitType,
    this.admissionStatus = 'Not admitted',
    this.dischargeStatus,
    this.assignedDoctorName,
    required this.doctorName,
    this.status = 'Completed',
    this.reason,
    this.notes,
    this.temperature,
    this.bloodPressure,
    this.pulse,
    this.spo2,
    this.weight,
    this.height,
  });
}

class MockReport {
  final String id;
  final int? visitId;
  final String title;
  final String date;
  final String reportType;
  final String summary;
  final String? diagnosis;
  final String? clinicalNotes;
  final String? voiceTranscript;
  final int versionNo;
  final bool isFinal;

  const MockReport({
    required this.id,
    this.visitId,
    required this.title,
    required this.date,
    required this.reportType,
    required this.summary,
    this.diagnosis,
    this.clinicalNotes,
    this.voiceTranscript,
    this.versionNo = 1,
    this.isFinal = true,
  });
}
