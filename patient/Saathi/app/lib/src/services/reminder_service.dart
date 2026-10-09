import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_text.dart';
import '../models.dart';
import '../screens/medicine_reminder_screen.dart';
import '../settings.dart';

/// Medicine-time reminders: local notification + spoken alert.
///
/// Schedules high-priority alarms at the exact times prescribed by the doctor.
/// When the alarm fires, it pops up on the phone's home screen (heads-up banner
/// like Flipkart / Amazon), plays sound, vibrates, and offers one-touch
/// "Mark as Taken" and "Snooze" actions directly on the notification.
/// Tapping the notification opens [MedicineReminderScreen] and speaks the alert.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _storage = const FlutterSecureStorage();
  final _tts = FlutterTts();
  bool _initialized = false;

  /// Callback registered by AppController to record adherence when the patient
  /// taps "Mark as Taken" directly from the mobile notification.
  Future<void> Function(int itemId, String status)? onAdherenceAction;

  /// Whether the shared [FlutterTts] engine is currently reading something
  /// aloud, for any of the "Listen" controls in the app.
  final isSpeaking = ValueNotifier<bool>(false);

  static const _channelId = 'medicine_reminders';
  static const _appointmentChannelId = 'appointment_reminders';
  static const _demoPayload = 'demo_reminder';
  static const _activeMedicineIdsKey = 'active_medicine_notification_ids';

  /// Navigator key so a tapped notification can open
  /// [MedicineReminderScreen] even if the app was backgrounded.
  final navigatorKey = GlobalKey<NavigatorState>();

  /// How fast every spoken prompt in the app is read out.
  double speechRate = VoiceSpeed.normal.rate;

  ReminderContent? _lastContent;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone));
    } catch (_) {
      // tz.local remains available; scheduling still works in the fallback zone.
    }

    _tts.setStartHandler(() => isSpeaking.value = true);
    _tts.setCompletionHandler(() => isSpeaking.value = false);
    _tts.setCancelHandler(() => isSpeaking.value = false);
    _tts.setErrorHandler((_) => isSpeaking.value = false);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    // Heads-up pop-up channel on Android with MAX importance, sound, and vibration
    const channel = AndroidNotificationChannel(
      _channelId,
      'Medicine reminders',
      description: 'Urgent reminders to take your prescribed medicine on time',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    const appointmentChannel = AndroidNotificationChannel(
      _appointmentChannelId,
      'Appointment reminders',
      description: 'Reminders for upcoming hospital appointments',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(appointmentChannel);
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (response.actionId == 'taken_action') {
      if (payload != null) _handleTakenAction(payload);
      return;
    }
    if (response.actionId == 'snooze_action') {
      if (payload != null) _handleSnoozeAction(payload);
      return;
    }
    if (payload == _demoPayload) {
      _openReminderScreen();
      return;
    }
    if (payload != null && payload.startsWith('{')) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final content = ReminderContent.fromJson(data);
        _lastContent = content;
        speak(content);
        _openReminderScreen();
        return;
      } catch (_) {}
    }
    _openReminderScreen();
  }

  Future<void> _handleTakenAction(String payload) async {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final itemId = data['itemId'] as int?;
      if (itemId != null && onAdherenceAction != null) {
        await onAdherenceAction!(itemId, 'taken');
      }
    } catch (_) {}
  }

  Future<void> _handleSnoozeAction(String payload) async {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final content = ReminderContent.fromJson(data);
      await snoozeMedicineReminder(content, minutes: 10);
    } catch (_) {}
  }

  int appointmentNotificationId(int appointmentId) =>
      0x40000000 | (appointmentId & 0x3fffffff);

  int medicineNotificationId(int itemId, int hour, int minute) =>
      ((itemId & 0x7fff) << 11) | ((hour & 0x1f) << 6) | (minute & 0x3f);

  String _appointmentPreferenceKey(int appointmentId, String field) =>
      'appointment_reminder_${appointmentId}_$field';

  Future<bool> scheduleAppointment({
    required int appointmentId,
    required DateTime appointmentTime,
    required int offsetMinutes,
    required String title,
    required String body,
  }) async {
    await init();
    if (!await requestPermissions()) {
      throw Exception('notification_permission_denied');
    }
    final when = appointmentTime.subtract(Duration(minutes: offsetMinutes));
    if (!when.isAfter(DateTime.now())) throw StateError('reminder_time_passed');
    final id = appointmentNotificationId(appointmentId);
    final replacing = (await _plugin.pendingNotificationRequests()).any(
      (request) => request.id == id,
    );
    await _plugin.cancel(id);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _appointmentChannelId,
          'Appointment reminders',
          channelDescription: 'Reminders for upcoming hospital appointments',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'appointment_reminder',
    );
    try {
      await Future.wait([
        _storage.write(
          key: _appointmentPreferenceKey(appointmentId, 'offset'),
          value: offsetMinutes.toString(),
        ),
        _storage.write(
          key: _appointmentPreferenceKey(appointmentId, 'time'),
          value: appointmentTime.toIso8601String(),
        ),
        _storage.write(
          key: _appointmentPreferenceKey(appointmentId, 'title'),
          value: title,
        ),
        _storage.write(
          key: _appointmentPreferenceKey(appointmentId, 'body'),
          value: body,
        ),
      ]);
    } catch (_) {
      // The OS notification is already scheduled.
    }
    return replacing;
  }

  Future<void> refreshAppointmentReminder({
    required int appointmentId,
    required DateTime appointmentTime,
    required String body,
  }) async {
    final offsetText = await _storage.read(
      key: _appointmentPreferenceKey(appointmentId, 'offset'),
    );
    final savedTime = await _storage.read(
      key: _appointmentPreferenceKey(appointmentId, 'time'),
    );
    if (offsetText == null || savedTime == appointmentTime.toIso8601String()) {
      return;
    }
    final offset = int.tryParse(offsetText);
    final title = await _storage.read(
      key: _appointmentPreferenceKey(appointmentId, 'title'),
    );
    if (offset == null || title == null) return;
    if (!appointmentTime
        .subtract(Duration(minutes: offset))
        .isAfter(DateTime.now())) {
      await cancelAppointmentReminder(appointmentId);
      return;
    }
    await scheduleAppointment(
      appointmentId: appointmentId,
      appointmentTime: appointmentTime,
      offsetMinutes: offset,
      title: title,
      body: body,
    );
  }

  Future<void> cancelAppointmentReminder(int appointmentId) async {
    await _plugin.cancel(appointmentNotificationId(appointmentId));
    await Future.wait([
      for (final field in ['offset', 'time', 'title', 'body'])
        _storage.delete(key: _appointmentPreferenceKey(appointmentId, field)),
    ]);
  }

  Future<bool> requestPermissions() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidGranted = await androidPlugin
        ?.requestNotificationsPermission();
    try {
      await androidPlugin?.requestExactAlarmsPermission();
    } catch (_) {}
    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return (androidGranted ?? true) && (iosGranted ?? true);
  }

  /// Builds high-priority NotificationDetails that trigger a Heads-Up pop-up
  /// on the phone's home screen (like Flipkart, Amazon, and clock alarms).
  NotificationDetails _buildMedicineNotificationDetails({
    required String title,
    required String body,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Medicine reminders',
        channelDescription:
            'Urgent reminders to take your prescribed medicine on time',
        importance: Importance.max,
        priority: Priority.max,
        ticker: 'Time for your medicine',
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        channelShowBadge: true,
        playSound: true,
        enableVibration: true,
        actions: const [
          AndroidNotificationAction(
            'taken_action',
            'Mark as Taken',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'snooze_action',
            'Snooze (10m)',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'Medicine Reminder',
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  /// Parses the doctor's assigned reminder times from a [PrescriptionItem].
  ///
  /// Extracts explicit clock times from `frequency` and `instructions`,
  /// handles Indian clinical dosage shorthand (e.g. 1-0-1), slot keywords
  /// (morning, afternoon, evening, night), and general medical frequencies
  /// (twice daily, 3x daily, etc.).
  static List<TimeOfDay> parseDoctorTimes(PrescriptionItem item) {
    final times = <TimeOfDay>[];
    final combined = '${item.frequency ?? ""} ${item.instructions ?? ""}'
        .trim();

    // 1. Check for explicit 12-hour clock times like 08:00 AM, 8:30 PM, 1:00 pm, etc.
    final regex12 = RegExp(r'\b(0?[1-9]|1[0-2]):([0-5]\d)\s*(AM|PM|am|pm)\b');
    for (final match in regex12.allMatches(combined)) {
      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final ampm = match.group(3)!.toUpperCase();
      if (ampm == 'PM' && hour < 12) hour += 12;
      if (ampm == 'AM' && hour == 12) hour = 0;
      final tod = TimeOfDay(hour: hour, minute: minute);
      if (!times.any((t) => t.hour == tod.hour && t.minute == tod.minute)) {
        times.add(tod);
      }
    }

    // 2. Check for explicit 24-hour clock times like 08:00, 14:30, 20:00 (if no 12-hr matched)
    if (times.isEmpty) {
      final regex24 = RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)\b');
      for (final match in regex24.allMatches(combined)) {
        final hour = int.parse(match.group(1)!);
        final minute = int.parse(match.group(2)!);
        final tod = TimeOfDay(hour: hour, minute: minute);
        if (!times.any((t) => t.hour == tod.hour && t.minute == tod.minute)) {
          times.add(tod);
        }
      }
    }

    if (times.isNotEmpty) {
      times.sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
      );
      return times;
    }

    // 3. Check for dosage shorthand pattern (e.g. 1-0-1, 1-1-1, 0-0-1)
    final dosePattern = RegExp(
      r'\b([0-2])\s*[-–/]\s*([0-2])\s*[-–/]\s*([0-2])\b',
    );
    final doseMatch = dosePattern.firstMatch(combined);
    if (doseMatch != null) {
      final morning = int.tryParse(doseMatch.group(1)!) ?? 0;
      final noon = int.tryParse(doseMatch.group(2)!) ?? 0;
      final night = int.tryParse(doseMatch.group(3)!) ?? 0;
      if (morning > 0) times.add(const TimeOfDay(hour: 8, minute: 0));
      if (noon > 0) times.add(const TimeOfDay(hour: 13, minute: 0));
      if (night > 0) times.add(const TimeOfDay(hour: 20, minute: 0));
      if (times.isNotEmpty) return times;
    }

    // 4. Check for clinical keywords
    final lower = combined.toLowerCase();
    final hasMorning =
        lower.contains('morning') ||
        lower.contains('breakfast') ||
        lower.contains('subah');
    final hasNoon =
        lower.contains('afternoon') ||
        lower.contains('lunch') ||
        lower.contains('dopahar');
    final hasEvening =
        lower.contains('evening') ||
        lower.contains('tea') ||
        lower.contains('shaam');
    final hasNight =
        lower.contains('night') ||
        lower.contains('bed') ||
        lower.contains('dinner') ||
        lower.contains('raat') ||
        lower.contains('hs');

    if (hasMorning || hasNoon || hasEvening || hasNight) {
      if (hasMorning) times.add(const TimeOfDay(hour: 8, minute: 0));
      if (hasNoon) times.add(const TimeOfDay(hour: 13, minute: 0));
      if (hasEvening) times.add(const TimeOfDay(hour: 18, minute: 0));
      if (hasNight) times.add(const TimeOfDay(hour: 20, minute: 30));
      return times;
    }

    // 5. Standard medical frequency multipliers
    if (lower.contains('4x') ||
        lower.contains('qid') ||
        lower.contains('four times')) {
      return const [
        TimeOfDay(hour: 8, minute: 0),
        TimeOfDay(hour: 12, minute: 0),
        TimeOfDay(hour: 16, minute: 0),
        TimeOfDay(hour: 20, minute: 0),
      ];
    }
    if (lower.contains('3x') ||
        lower.contains('tid') ||
        lower.contains('thrice') ||
        lower.contains('three times')) {
      return const [
        TimeOfDay(hour: 8, minute: 0),
        TimeOfDay(hour: 13, minute: 0),
        TimeOfDay(hour: 20, minute: 0),
      ];
    }
    if (lower.contains('2x') ||
        lower.contains('bid') ||
        lower.contains('twice') ||
        lower.contains('two times')) {
      return const [
        TimeOfDay(hour: 8, minute: 0),
        TimeOfDay(hour: 20, minute: 0),
      ];
    }

    // Default: once daily at 08:00 AM
    return const [TimeOfDay(hour: 8, minute: 0)];
  }

  /// Times safe to activate without choosing a clock time for the patient.
  /// Frequency words and morning/evening shorthand need patient confirmation.
  static List<TimeOfDay> parseExplicitTimes(PrescriptionItem item) {
    if (item.reminderTimes.isNotEmpty) {
      final structuredTimes = <TimeOfDay>[];
      for (final raw in item.reminderTimes) {
        final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.trim());
        if (match == null) continue;
        final hour = int.tryParse(match.group(1)!);
        final minute = int.tryParse(match.group(2)!);
        if (hour == null || minute == null || hour > 23 || minute > 59) continue;
        structuredTimes.add(TimeOfDay(hour: hour, minute: minute));
      }
      if (structuredTimes.isNotEmpty) return structuredTimes;
    }
    final combined = '${item.frequency ?? ''} ${item.instructions ?? ''}';
    if (RegExp(
      r'\b(as needed|if needed|prn)\b',
      caseSensitive: false,
    ).hasMatch(combined)) {
      return [];
    }
    final times = <TimeOfDay>[];
    final twelve = RegExp(
      r'\b(0?[1-9]|1[0-2]):([0-5]\d)\s*(AM|PM)\b',
      caseSensitive: false,
    );
    for (final match in twelve.allMatches(combined)) {
      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      if (match.group(3)!.toUpperCase() == 'PM' && hour < 12) hour += 12;
      if (match.group(3)!.toUpperCase() == 'AM' && hour == 12) hour = 0;
      times.add(TimeOfDay(hour: hour, minute: minute));
    }
    if (times.isEmpty) {
      final twentyFour = RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)\b');
      for (final match in twentyFour.allMatches(combined)) {
        times.add(
          TimeOfDay(
            hour: int.parse(match.group(1)!),
            minute: int.parse(match.group(2)!),
          ),
        );
      }
    }
    final unique = <String, TimeOfDay>{};
    for (final time in times) {
      unique['${time.hour}:${time.minute}'] = time;
    }
    return unique.values.toList()..sort(
      (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
    );
  }

  static String formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  /// Synchronizes scheduled medicine reminder alarms on the device with the
  /// doctor's current prescription.
  ///
  /// Cancels previous alarms that are no longer active, and schedules recurring
  /// daily exact alarms for each medicine and time slot assigned by the doctor.
  Future<int> syncPrescriptionReminders({
    required Patient patient,
    required String diseaseName,
    required List<PrescriptionItem> items,
    required AppLanguage language,
  }) async {
    await init();
    try {
      await requestPermissions();
    } catch (_) {}

    // Cancel old scheduled alarms
    final storedIds = await _storage.read(key: _activeMedicineIdsKey);
    if (storedIds != null && storedIds.isNotEmpty) {
      final ids = storedIds
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();
      for (final id in ids) {
        await _plugin.cancel(id);
      }
    }

    if (items.isEmpty) {
      await _storage.delete(key: _activeMedicineIdsKey);
      return 0;
    }

    final newIds = <int>[];
    final text = AppText(language);

    for (final item in items) {
      final times = parseExplicitTimes(item);
      final foodTiming = item.foodTiming;

      for (final time in times) {
        final id = medicineNotificationId(item.itemId, time.hour, time.minute);
        final timeStr = formatTimeOfDay(time);

        final title = '${patient.name}, ${text(T.reminderItIsTimeFor)}';
        final body =
            '${item.name}${item.dosage == null ? '' : ' (${item.dosage})'} — ${text(T.reminderYourMedicineFor)} $diseaseName';

        final content = ReminderContent(
          patientName: patient.name,
          medicineName: item.name,
          instruction: [item.dosage, foodTiming, item.instructions]
              .where((value) => value != null && value.trim().isNotEmpty)
              .join(' • '),
          diseaseName: diseaseName,
          language: language,
          itemId: item.itemId,
          timeLabel: timeStr,
          dosage: item.dosage,
          foodTiming: foodTiming,
        );

        final payload = jsonEncode(content.toJson());

        // Calculate next occurrence
        final now = tz.TZDateTime.now(tz.local);
        var scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          time.hour,
          time.minute,
        );
        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }

        final details = _buildMedicineNotificationDetails(
          title: title,
          body: body,
        );

        try {
          await _plugin.zonedSchedule(
            id,
            title,
            body,
            scheduledDate,
            details,
            androidScheduleMode: AndroidScheduleMode.alarmClock,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: payload,
          );
        } catch (_) {
          try {
            await _plugin.zonedSchedule(
              id,
              title,
              body,
              scheduledDate,
              details,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              matchDateTimeComponents: DateTimeComponents.time,
              payload: payload,
            );
          } catch (_) {
            await _plugin.zonedSchedule(
              id,
              title,
              body,
              scheduledDate,
              details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              matchDateTimeComponents: DateTimeComponents.time,
              payload: payload,
            );
          }
        }

        newIds.add(id);
      }
    }

    await _storage.write(key: _activeMedicineIdsKey, value: newIds.join(','));

    return newIds.length;
  }

  /// Snoozes an active reminder for [minutes] (default 10 minutes).
  Future<void> snoozeMedicineReminder(
    ReminderContent content, {
    int minutes = 10,
  }) async {
    await init();
    final id = 0x50000000 | (content.itemId ?? 0);
    final when = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));
    final text = AppText(content.language);
    final title =
        '${content.patientName}, ${text(T.reminderItIsTimeFor)} (Snoozed)';
    final body =
        '${content.medicineName} — ${text(T.reminderYourMedicineFor)} ${content.diseaseName}';
    final details = _buildMedicineNotificationDetails(title: title, body: body);
    final payload = jsonEncode(content.toJson());

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      details,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      payload: payload,
    );
  }

  /// Fires a heads-up pop-up notification on the home screen immediately or
  /// with a delay so the patient can test and verify notifications.
  Future<void> triggerHeadsUpTest({
    required BuildContext context,
    required ReminderContent content,
    int delaySeconds = 0,
  }) async {
    _lastContent = content;
    final text = AppText(content.language);
    await requestPermissions();

    final title = '${content.patientName}, ${text(T.reminderItIsTimeFor)}';
    final body =
        '${content.medicineName} — ${text(T.reminderYourMedicineFor)} ${content.diseaseName} (${content.instruction})';
    final details = _buildMedicineNotificationDetails(title: title, body: body);
    final payload = jsonEncode(content.toJson());

    if (delaySeconds <= 0) {
      await _plugin.show(0x50000002, title, body, details, payload: payload);
      await speak(content);
      if (context.mounted) _openReminderScreen();
    } else {
      final when = tz.TZDateTime.now(
        tz.local,
      ).add(Duration(seconds: delaySeconds));
      await _plugin.zonedSchedule(
        0x50000002,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        payload: payload,
      );
    }
  }

  /// Fires one real system notification for the reminder described by
  /// [content], speaks the same information aloud, and opens
  /// [MedicineReminderScreen].
  Future<void> trigger(BuildContext context, ReminderContent content) async {
    await triggerHeadsUpTest(
      context: context,
      content: content,
      delaySeconds: 0,
    );
  }

  /// Speaks the patient's name, the medicine name, and the local disease name.
  Future<void> speak(ReminderContent content) async {
    final text = AppText(content.language);
    final sentence =
        '${content.patientName}, ${text(T.reminderItIsTimeFor)}. '
        '${content.medicineName}. ${text(T.reminderYourMedicineFor)} '
        '${content.diseaseName}.';
    await _configureVoice(content.language);
    await _tts.speak(sentence);
  }

  Future<void> speakSentence(String sentence, AppLanguage language) async {
    await _configureVoice(language);
    await _tts.speak(sentence);
  }

  Future<void> stopSpeaking() async {
    isSpeaking.value = false;
    await _tts.stop();
  }

  Future<void> _configureVoice(AppLanguage language) async {
    try {
      await _tts.setLanguage(_ttsLocaleTag(language));
    } catch (_) {}
    await _tts.setSpeechRate(speechRate);
    await _tts.setPitch(1.0);
  }

  void _openReminderScreen() {
    final content = _lastContent;
    final nav = navigatorKey.currentState;
    if (nav == null || content == null) return;
    nav.push(
      MaterialPageRoute(
        builder: (_) => MedicineReminderScreen(content: content),
      ),
    );
  }

  static String _ttsLocaleTag(AppLanguage language) => switch (language) {
    AppLanguage.english => 'en-IN',
    AppLanguage.hindi => 'hi-IN',
    AppLanguage.kannada => 'kn-IN',
  };
}

