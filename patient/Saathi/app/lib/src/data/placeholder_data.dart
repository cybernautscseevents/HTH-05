import '../l10n/app_text.dart';

/// ============================================================================
/// PHASE 2 SEAM — PLACEHOLDER CLINICAL DATA
/// ============================================================================
///
/// Everything in this file is fake. None of it is read from
/// [ApiClient]/the FastAPI backend, and none of it is written back anywhere.
/// It exists so the visit-history, next-appointment, prescription and
/// medicine-reminder screens can be fully built and demoed before the backend
/// models this data (Phase 2: appointments, prescriptions, dispensed
/// medicines).
///
/// EVERY function in this file is named `mockXxx` and every value is marked
/// `// PLACEHOLDER` at its use site, so a future pass wiring up the real API
/// can grep for `mock` in `lib/src/data/` and know exactly what to replace.
/// The screens that consume this file only touch it through the functions
/// below — swap the function bodies for `ApiClient` calls and no screen code
/// needs to change.
/// ============================================================================

class MockAppointment {
  const MockAppointment({
    required this.date,
    required this.doctorName,
    required this.hospitalName,
    this.note,
  });

  /// Both the calendar day and the clock time of the appointment. The
  /// dashboard card renders the day, the weekday and the time from this one
  /// value, so a backend that returns a single ISO timestamp maps straight
  /// onto it.
  final DateTime date;
  final String doctorName;
  final String hospitalName;
  final String? note;
}

/// One dose the patient is due to take today.
///
/// Split into four independent fields on purpose — name, dosage, when, and
/// how — because that is how the backend will return it, and because the
/// dashboard card and the spoken reminder each need a different subset. A
/// single pre-joined "Metformin 1 tablet after breakfast" string would have to
/// be re-parsed by both.
///
/// [timeOfDay] and [instruction] are [T] keys rather than free text so they
/// translate with the app; [medicineName] and [dosage] stay as data, since
/// they come verbatim from the doctor's prescription.
class MockTodayMedicine {
  const MockTodayMedicine({
    required this.medicineName,
    required this.dosage,
    required this.timeOfDay,
    required this.instruction,
    required this.scheduledHour,
    required this.scheduledMinute,
  });

  final String medicineName; // e.g. "Metformin"
  final String dosage; // e.g. "1 tablet"
  final T timeOfDay; // T.morning / T.afternoon / T.night
  final T instruction; // T.afterFood / T.beforeFood
  final int scheduledHour; // 24-hour clock; formatted for display per locale
  final int scheduledMinute;

  /// The dose time as a [DateTime] on today's date, ready for `DateFormat.jm`.
  DateTime scheduledAtToday() {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      scheduledHour,
      scheduledMinute,
    );
  }
}

class MockMedicineDose {
  const MockMedicineDose({
    required this.medicineName,
    required this.timeOfDay,
    required this.instruction,
  });
  final String medicineName;
  final T timeOfDay; // T.morning / T.afternoon / T.night
  final String instruction; // e.g. "1 tablet, after food"
}

class MockPrescription {
  const MockPrescription({
    required this.issuedOn,
    required this.doctorName,
    required this.doses,
  });
  final DateTime issuedOn;
  final String doctorName;
  final List<MockMedicineDose> doses;
}

class MockVisit {
  const MockVisit({
    required this.id,
    required this.date,
    required this.doctorName,
    required this.summary,
    required this.prescription,
  });
  final String id;
  final DateTime date;
  final String doctorName;
  final String summary;
  final MockPrescription prescription;
}

/// PLACEHOLDER — Phase 2 replaces this with `ApiClient.nextAppointment(token)`
/// reading the doctor-set next-appointment date from the most recent
/// prescription report.
MockAppointment? mockNextAppointment() {
  final now = DateTime.now();
  return MockAppointment(
    // Relative to today rather than a fixed calendar date, so the placeholder
    // never quietly turns into a past appointment while the backend is still
    // being built.
    date: DateTime(now.year, now.month, now.day + 12, 10, 30),
    doctorName: 'Dr. Ashish Rao',
    hospitalName: 'City Care Hospital',
    note: 'Routine sugar and blood pressure check-up',
  );
}

/// PLACEHOLDER — Phase 2 replaces this with the next unmet dose for today,
/// derived from the patient's latest prescription and the doses already
/// marked as taken. Returns null when there is nothing left to take today,
/// which the dashboard renders as an explicit empty state.
MockTodayMedicine? mockTodaysMedicine() => const MockTodayMedicine(
  medicineName: 'Metformin',
  dosage: '1 tablet',
  timeOfDay: T.morning,
  instruction: T.afterFood,
  scheduledHour: 8,
  scheduledMinute: 0,
);

