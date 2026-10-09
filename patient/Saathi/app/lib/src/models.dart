// Re-exports package:characters, used by Patient.initial below for
// grapheme-safe handling of Indic-script names.
import 'package:flutter/widgets.dart';

class Patient {
  const Patient({
    required this.id,
    required this.uid,
    required this.name,
    this.dateOfBirth,
    int? age,
    required this.condition,
    this.phone,
    this.photoUrl,
    this.preferredLanguage,
    this.registrationDate,
    this.registeredBy,
    this.receptionistName,
    this.currentMedicines,
  }) : _explicitAge = age;

  /// Internal integer ID matching FastAPI `patient_id`
  final int id;

  /// Patient registration number matching FastAPI `registration_no` (e.g. MA-2026-000001)
  final String uid;

  /// Patient full name matching FastAPI `name`
  final String name;

  /// Date of birth matching FastAPI `date_of_birth`
  final DateTime? dateOfBirth;

  final int? _explicitAge;

  /// Calculated from `dateOfBirth` if not explicitly passed
  int get age {
    final explicit = _explicitAge;
    if (explicit != null) return explicit;
    final dob = dateOfBirth;
    if (dob != null) {
      final now = DateTime.now();
      int calculated = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        calculated--;
      }
      return calculated >= 0 ? calculated : 0;
    }
    return 0;
  }

  /// Patient condition matching FastAPI `disease_condition`
  final String condition;

  /// Emergency contact matching FastAPI `emergency_contact`
  final String? phone;

  /// Photo URL matching FastAPI `photo_url`
  final String? photoUrl;

  /// Preferred language matching FastAPI `preferred_language`
  final String? preferredLanguage;

  /// Registration timestamp matching FastAPI `registration_date`
  final DateTime? registrationDate;

  /// Staff ID who registered this patient matching FastAPI `registered_by`
  final int? registeredBy;

  /// Name of the receptionist or staff who registered the patient
  final String? receptionistName;

  /// Clinical medicine summary (optional / placeholder)
  final String? currentMedicines;

  /// Single character for the avatar badge on the patient home screen.
  String get initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      try {
        return DateTime.parse(value.trim());
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  factory Patient.fromJson(Map<String, dynamic> json) {
    // If backend returns wrapped {"success": true, "patient": {...}}, unwrap it
    final data =
        json.containsKey('patient') && json['patient'] is Map<String, dynamic>
        ? json['patient'] as Map<String, dynamic>
        : json;

    final parsedDob = _parseDate(data['date_of_birth'] ?? data['dateOfBirth']);
    final parsedRegDate = _parseDate(
      data['registration_date'] ?? data['registrationDate'],
    );

    return Patient(
      id: _parseInt(data['patient_id'] ?? data['id']) ?? 0,
      uid: (data['registration_no'] ?? data['patient_uid'] ?? data['uid'] ?? '')
          .toString(),
      name: (data['name'] ?? data['full_name'] ?? '').toString(),
      dateOfBirth: parsedDob,
      age: _parseInt(data['age']),
      condition: (data['disease_condition'] ?? data['condition'] ?? '')
          .toString(),
      phone: data['emergency_contact']?.toString() ?? data['phone']?.toString(),
      photoUrl: data['photo_url']?.toString(),
      preferredLanguage:
          (data['preferred_language'] ?? data['preferredLanguage'] ?? 'English')
              .toString(),
      registrationDate: parsedRegDate,
      registeredBy: _parseInt(data['registered_by']),
      receptionistName:
          data['receptionist_name']?.toString() ??
          data['registered_by_name']?.toString() ??
          data['receptionist']?.toString(),
      currentMedicines: data['current_medicines']?.toString(),
    );
  }
}

class PatientVisit {
  final int visitId;
  final int patientId;
  final int? doctorId;
  final String? visitDate;
  final String visitType;
  final String status;
  final String? reason;
  final String? notes;
  final String? temperature;
  final String? bloodPressure;
  final String? pulse;
  final String? spo2;
  final String? weight;
  final String? height;

