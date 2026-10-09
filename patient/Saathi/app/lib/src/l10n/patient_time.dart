import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'app_text.dart';

/// Clock times written the way a patient should read them.
///
/// Not plain `DateFormat.jm`. Its am/pm marker comes from CLDR, and CLDR's
/// Kannada data uses the *narrow* marker — a bare "a" or "p". An appointment
/// rendered as "10:30 a" tells a Kannada-reading patient nothing about whether
/// to come in the morning or the evening, and getting that wrong means a
/// wasted trip to the hospital or a missed dose.
///
/// So: use the locale's own marker where it is a real word ("AM", "am"), and
/// fall back to the everyday part-of-day word the app already translates and
/// already uses on the prescription screen ("Morning", "सुबह", "ಬೆಳಿಗ್ಗೆ")
/// where it is not.
String formatPatientTime(DateTime when, AppText text) {
  final locale = text.language.code;
  return '${DateFormat('h:mm', locale).format(when)} '
      '${_dayMarker(when, text)}';
}

/// The [T] key for the part of the day [hour] falls in.
///
/// Boundaries match the ones the prescription screen groups doses by, so a
/// dose listed under "Morning" there never reads as "Afternoon" here.
T partOfDayFor(int hour) {
  if (hour < 12) return T.morning;
  if (hour < 17) return T.afternoon;
  return T.night;
}

String _dayMarker(DateTime when, AppText text) {
  final marker = DateFormat('a', text.language.code).format(when);
  // One character means CLDR handed back a narrow marker, not a word.
  if (marker.characters.length >= 2) return marker;
  return text(partOfDayFor(when.hour));
}
