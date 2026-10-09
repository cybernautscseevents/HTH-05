import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saathi_app/src/models.dart';
import 'package:saathi_app/src/services/reminder_plan.dart';
import 'package:saathi_app/src/services/reminder_service.dart';
import 'package:saathi_app/src/l10n/app_text.dart';

void main() {
  test('PDF clock times and finite dates are preserved without guessing', () {
    final medicine = <String, dynamic>{
      'name': 'Example medicine 10 mg',
      'dose': '1 tablet',
      'frequency': 'Twice daily',
      'timing': '8:00 AM and 8:00 PM',
      'start_date': '10 October 2026',
      'end_date': '12 October 2026',
    };
    final plan = MedicineReminderPlan.fromReport(
      patientId: 7, reportId: 2, medicineIndex: 0, medicine: medicine,
      times: explicitClockTimes(medicine['timing'] as String),
    )!;
    expect(plan.times, const [TimeOfDay(hour: 8, minute: 0),
      TimeOfDay(hour: 20, minute: 0)]);
    expect(plan.upcoming(DateTime(2026, 10, 10, 7)).length, 6);
    expect(plan.upcoming(DateTime(2026, 10, 13)).isEmpty, isTrue);
    expect(MedicineReminderPlan.fromJson(plan.toJson())?.signature,
        plan.signature);
  });

  test('frequency alone requires patient-confirmed clock times', () {
    expect(explicitClockTimes('Twice daily in morning and evening'), isEmpty);
    expect(explicitClockTimes('At night'), isEmpty);
    expect(parseCarePlanDate('2026-02-30'), isNull);
  });

  test('as needed and missing dates do not form a daily plan', () {
    final medicine = <String, dynamic>{
      'name': 'Example medicine', 'frequency': 'As needed',
      'start_date': '2026-10-10', 'end_date': '2026-10-12',
    };
    expect(MedicineReminderPlan.fromReport(patientId: 7, reportId: 2,
      medicineIndex: 0, medicine: medicine,
      times: const [TimeOfDay(hour: 8, minute: 0)]), isNull);
    medicine['frequency'] = 'Once daily';
    medicine.remove('end_date');
    expect(MedicineReminderPlan.fromReport(patientId: 7, reportId: 2,
      medicineIndex: 0, medicine: medicine,
      times: const [TimeOfDay(hour: 8, minute: 0)]), isNull);
  });

  test('doctor PRN is not scheduled even with stored times', () {
    final item = PrescriptionItem.fromJson({
      'item_id': 5, 'medicine_name': 'Example medicine',
      'frequency': 'As needed', 'reminder_times': ['08:00'],
      'start_date': '2026-10-10', 'end_date': '2026-10-12',
    });
    expect(ReminderService.parseExplicitTimes(item), isEmpty);
  });

  test('notification IDs are stable and source separated', () {
    expect(stableNotificationId('7:doctor:1:5:2026-10-10:8:0'),
      stableNotificationId('7:doctor:1:5:2026-10-10:8:0'));
    expect(stableNotificationId('7:doctor:1:5:2026-10-10:8:0'),
      isNot(stableNotificationId('7:pdf:1:5:2026-10-10:8:0')));
  });

  test('notification payload retains patient, source and exact dose slot', () {
    const content = ReminderContent(
      patientName: 'Fictional Patient', patientId: 7,
      sourceKey: 'doctor:1:5', medicineName: 'Example medicine',
      instruction: '1 tablet', diseaseName: '',
      language: AppLanguage.english, itemId: 5,
      scheduledDate: '2026-10-10', timeSlot: '08:00',
    );
    final restored = ReminderContent.fromJson(content.toJson());
    expect(restored.patientId, 7);
    expect(restored.sourceKey, 'doctor:1:5');
    expect(restored.scheduledDate, '2026-10-10');
    expect(restored.timeSlot, '08:00');
  });
}