  const PatientVisit({
    required this.visitId,
    required this.patientId,
    this.doctorId,
    this.visitDate,
    this.visitType = 'consultation',
    this.status = 'completed',
    this.reason,
    this.notes,
    this.temperature,
    this.bloodPressure,
    this.pulse,
    this.spo2,
    this.weight,
    this.height,
  });

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  factory PatientVisit.fromJson(Map<String, dynamic> json) {
    return PatientVisit(
      visitId: _parseInt(json['visit_id']) ?? 0,
      patientId: _parseInt(json['patient_id']) ?? 0,
      doctorId: _parseInt(json['doctor_id']),
      visitDate: json['visit_date']?.toString(),
      visitType: json['visit_type']?.toString() ?? 'consultation',
      status: json['status']?.toString() ?? 'completed',
      reason: json['reason']?.toString(),
      notes: json['notes']?.toString(),
      temperature: json['temperature']?.toString(),
      bloodPressure: json['blood_pressure']?.toString(),
      pulse: json['pulse']?.toString(),
      spo2: json['spo2']?.toString(),
      weight: json['weight']?.toString(),
      height: json['height']?.toString(),
    );
  }
}

class HealthSummary {
  const HealthSummary({
    required this.hasData,
    this.visitId,
    this.visitDate,
    this.doctorName,
    this.heartRate,
    this.bloodPressure,
    this.spo2,
    this.temperature,
    this.weight,
    this.height,
  });

  final bool hasData;
  final int? visitId;
  final String? visitDate;
  final String? doctorName;
  final String? heartRate;
  final String? bloodPressure;
  final String? spo2;
  final String? temperature;
  final String? weight;
  final String? height;

  factory HealthSummary.fromJson(Map<String, dynamic> json) {
    final vitals = json['vitals'] is Map
        ? Map<String, dynamic>.from(json['vitals'] as Map)
        : <String, dynamic>{};
    final doctor = json['doctor'] is Map
        ? Map<String, dynamic>.from(json['doctor'] as Map)
        : <String, dynamic>{};
    return HealthSummary(
      hasData: json['has_data'] == true,
      visitId: (json['visit_id'] as num?)?.toInt(),
      visitDate: json['visit_date']?.toString(),
      doctorName: doctor['name']?.toString(),
      heartRate: vitals['heart_rate']?.toString(),
      bloodPressure: vitals['blood_pressure']?.toString(),
      spo2: vitals['spo2']?.toString(),
      temperature: vitals['temperature']?.toString(),
      weight: vitals['weight']?.toString(),
      height: vitals['height']?.toString(),
    );
  }
}

class VitalHistoryEntry {
  const VitalHistoryEntry({
    required this.visitId,
    this.visitDate,
    this.doctorName,
    this.pulse,
    this.bloodPressure,
    this.spo2,
    this.temperature,
    this.weight,
    this.height,
  });
  final int visitId;
  final String? visitDate;
  final String? doctorName;
  final String? pulse;
  final String? bloodPressure;
  final String? spo2;
  final String? temperature;
  final String? weight;
  final String? height;
  factory VitalHistoryEntry.fromJson(Map<String, dynamic> json) {
    final v = json['vitals'] is Map
        ? Map<String, dynamic>.from(json['vitals'] as Map)
        : <String, dynamic>{};
    final id = json['visit_id'];
    return VitalHistoryEntry(
      visitId: id is num ? id.toInt() : int.tryParse('$id') ?? 0,
      visitDate: json['visit_date']?.toString(),
      doctorName: json['doctor_name']?.toString(),
      pulse: v['pulse']?.toString(),
      bloodPressure: v['blood_pressure']?.toString(),
      spo2: v['spo2']?.toString(),
      temperature: v['temperature']?.toString(),
      weight: v['weight']?.toString(),
      height: v['height']?.toString(),
    );
  }
}

