import 'dart:convert';

import 'package:flutter/material.dart';

import '../models.dart';

/// Source-specific, patient-approved local notification schedule.
class MedicineReminderPlan {
  const MedicineReminderPlan({
    required this.patientId,
    required this.sourceKey,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.times,
    this.dose,
    this.foodTiming,
    this.instructions,
    this.itemId,
  });

  final int patientId;
  final String sourceKey;
  final String name;
  final String? dose;
  final String? foodTiming;
  final String? instructions;
  final DateTime startDate;
  final DateTime endDate;
  final List<TimeOfDay> times;
  final int? itemId;

  Map<String, dynamic> toJson() => {
    'patientId': patientId,
    'sourceKey': sourceKey,
    'name': name,
    'dose': dose,
    'foodTiming': foodTiming,
    'instructions': instructions,
    'startDate': _isoDate(startDate),
    'endDate': _isoDate(endDate),
    'times': times
        .map(
          (t) =>
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
        )
        .toList(),
    'itemId': itemId,
  };

  static MedicineReminderPlan? fromJson(Map<String, dynamic> data) {
    final start = parseCarePlanDate(data['startDate']);
    final end = parseCarePlanDate(data['endDate']);
    final patientId = data['patientId'];
    final sourceKey = data['sourceKey'];
    final name = data['name'];
    if (start == null ||
        end == null ||
        patientId is! int ||
        sourceKey is! String ||
        name is! String) {
      return null;
    }
    final times = <TimeOfDay>[];
    for (final raw in (data['times'] as List? ?? [])) {
      times.addAll(explicitClockTimes(raw.toString()));
    }
    return MedicineReminderPlan(
      patientId: patientId,
      sourceKey: sourceKey,
      name: name,
      dose: data['dose']?.toString(),
      foodTiming: data['foodTiming']?.toString(),
      instructions: data['instructions']?.toString(),
      startDate: start,
      endDate: end,
      times: times,
      itemId: data['itemId'] is int ? data['itemId'] as int : null,
    );
  }

  static MedicineReminderPlan? fromDoctor({
    required int patientId,
    required int prescriptionId,
    required PrescriptionItem item,
    required List<TimeOfDay> times,
  }) {
    final start = parseCarePlanDate(item.startDate);
    final end = parseCarePlanDate(item.endDate);
    if (item.itemId <= 0 ||
        start == null ||
        end == null ||
        end.isBefore(start) ||
        times.isEmpty ||
        isAsNeeded('${item.frequency ?? ''} ${item.instructions ?? ''}')) {
      return null;
    }
    return MedicineReminderPlan(
      patientId: patientId,
      sourceKey: 'doctor:$prescriptionId:${item.itemId}',
      name: item.name,
      dose: item.dosage,
      foodTiming: item.foodTiming,
      instructions: item.instructions,
      startDate: start,
      endDate: end,
      times: times,
      itemId: item.itemId,
    );
  }

  static MedicineReminderPlan? fromReport({
    required int patientId,
    required int reportId,
    required int medicineIndex,
    required Map medicine,
    required List<TimeOfDay> times,
  }) {
    final start = parseCarePlanDate(medicine['start_date']);
    final end = parseCarePlanDate(medicine['end_date']);
    final name = medicine['name']?.toString().trim() ?? '';
    if (name.isEmpty ||
        start == null ||
        end == null ||
        end.isBefore(start) ||
        times.isEmpty ||
        medicine['as_needed'] == true ||
        isAsNeeded(
          '${medicine['frequency'] ?? ''} ${medicine['timing'] ?? ''} '
          '${medicine['instructions'] ?? ''}',
        )) {
      return null;
    }
    return MedicineReminderPlan(
      patientId: patientId,
      sourceKey: 'pdf:$reportId:$medicineIndex',
      name: name,
      dose: medicine['dose']?.toString(),
      foodTiming: medicine['food_timing']?.toString(),
      instructions: medicine['instructions']?.toString(),
      startDate: start,
      endDate: end,
      times: times,
    );
  }

  /// Finite one-shot occurrences. The app extends long courses on each refresh.
  Iterable<DateTime> upcoming(DateTime now, {int horizonDays = 45}) sync* {
    final last = DateTime(now.year, now.month, now.day + horizonDays);
    var day = DateTime(startDate.year, startDate.month, startDate.day);
    final today = DateTime(now.year, now.month, now.day);
    if (day.isBefore(today)) day = today;
    final finalDay = DateTime(endDate.year, endDate.month, endDate.day);
    while (!day.isAfter(finalDay) && !day.isAfter(last)) {
      for (final time in times) {
        final occurrence = DateTime(
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        );
        if (occurrence.isAfter(now)) yield occurrence;
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
  }

  String get signature => jsonEncode(toJson());
}

bool isAsNeeded(String text) => RegExp(
  r'\b(as needed|if needed|prn)\b',
  caseSensitive: false,
).hasMatch(text);

DateTime? parseCarePlanDate(Object? value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  final iso = DateTime.tryParse(raw);
  if (iso != null) {
    final prefix = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
    if (prefix == null ||
        (iso.year == int.parse(prefix.group(1)!) &&
            iso.month == int.parse(prefix.group(2)!) &&
            iso.day == int.parse(prefix.group(3)!))) {
      return DateTime(iso.year, iso.month, iso.day);
    }
    return null;
  }
  const months = [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];
  final dayFirst = RegExp(
    r'^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})$',
  ).firstMatch(raw);
  final monthFirst = RegExp(
    r'^([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{4})$',
  ).firstMatch(raw);
  final day = int.tryParse(dayFirst?.group(1) ?? monthFirst?.group(2) ?? '');
  final monthName = (dayFirst?.group(2) ?? monthFirst?.group(1) ?? '')
      .toLowerCase();
  final month = months.indexOf(
    monthName.length >= 3 ? monthName.substring(0, 3) : '',
  );
  final year = int.tryParse(dayFirst?.group(3) ?? monthFirst?.group(3) ?? '');
  if (day != null && month >= 0 && year != null) {
    final date = DateTime(year, month + 1, day);
    if (date.day == day && date.month == month + 1 && date.year == year) {
      return date;
    }
  }
  return null;
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

List<TimeOfDay> explicitClockTimes(String value) {
  final matches = RegExp(
    r'\b(0?[1-9]|1[0-2]):([0-5]\d)\s*(AM|PM)\b|\b([01]?\d|2[0-3]):([0-5]\d)\b',
    caseSensitive: false,
  ).allMatches(value);
  final times = <String, TimeOfDay>{};
  for (final match in matches) {
    var hour = int.parse(match.group(1) ?? match.group(4)!);
    final minute = int.parse(match.group(2) ?? match.group(5)!);
    final period = match.group(3)?.toUpperCase();
    if (period == 'PM' && hour < 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    times['$hour:$minute'] = TimeOfDay(hour: hour, minute: minute);
  }
  return times.values.toList()..sort(
    (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
  );
}

int stableNotificationId(String value, {int prefix = 0}) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(value)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return prefix | (hash & 0x1fffffff);
}