/// PLACEHOLDER — Phase 2 replaces this with
/// `ApiClient.currentPrescription(token)` reading the latest immutable
/// prescription report for the patient.
MockPrescription mockCurrentPrescription() {
  final now = DateTime.now();
  return MockPrescription(
    issuedOn: DateTime(now.year, now.month, now.day - 9),
    doctorName: 'Dr. Ashish Rao',
    doses: const [
      MockMedicineDose(
        medicineName: 'Metformin 500mg',
        timeOfDay: T.morning,
        instruction: '1 tablet, after food',
      ),
      MockMedicineDose(
        medicineName: 'Metformin 500mg',
        timeOfDay: T.night,
        instruction: '1 tablet, after food',
      ),
      MockMedicineDose(
        medicineName: 'Amlodipine 5mg',
        timeOfDay: T.morning,
        instruction: '1 tablet, before food',
      ),
    ],
  );
}

/// PLACEHOLDER — Phase 2 replaces this with `ApiClient.visitHistory(token)`
/// reading every locked prescription report for the patient, newest first.
List<MockVisit> mockVisitHistory() {
  final now = DateTime.now();
  DateTime daysAgo(int d) => DateTime(now.year, now.month, now.day - d);
  return [
    MockVisit(
      id: 'v3',
      date: daysAgo(9),
      doctorName: 'Dr. Ashish Rao',
      summary: 'Follow-up visit. Sugar levels improved since last visit.',
      prescription: MockPrescription(
        issuedOn: daysAgo(9),
        doctorName: 'Dr. Ashish Rao',
        doses: const [
          MockMedicineDose(
            medicineName: 'Metformin 500mg',
            timeOfDay: T.morning,
            instruction: '1 tablet, after food',
          ),
          MockMedicineDose(
            medicineName: 'Metformin 500mg',
            timeOfDay: T.night,
            instruction: '1 tablet, after food',
          ),
          MockMedicineDose(
            medicineName: 'Amlodipine 5mg',
            timeOfDay: T.morning,
            instruction: '1 tablet, before food',
          ),
        ],
      ),
    ),
    MockVisit(
      id: 'v2',
      date: daysAgo(52),
      doctorName: 'Dr. Ashish Rao',
      summary: 'Blood pressure slightly high. Dosage adjusted.',
      prescription: MockPrescription(
        issuedOn: daysAgo(52),
        doctorName: 'Dr. Ashish Rao',
        doses: const [
          MockMedicineDose(
            medicineName: 'Metformin 500mg',
            timeOfDay: T.morning,
            instruction: '1 tablet, after food',
          ),
          MockMedicineDose(
            medicineName: 'Amlodipine 5mg',
            timeOfDay: T.morning,
            instruction: '1 tablet, before food',
          ),
        ],
      ),
    ),
    MockVisit(
      id: 'v1',
      date: daysAgo(101),
      doctorName: 'Dr. Priya Nair',
      summary: 'First visit. Diabetes and blood pressure diagnosed.',
      prescription: MockPrescription(
        issuedOn: daysAgo(101),
        doctorName: 'Dr. Priya Nair',
        doses: const [
          MockMedicineDose(
            medicineName: 'Metformin 500mg',
            timeOfDay: T.morning,
            instruction: '1 tablet, after food',
          ),
        ],
      ),
    ),
  ];
}

/// PLACEHOLDER — Phase 2 replaces this with a real PDF/image fetch of the
/// locked report from the backend and a platform save/share sheet. For now
/// this only simulates the delay of a download so the UI/UX of that action
/// can be reviewed; it does not write any file to the device.
Future<void> mockDownloadReport(String visitId) =>
    Future<void>.delayed(const Duration(milliseconds: 900));

/// The hospital this device is linked to.
///
/// Read-only everywhere it appears. A patient cannot change or unlink it —
/// that stays with hospital staff — so this is shown as information, never as
/// an editable setting.
class MockHospital {
  const MockHospital({
    required this.name,
    required this.receptionPhone,
    required this.receptionHours,
  });

  final String name;

  /// Displayed as text, not dialled. See the note on [mockLinkedHospital].
  final String receptionPhone;
  final String receptionHours;
}

/// PLACEHOLDER — Phase 2 replaces this with the hospital record the device was
/// linked to, returned alongside the patient by `ApiClient.patientMe`.
///
/// The number is deliberately shown rather than dialled. Placing a call needs
/// `url_launcher`, which is not in this app's approved package list yet — the
/// same constraint the emergency flow documents. Showing it large and legible
/// is honest and still useful; a fake "call" button would not be.
MockHospital mockLinkedHospital() => const MockHospital(
  name: 'City Care Hospital',
  receptionPhone: '080 4000 1234',
  receptionHours: 'Monday to Saturday, 9:00 AM to 6:00 PM',
);

/// PLACEHOLDER — Phase 2 replaces this with a real notification payload built
/// server-side from the prescription's time-of-day slots, delivered via the
/// backend's scheduling job. This is one illustrative dose used to demo the
/// medicine-reminder screen and notification.
MockMedicineDose mockReminderDose() => const MockMedicineDose(
  medicineName: 'Metformin 500mg',
  timeOfDay: T.morning,
  instruction: '1 tablet, after food',
);