class VitalHistoryPage {
  const VitalHistoryPage({
    required this.items,
    required this.hasMore,
    required this.offset,
  });
  final List<VitalHistoryEntry> items;
  final bool hasMore;
  final int offset;
  factory VitalHistoryPage.fromJson(Map<String, dynamic> json) =>
      VitalHistoryPage(
        items: ((json['items'] as List?) ?? [])
            .whereType<Map>()
            .map(
              (e) => VitalHistoryEntry.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList(),
        hasMore: json['has_more'] == true,
        offset: (json['offset'] as num?)?.toInt() ?? 0,
      );
}

class PatientReport {
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

  const PatientReport({
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
  });

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  factory PatientReport.fromJson(Map<String, dynamic> json) {
    return PatientReport(
      reportId: _parseInt(json['report_id']) ?? 0,
      patientId: _parseInt(json['patient_id']) ?? 0,
      visitId: _parseInt(json['visit_id']),
      doctorId: _parseInt(json['doctor_id']),
      versionNo: _parseInt(json['version_no']) ?? 1,
      diagnosis: json['diagnosis']?.toString() ?? '',
      clinicalNotes: json['clinical_notes']?.toString(),
      voiceTranscript: json['voice_transcript']?.toString(),
      reportDatetime: json['report_datetime']?.toString(),
      isFinal: json['is_final'] is bool ? json['is_final'] as bool : true,
    );
  }
}

class PatientMedicalHistory {
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