/// The information a medicine reminder reinforces:
/// patient name, medicine name, local/familiar disease name, dosage, and timings.
@immutable
class ReminderContent {
  const ReminderContent({
    required this.patientName,
    required this.medicineName,
    required this.instruction,
    required this.diseaseName,
    required this.language,
    this.itemId,
    this.timeLabel,
    this.dosage,
    this.foodTiming,
  });

  final String patientName;
  final String medicineName;
  final String instruction;
  final String diseaseName;
  final AppLanguage language;
  final int? itemId;
  final String? timeLabel;
  final String? dosage;
  final String? foodTiming;

  Map<String, dynamic> toJson() => {
    'patientName': patientName,
    'medicineName': medicineName,
    'instruction': instruction,
    'diseaseName': diseaseName,
    'language': language.code,
    if (itemId != null) 'itemId': itemId,
    if (timeLabel != null) 'timeLabel': timeLabel,
    if (dosage != null) 'dosage': dosage,
    if (foodTiming != null) 'foodTiming': foodTiming,
  };

  factory ReminderContent.fromJson(Map<String, dynamic> json) =>
      ReminderContent(
        patientName: json['patientName']?.toString() ?? '',
        medicineName: json['medicineName']?.toString() ?? '',
        instruction: json['instruction']?.toString() ?? '',
        diseaseName: json['diseaseName']?.toString() ?? '',
        language: AppLanguage.fromCode(json['language']?.toString()),
        itemId: json['itemId'] as int?,
        timeLabel: json['timeLabel']?.toString(),
        dosage: json['dosage']?.toString(),
        foodTiming: json['foodTiming']?.toString(),
      );
}
