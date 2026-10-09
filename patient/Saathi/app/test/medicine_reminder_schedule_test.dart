import 'package:flutter_test/flutter_test.dart';
import 'package:saathi_app/src/l10n/app_text.dart';
import 'package:saathi_app/src/models.dart';
import 'package:saathi_app/src/services/reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ReminderService Doctor Timing Parser', () {
    test(
      'parses explicit 12-hour AM/PM times from doctor frequency string',
      () {
        const item = PrescriptionItem(
          name: 'Amoxicillin 500mg',
          frequency: '2x daily (08:00 AM, 08:00 PM)',
        );
        final times = ReminderService.parseDoctorTimes(item);
        expect(times.length, 2);
        expect(times[0].hour, 8);
        expect(times[0].minute, 0);
        expect(times[1].hour, 20);
        expect(times[1].minute, 0);
        expect(ReminderService.formatTimeOfDay(times[0]), '08:00 AM');
        expect(ReminderService.formatTimeOfDay(times[1]), '08:00 PM');
      },
    );

    test('parses explicit 3x times with afternoon slot', () {
      const item = PrescriptionItem(
        name: 'Paracetamol',
        frequency: '3x daily (08:00 AM, 01:00 PM, 08:00 PM)',
        instructions: 'Reminders: 08:00 AM, 01:00 PM, 08:00 PM | After Food',
      );
      final times = ReminderService.parseDoctorTimes(item);
      expect(times.length, 3);
      expect(times[0].hour, 8);
      expect(times[1].hour, 13);
      expect(times[2].hour, 20);
    });

    test('parses 24-hour clock times when AM/PM is omitted', () {
      const item = PrescriptionItem(
        name: 'Metformin 500mg',
        frequency: 'Take at 09:30 and 21:15',
      );
      final times = ReminderService.parseDoctorTimes(item);
      expect(times.length, 2);
      expect(times[0].hour, 9);
      expect(times[0].minute, 30);
      expect(times[1].hour, 21);
      expect(times[1].minute, 15);
    });

    test('parses Indian clinical shorthand dosage 1-0-1', () {
      const item = PrescriptionItem(
        name: 'Pantoprazole 40mg',
        frequency: '1-0-1',
      );
      final times = ReminderService.parseDoctorTimes(item);
      expect(times.length, 2);
      expect(times[0].hour, 8);
      expect(times[1].hour, 20);
    });

    test('parses Indian clinical shorthand dosage 1-1-1', () {
      const item = PrescriptionItem(
        name: 'Vitamin B Complex',
        frequency: '1-1-1',
      );
      final times = ReminderService.parseDoctorTimes(item);
      expect(times.length, 3);
      expect(times[0].hour, 8);
      expect(times[1].hour, 13);
      expect(times[2].hour, 20);
    });

    test('parses clinical keywords Morning and Night', () {
      const item = PrescriptionItem(
        name: 'Amlodipine 5mg',
        frequency: 'Morning, Night',
      );
      final times = ReminderService.parseDoctorTimes(item);
      expect(times.length, 2);
      expect(times[0].hour, 8);
      expect(times[1].hour, 20);
      expect(times[1].minute, 30);
    });

    test('parses standard frequency BID (twice daily)', () {
      const item = PrescriptionItem(
        name: 'Cetirizine 10mg',
        frequency: 'Twice daily',
      );
      final times = ReminderService.parseDoctorTimes(item);
      expect(times.length, 2);
      expect(times[0].hour, 8);
      expect(times[1].hour, 20);
    });

    test('parses standard frequency TID (three times daily)', () {
      const item = PrescriptionItem(name: 'Cough Syrup', frequency: 'TID');
      final times = ReminderService.parseDoctorTimes(item);
      expect(times.length, 3);
      expect(times[0].hour, 8);
      expect(times[1].hour, 13);
      expect(times[2].hour, 20);
    });

    test('defaults to 08:00 AM for once daily or unspecified', () {
      const item = PrescriptionItem(
        name: 'Atorvastatin 10mg',
        frequency: 'Once daily',
      );
      final times = ReminderService.parseDoctorTimes(item);
      expect(times.length, 1);
      expect(times[0].hour, 8);
      expect(times[0].minute, 0);
    });
  });

  group('Reminder activation safety', () {
    test('uses only written clock times', () {
      const item = PrescriptionItem(
        name: 'Cetirizine 10 mg',
        frequency: 'Once daily at 9:00 PM',
      );
      expect(ReminderService.parseExplicitTimes(item).single.hour, 21);
      const unclear = PrescriptionItem(name: 'Spray', frequency: 'Twice daily');
      expect(ReminderService.parseExplicitTimes(unclear), isEmpty);
    });

    test('never schedules an as-needed dose', () {
      const item = PrescriptionItem(
        name: 'Paracetamol 500 mg',
        frequency: 'As needed at 9:00 PM for fever',
      );
      expect(ReminderService.parseExplicitTimes(item), isEmpty);
    });
  });

  group('ReminderContent Serialization', () {
    test('serializes to and from JSON correctly', () {
      const original = ReminderContent(
        patientName: 'Ramesh Kumar',
        medicineName: 'Metformin 500mg',
        instruction: '1 tablet • After Food',
        diseaseName: 'Type 2 Diabetes',
        language: AppLanguage.hindi,
        itemId: 42,
        timeLabel: '08:00 AM',
        dosage: '1 tablet',
        foodTiming: 'After Food',
      );

      final json = original.toJson();
      final restored = ReminderContent.fromJson(json);

      expect(restored.patientName, 'Ramesh Kumar');
      expect(restored.medicineName, 'Metformin 500mg');
      expect(restored.instruction, '1 tablet • After Food');
      expect(restored.diseaseName, 'Type 2 Diabetes');
      expect(restored.language, AppLanguage.hindi);
      expect(restored.itemId, 42);
      expect(restored.timeLabel, '08:00 AM');
      expect(restored.dosage, '1 tablet');
      expect(restored.foodTiming, 'After Food');
    });
  });

  group('Deterministic Notification ID Generation', () {
    test('generates unique positive IDs within 31-bit integer limit', () {
      final id1 = ReminderService.instance.medicineNotificationId(1, 8, 0);
      final id2 = ReminderService.instance.medicineNotificationId(1, 20, 0);
      final id3 = ReminderService.instance.medicineNotificationId(2, 8, 0);

      expect(id1, isPositive);
      expect(id2, isPositive);
      expect(id3, isPositive);
      expect(id1, isNot(id2));
      expect(id1, isNot(id3));
      expect(id2, isNot(id3));
    });
  });
}
