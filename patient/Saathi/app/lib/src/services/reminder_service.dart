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
import 'reminder_plan.dart';
import '../screens/medicine_reminder_screen.dart';
import '../settings.dart';

/// Medicine-time reminders: local notification + spoken alert.
///
/// Schedules finite device notifications at patient-confirmed clock times.
/// Android may delay delivery when exact alarm access or battery permission is
/// unavailable. Tapping a medicine notification opens its reminder screen.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _storage = const FlutterSecureStorage();
  final _tts = FlutterTts();
  bool _initialized = false;

  /// Callback registered by AppController to record adherence when the patient
  /// taps "Mark as Taken" directly from the mobile notification.
  Future<void> Function(
    int itemId,
    String status,
    String date,
    String timeSlot,
  )?
  onAdherenceAction;

  /// Whether the shared [FlutterTts] engine is currently reading something
  /// aloud, for any of the "Listen" controls in the app.
  final isSpeaking = ValueNotifier<bool>(false);

  static const _channelId = 'medicine_reminders_v2';
  static const _appointmentChannelId = 'appointment_reminders_v2';
  static const _demoPayload = 'demo_reminder';
  static const _plansKey = 'confirmed_medicine_plans_v2';
  static String _followupIdsKey(int patientId) =>
      'confirmed_followup_notification_ids_$patientId';
  static String _snoozeIdsKey(int patientId) =>
      'snoozed_medicine_notification_ids_$patientId';
  static const _testNotificationId = 0x70000001;

  VoidCallback? onAppointmentTap;

  /// Navigator key so a tapped notification can open
  /// [MedicineReminderScreen] even if the app was backgrounded.
  final navigatorKey = GlobalKey<NavigatorState>();

  /// How fast every spoken prompt in the app is read out.
  double speechRate = VoiceSpeed.normal.rate;

  ReminderContent? _lastContent;
  bool _pendingMedicineOpen = false;
  bool _pendingAppointmentOpen = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    await refreshLocalTimezone();

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
    // Previous releases used unbounded daily recurring alarms. Cancel their
    // recorded IDs once so an expired course cannot keep alerting after upgrade.
    final legacyIds = await _storage.read(
      key: 'active_medicine_notification_ids',
    );
    if (legacyIds != null) {
      for (final raw in legacyIds.split(',')) {
        final id = int.tryParse(raw.trim());
        if (id != null) await _plugin.cancel(id);
      }
      await _storage.delete(key: 'active_medicine_notification_ids');
    }

    // Heads-up pop-up channel on Android with MAX importance, sound, and vibration
    const channel = AndroidNotificationChannel(
      _channelId,
      'Medicine reminders',
      description: 'Patient-confirmed medicine reminders',
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
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(appointmentChannel);
    _initialized = true;
  }

  Future<void> refreshLocalTimezone() async {
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone));
    } catch (_) {
      // The device zone can be read again when the app resumes.
    }
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
      return;
    }
    if (payload?.startsWith('appointment:') == true ||
        payload?.startsWith('followup:') == true) {
      _pendingAppointmentOpen = true;
      flushPendingNavigation();
      return;
    }
    if (payload != null && payload.startsWith('{')) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final content = ReminderContent.fromJson(data);
        _lastContent = content;
        _pendingMedicineOpen = true;
        flushPendingNavigation();
        return;
      } catch (_) {}
    }
    _pendingMedicineOpen = true;
    flushPendingNavigation();
  }

  void flushPendingNavigation() {
    if (navigatorKey.currentState == null) return;
    if (_pendingAppointmentOpen && onAppointmentTap != null) {
      _pendingAppointmentOpen = false;
      onAppointmentTap?.call();
    }
    if (_pendingMedicineOpen && _lastContent != null) {
      _pendingMedicineOpen = false;
      _openReminderScreen();
    }
  }

  Future<void> _handleTakenAction(String payload) async {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final itemId = data['itemId'] as int?;
      final date = data['scheduledDate']?.toString();
      final slot = data['timeSlot']?.toString();
      if (itemId != null &&
          date != null &&
          slot != null &&
          onAdherenceAction != null) {
        await onAdherenceAction!(itemId, 'taken', date, slot);
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
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.private,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: await _scheduleMode(),
      payload: 'appointment:$appointmentId',
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

  Future<void> scheduleRecommendedFollowup({
    required int patientId,
    required int reportId,
    required int followupIndex,
    required DateTime reminderTime,
    required String description,
  }) async {
    if (!reminderTime.isAfter(DateTime.now())) {
      throw StateError('The reminder time has already passed.');
    }
    if (!await requestPermissions()) {
      throw StateError('Notifications are disabled for Saathi on this phone.');
    }
    final id = stableNotificationId(
      '$patientId:$reportId:$followupIndex',
      prefix: 0x60000000,
    );
    await _plugin.cancel(id);
    await _plugin.zonedSchedule(
      id,
      '📅 Recommended follow-up reminder',
      '$description. Contact the clinic to confirm availability.',
      tz.TZDateTime.from(reminderTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _appointmentChannelId,
          'Appointment reminders',
          channelDescription: 'Reminders for upcoming hospital appointments',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.private,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: await _scheduleMode(),
      payload: 'followup:$reportId:$followupIndex',
    );
    final key = _followupIdsKey(patientId);
    final ids = (await _storage.read(key: key) ?? '')
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    ids.add(id);
    await _storage.write(key: key, value: ids.join(','));
  }

  Future<bool> requestPermissions() async {
    await init();
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidGranted = await androidPlugin
        ?.requestNotificationsPermission();
    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return (androidGranted ?? true) && (iosGranted ?? true);
  }

  Future<({bool notifications, bool exact, int pending})> status() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return (
      notifications: await android?.areNotificationsEnabled() ?? true,
      exact: await android?.canScheduleExactNotifications() ?? true,
      pending: (await _plugin.pendingNotificationRequests()).length,
    );
  }

  Future<bool> requestExactTiming() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestExactAlarmsPermission();
    return await android?.canScheduleExactNotifications() ?? true;
  }

  Future<AndroidScheduleMode> _scheduleMode() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return (await android?.canScheduleExactNotifications() ?? false)
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
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
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.private,
        channelShowBadge: true,
        playSound: true,
        enableVibration: true,
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
    if (isAsNeeded('${item.frequency ?? ''} ${item.instructions ?? ''}')) {
      return [];
    }
    if (item.reminderTimes.isNotEmpty) {
      final structuredTimes = <TimeOfDay>[];
      for (final raw in item.reminderTimes) {
        final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.trim());
        if (match == null) continue;
        final hour = int.tryParse(match.group(1)!);
        final minute = int.tryParse(match.group(2)!);
        if (hour == null || minute == null || hour > 23 || minute > 59) {
          continue;
        }
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

  Future<List<MedicineReminderPlan>> _readPlans() async {
    final raw = await _storage.read(key: _plansKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map(
            (value) =>
                MedicineReminderPlan.fromJson(Map<String, dynamic>.from(value)),
          )
          .whereType<MedicineReminderPlan>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _savePlans(List<MedicineReminderPlan> plans) => _storage.write(
    key: _plansKey,
    value: jsonEncode(plans.map((plan) => plan.toJson()).toList()),
  );

  String _idsKey(MedicineReminderPlan plan) =>
      'medicine_ids_${plan.patientId}_${plan.sourceKey}';
  String _signatureKey(MedicineReminderPlan plan) =>
      'medicine_signature_${plan.patientId}_${plan.sourceKey}';

  Future<void> _cancelPlan(MedicineReminderPlan plan) async {
    final raw = await _storage.read(key: _idsKey(plan));
    for (final value in (raw ?? '').split(',')) {
      final id = int.tryParse(value);
      if (id != null) await _plugin.cancel(id);
    }
    await _storage.delete(key: _idsKey(plan));
    await _storage.delete(key: _signatureKey(plan));
  }

  Future<int> _schedulePlan(
    MedicineReminderPlan plan, {
    required String patientName,
    required AppLanguage language,
    bool force = false,
  }) async {
    await init();
    await refreshLocalTimezone();
    final idsKey = _idsKey(plan);
    final oldIds = (await _storage.read(key: idsKey) ?? '')
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .toList();
    final signature =
        '${plan.signature}|${tz.local.name}|${language.name}|'
        '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    if (!force && await _storage.read(key: _signatureKey(plan)) == signature) {
      final pending = (await _plugin.pendingNotificationRequests())
          .map((request) => request.id)
          .toSet();
      if (oldIds.every(pending.contains)) return oldIds.length;
    }
    await _cancelPlan(plan);
    final mode = await _scheduleMode();
    final ids = <int>[];
    final now = DateTime.now();
    final title = '💊 Time for your medicine';
    final detail = [
      if (plan.dose?.trim().isNotEmpty == true) plan.dose!.trim(),
      if (plan.foodTiming?.trim().isNotEmpty == true) plan.foodTiming!.trim(),
    ].join(', ');
    final body = detail.isEmpty ? plan.name : '${plan.name} — $detail.';
    try {
      for (final occurrence in plan.upcoming(now)) {
        if (ids.length >= 320) break;
        final id = stableNotificationId(
          '${plan.patientId}:${plan.sourceKey}:'
          '${occurrence.year}-${occurrence.month}-${occurrence.day}:'
          '${occurrence.hour}:${occurrence.minute}',
        );
        final content = ReminderContent(
          patientName: patientName,
          patientId: plan.patientId,
          sourceKey: plan.sourceKey,
          medicineName: plan.name,
          instruction: [
            plan.dose,
            plan.foodTiming,
            plan.instructions,
          ].where((part) => part?.trim().isNotEmpty == true).join(' • '),
          diseaseName: '',
          language: language,
          itemId: plan.itemId,
          dosage: plan.dose,
          foodTiming: plan.foodTiming,
          scheduledDate:
              '${occurrence.year.toString().padLeft(4, '0')}-'
              '${occurrence.month.toString().padLeft(2, '0')}-'
              '${occurrence.day.toString().padLeft(2, '0')}',
          timeSlot:
              '${occurrence.hour.toString().padLeft(2, '0')}:'
              '${occurrence.minute.toString().padLeft(2, '0')}',
        );
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime(
            tz.local,
            occurrence.year,
            occurrence.month,
            occurrence.day,
            occurrence.hour,
            occurrence.minute,
          ),
          _buildMedicineNotificationDetails(title: title, body: body),
          androidScheduleMode: mode,
          payload: jsonEncode(content.toJson()),
        );
        ids.add(id);
      }
    } catch (_) {
      for (final id in ids) {
        await _plugin.cancel(id);
      }
      rethrow;
    }
    await _storage.write(key: idsKey, value: ids.join(','));
    await _storage.write(key: _signatureKey(plan), value: signature);
    return ids.length;
  }

  Future<int> enableMedicinePlan(
    MedicineReminderPlan plan, {
    required String patientName,
    required AppLanguage language,
  }) async {
    if (!await requestPermissions()) {
      throw StateError('Notifications are disabled for Saathi on this phone.');
    }
    if (plan.endDate.isBefore(
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    )) {
      throw StateError('This medicine course has already ended.');
    }
    final plans = await _readPlans();
    final count = await _schedulePlan(
      plan,
      patientName: patientName,
      language: language,
      force: true,
    );
    plans.removeWhere(
      (existing) =>
          existing.patientId == plan.patientId &&
          existing.sourceKey == plan.sourceKey,
    );
    plans.add(plan);
    await _savePlans(plans);
    return count;
  }

  Future<int> syncPrescriptionReminders({
    required Patient patient,
    required int prescriptionId,
    required String diseaseName,
    required List<PrescriptionItem> items,
    required AppLanguage language,
  }) async {
    var count = 0;
    for (final item in items) {
      final plan = MedicineReminderPlan.fromDoctor(
        patientId: patient.id,
        prescriptionId: prescriptionId,
        item: item,
        times: parseExplicitTimes(item),
      );
      if (plan != null) {
        count += await enableMedicinePlan(
          plan,
          patientName: patient.name,
          language: language,
        );
      }
    }
    return count;
  }

  Future<bool> isMedicineEnabled(int patientId, String sourceKey) async =>
      (await _readPlans()).any(
        (plan) => plan.patientId == patientId && plan.sourceKey == sourceKey,
      );

  Future<void> reconcileDoctorPlans({
    required Patient patient,
    required List<ClinicalVisit> visits,
    required AppLanguage language,
  }) async {
    final plans = await _readPlans();
    final current = <String, MedicineReminderPlan>{};
    for (final visit in visits) {
      final prescription = visit.prescription;
      if (prescription == null) continue;
      for (final item in prescription.items) {
        final plan = MedicineReminderPlan.fromDoctor(
          patientId: patient.id,
          prescriptionId: prescription.id,
          item: item,
          times: parseExplicitTimes(item),
        );
        if (plan != null) current[plan.sourceKey] = plan;
      }
    }
    var changed = false;
    for (final old in plans.toList()) {
      if (old.patientId != patient.id || !old.sourceKey.startsWith('doctor:')) {
        continue;
      }
      final replacement = current[old.sourceKey];
      if (replacement == null ||
          replacement.endDate.isBefore(DateUtils.dateOnly(DateTime.now()))) {
        await _cancelPlan(old);
        plans.remove(old);
        changed = true;
        continue;
      }
      await _schedulePlan(
        replacement,
        patientName: patient.name,
        language: language,
      );
      if (replacement.signature != old.signature) {
        plans[plans.indexOf(old)] = replacement;
        changed = true;
      }
    }
    if (changed) await _savePlans(plans);
  }

  Future<void> reconcileReportPlans({
    required Patient patient,
    required List<Map<String, dynamic>> reports,
    required AppLanguage language,
  }) async {
    final plans = await _readPlans();
    final existing = <String, Map>{};
    for (final report in reports) {
      final reportId = report['report_id'];
      final data = report['structured_data'];
      final medicines = data is Map ? data['medicines'] : null;
      if (reportId is! int || medicines is! List) continue;
      for (var index = 0; index < medicines.length; index++) {
        if (medicines[index] is Map) {
          existing['pdf:$reportId:$index'] = medicines[index] as Map;
        }
      }
    }
    var changed = false;
    for (final old in plans.toList()) {
      if (old.patientId != patient.id || !old.sourceKey.startsWith('pdf:')) {
        continue;
      }
      final medicine = existing[old.sourceKey];
      final parts = old.sourceKey.split(':');
      final replacement = medicine == null
          ? null
          : MedicineReminderPlan.fromReport(
              patientId: patient.id,
              reportId: int.parse(parts[1]),
              medicineIndex: int.parse(parts[2]),
              medicine: medicine,
              times: old.times,
            );
      if (replacement == null ||
          replacement.endDate.isBefore(DateUtils.dateOnly(DateTime.now()))) {
        await _cancelPlan(old);
        plans.remove(old);
        changed = true;
        continue;
      }
      await _schedulePlan(
        replacement,
        patientName: patient.name,
        language: language,
      );
      if (replacement.signature != old.signature) {
        plans[plans.indexOf(old)] = replacement;
        changed = true;
      }
    }
    if (changed) await _savePlans(plans);
  }

  Future<void> cancelPatientReminders(int patientId) async {
    await init();
    final plans = await _readPlans();
    for (final plan in plans.where((p) => p.patientId == patientId)) {
      await _cancelPlan(plan);
    }
    plans.removeWhere((plan) => plan.patientId == patientId);
    await _savePlans(plans);
    final followupKey = _followupIdsKey(patientId);
    for (final raw in (await _storage.read(key: followupKey) ?? '').split(
      ',',
    )) {
      final id = int.tryParse(raw);
      if (id != null) await _plugin.cancel(id);
    }
    await _storage.delete(key: followupKey);
    final snoozeKey = _snoozeIdsKey(patientId);
    for (final raw in (await _storage.read(key: snoozeKey) ?? '').split(',')) {
      final id = int.tryParse(raw);
      if (id != null) await _plugin.cancel(id);
    }
    await _storage.delete(key: snoozeKey);
  }

  /// A generic delivery check. It never creates a medicine or adherence event.
  Future<void> scheduleTestNotification() async {
    if (!await requestPermissions()) {
      throw StateError('Notifications are disabled for Saathi on this phone.');
    }
    await _plugin.cancel(_testNotificationId);
    await _plugin.zonedSchedule(
      _testNotificationId,
      'Saathi test notification',
      'Your phone can receive Saathi reminders.',
      tz.TZDateTime.now(tz.local).add(const Duration(seconds: 30)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Medicine reminders',
          channelDescription: 'Patient-confirmed medicine reminders',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.private,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: await _scheduleMode(),
      payload: _demoPayload,
    );
  }

  Future<void> recordReminderAction(
    ReminderContent content,
    String status,
  ) async {
    if (status != 'taken' && status != 'skipped') {
      throw ArgumentError.value(status, 'status');
    }
    final patientId = content.patientId;
    final sourceKey = content.sourceKey;
    final date = content.scheduledDate;
    final slot = content.timeSlot;
    if (patientId == null ||
        sourceKey == null ||
        date == null ||
        slot == null) {
      throw StateError('This reminder has no saved schedule to update.');
    }
    if (content.itemId != null && sourceKey.startsWith('doctor:')) {
      final callback = onAdherenceAction;
      if (callback == null) throw StateError('Patient session is not ready.');
      await callback(content.itemId!, status, date, slot);
    }
    final key = 'local_reminder_history_$patientId';
    final raw = await _storage.read(key: key);
    final history = raw == null
        ? <Map<String, dynamic>>[]
        : (jsonDecode(raw) as List)
              .whereType<Map>()
              .map((entry) => Map<String, dynamic>.from(entry))
              .toList();
    history.removeWhere(
      (entry) =>
          entry['sourceKey'] == sourceKey &&
          entry['scheduledDate'] == date &&
          entry['timeSlot'] == slot,
    );
    history.insert(0, {
      'sourceKey': sourceKey,
      'medicineName': content.medicineName,
      'scheduledDate': date,
      'timeSlot': slot,
      'status': status,
      'recordedAt': DateTime.now().toIso8601String(),
    });
    await _storage.write(
      key: key,
      value: jsonEncode(history.take(100).toList()),
    );
  }

  Future<List<Map<String, dynamic>>> reminderHistory(int patientId) async {
    final raw = await _storage.read(key: 'local_reminder_history_$patientId');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Snoozes an active reminder for [minutes] (default 10 minutes).
  Future<void> snoozeMedicineReminder(
    ReminderContent content, {
    int minutes = 10,
  }) async {
    await init();
    final id = stableNotificationId(
      '${content.patientId}:${content.sourceKey}:${content.scheduledDate}:'
      '${content.timeSlot}:snooze',
      prefix: 0x50000000,
    );
    final when = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));
    final title = '💊 Medicine reminder (snoozed)';
    final body = [
      content.medicineName,
      content.dosage,
      content.foodTiming,
    ].where((part) => part?.trim().isNotEmpty == true).join(' · ');
    final details = _buildMedicineNotificationDetails(title: title, body: body);
    final payload = jsonEncode(content.toJson());

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      details,
      androidScheduleMode: await _scheduleMode(),
      payload: payload,
    );
    if (content.patientId != null) {
      final key = _snoozeIdsKey(content.patientId!);
      final ids = (await _storage.read(key: key) ?? '')
          .split(',')
          .map(int.tryParse)
          .whereType<int>()
          .toSet();
      ids.add(id);
      await _storage.write(key: key, value: ids.join(','));
    }
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
        androidScheduleMode: await _scheduleMode(),
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
    this.patientId,
    this.sourceKey,
    required this.medicineName,
    required this.instruction,
    required this.diseaseName,
    required this.language,
    this.itemId,
    this.timeLabel,
    this.dosage,
    this.foodTiming,
    this.scheduledDate,
    this.timeSlot,
  });

  final String patientName;
  final int? patientId;
  final String? sourceKey;
  final String medicineName;
  final String instruction;
  final String diseaseName;
  final AppLanguage language;
  final int? itemId;
  final String? timeLabel;
  final String? dosage;
  final String? foodTiming;
  final String? scheduledDate;
  final String? timeSlot;

  Map<String, dynamic> toJson() => {
    'patientName': patientName,
    if (patientId != null) 'patientId': patientId,
    if (sourceKey != null) 'sourceKey': sourceKey,
    'medicineName': medicineName,
    'instruction': instruction,
    'diseaseName': diseaseName,
    'language': language.code,
    if (itemId != null) 'itemId': itemId,
    if (timeLabel != null) 'timeLabel': timeLabel,
    if (dosage != null) 'dosage': dosage,
    if (foodTiming != null) 'foodTiming': foodTiming,
    if (scheduledDate != null) 'scheduledDate': scheduledDate,
    if (timeSlot != null) 'timeSlot': timeSlot,
  };

  factory ReminderContent.fromJson(Map<String, dynamic> json) =>
      ReminderContent(
        patientName: json['patientName']?.toString() ?? '',
        patientId: json['patientId'] as int?,
        sourceKey: json['sourceKey']?.toString(),
        medicineName: json['medicineName']?.toString() ?? '',
        instruction: json['instruction']?.toString() ?? '',
        diseaseName: json['diseaseName']?.toString() ?? '',
        language: AppLanguage.fromCode(json['language']?.toString()),
        itemId: json['itemId'] as int?,
        timeLabel: json['timeLabel']?.toString(),
        dosage: json['dosage']?.toString(),
        foodTiming: json['foodTiming']?.toString(),
        scheduledDate: json['scheduledDate']?.toString(),
        timeSlot: json['timeSlot']?.toString(),
      );
}