  const PatientMedicalHistory({
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

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  factory PatientMedicalHistory.fromJson(Map<String, dynamic> json) {
    return PatientMedicalHistory(
      historyId: _parseInt(json['history_id']) ?? 0,
      patientId: _parseInt(json['patient_id']) ?? 0,
      medicineName: json['medicine_name']?.toString(),
      medicineType: json['medicine_type']?.toString(),
      dosage: json['dosage']?.toString(),
      frequency: json['frequency']?.toString(),
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      reason: json['reason']?.toString(),
      notes: json['notes']?.toString(),
      visitId: _parseInt(json['visit_id']),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class PrescriptionItem {
  const PrescriptionItem({
    this.itemId = 0,
    this.medicineId,
    required this.name,
    this.genericName,
    this.strength,
    this.dosage,
    this.frequency,
    this.durationDays,
    this.instructions,
    this.route,
    this.foodTiming,
    this.medicineType,
    this.startDate,
    this.endDate,
    this.reminderTimes = const [],
  });

  final int itemId;
  final int? medicineId;
  final String name;
  final String? genericName;
  final String? strength;
  final String? dosage;
  final String? frequency;
  final int? durationDays;
  final String? instructions;
  final String? route;
  final String? foodTiming;
  final String? medicineType;
  final String? startDate;
  final String? endDate;
  final List<String> reminderTimes;

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  factory PrescriptionItem.fromJson(Map<String, dynamic> json) =>
      PrescriptionItem(
        itemId: _parseInt(json['item_id']) ?? 0,
        medicineId: _parseInt(json['medicine_id']),
        name: json['medicine_name']?.toString() ?? '',
        genericName: json['generic_name']?.toString(),
        strength: json['strength']?.toString(),
        dosage: json['dosage']?.toString(),
        frequency: json['frequency']?.toString(),
        durationDays: _parseInt(json['duration_days']),
        instructions: json['instructions']?.toString(),
        route: json['route']?.toString(),
        foodTiming: json['food_timing']?.toString(),
        medicineType: json['medicine_type']?.toString(),
        startDate: json['start_date']?.toString(),
        endDate: json['end_date']?.toString(),
        reminderTimes: ((json['reminder_times'] as List?) ?? [])
            .map((value) => value.toString())
            .toList(growable: false),
      );
}

class PatientPrescription {
  const PatientPrescription({
    required this.id,
    this.createdAt,
    this.doctorId,
    required this.items,
  });

  final int id;
  final String? createdAt;
  final int? doctorId;
  final List<PrescriptionItem> items;

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  factory PatientPrescription.fromJson(Map<String, dynamic> json) =>
      PatientPrescription(
        id: _parseInt(json['prescription_id']) ?? 0,
        createdAt: json['created_at']?.toString(),
        doctorId: _parseInt(json['doctor_id']),
        items: ((json['items'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => PrescriptionItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class ClinicalVisit {
  const ClinicalVisit({
    required this.visit,
    this.doctorName,
    this.diagnosis,
    this.reportNotes,
    this.prescription,
    this.reportDatetime,
  });

  final PatientVisit visit;
  final String? doctorName;
  final String? diagnosis;
  final String? reportNotes;
  final PatientPrescription? prescription;

  /// ISO datetime string of the associated report, if any.
  final String? reportDatetime;

  factory ClinicalVisit.fromJson(Map<String, dynamic> json) {
    // vitals come nested under "vitals" in clinical-records endpoint
    final vitals = json['vitals'] is Map
        ? Map<String, dynamic>.from(json['vitals'] as Map)
        : <String, dynamic>{};
    final visitJson = Map<String, dynamic>.from(json)..addAll(vitals);

    final report = json['report'] is Map
        ? Map<String, dynamic>.from(json['report'] as Map)
        : <String, dynamic>{};

    final prescriptionJson = json['prescription'];
    final prescription = prescriptionJson is Map
        ? PatientPrescription.fromJson(
            Map<String, dynamic>.from(prescriptionJson),
          )
        : null;

    return ClinicalVisit(
      visit: PatientVisit.fromJson(visitJson),
      doctorName: json['doctor_name']?.toString(),
      diagnosis: report['diagnosis']?.toString(),
      reportNotes: report['clinical_notes']?.toString(),
      prescription: prescription,
      reportDatetime: report['report_datetime']?.toString(),
    );
  }
}

class PatientAppointmentReschedule {
  const PatientAppointmentReschedule({
    required this.requestId,
    required this.status,
    required this.preferredDatetime,
    this.reason,
  });

  final int requestId;
  final String status;
  final String preferredDatetime;
  final String? reason;

  factory PatientAppointmentReschedule.fromJson(Map<String, dynamic> json) =>
      PatientAppointmentReschedule(
        requestId: (json['request_id'] as num).toInt(),
        status: json['status']?.toString() ?? 'pending',
        preferredDatetime: json['preferred_datetime']?.toString() ?? '',
        reason: json['reason']?.toString(),
      );
}

class PatientAppointment {
  const PatientAppointment({
    required this.appointmentId,
    required this.patientId,
    required this.doctorId,
    required this.doctorName,
    required this.department,
    this.specialization,
    required this.appointmentDatetime,
    this.reason,
    this.notes,
    required this.status,
    required this.hospitalName,
    this.rescheduleRequest,
  });

  final int appointmentId;
  final int patientId;
  final int doctorId;
  final String doctorName;
  final String department;
  final String? specialization;
  final String appointmentDatetime;
  final String? reason;
  final String? notes;
  final String status;
  final String hospitalName;
  final PatientAppointmentReschedule? rescheduleRequest;

  DateTime get date => DateTime.tryParse(appointmentDatetime) ?? DateTime.now();

  factory PatientAppointment.fromJson(Map<String, dynamic> json) {
    final reschedule = json['reschedule_request'];
    return PatientAppointment(
      appointmentId: json['appointment_id'] as int,
      patientId: json['patient_id'] as int,
      doctorId: json['doctor_id'] as int,
      doctorName: json['doctor_name'] as String? ?? 'Doctor',
      department: json['department'] as String? ?? 'General Medicine',
      specialization: json['specialization'] as String?,
      appointmentDatetime: json['appointment_datetime'] as String? ?? '',
      reason: json['reason'] as String?,
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'scheduled',
      hospitalName: json['hospital_name'] as String? ?? 'City Care Hospital',
      rescheduleRequest: reschedule is Map
          ? PatientAppointmentReschedule.fromJson(
              Map<String, dynamic>.from(reschedule),
            )
          : null,
    );
  }
}
