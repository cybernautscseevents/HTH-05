import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../app_controller.dart';
import '../api_client.dart';
import '../l10n/app_text.dart';
import '../models.dart';
import '../services/reminder_service.dart';
import '../services/reminder_plan.dart';
import '../theme.dart';
import '../widgets/patient_scaffold.dart';
import '../widgets/patient_widgets.dart';

/// NEXT APPOINTMENT screen.
///
/// Displays the real doctor-assigned upcoming appointment or a calm empty
/// state if no upcoming appointment has been scheduled by the doctor.
class NextAppointmentScreen extends StatefulWidget {
  const NextAppointmentScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<NextAppointmentScreen> createState() => _NextAppointmentScreenState();
}

class _NextAppointmentScreenState extends State<NextAppointmentScreen> {
  AppController get controller => widget.controller;
  final _followupsKey = GlobalKey<_ReportFollowupsState>();
  Object? _appointmentError;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    _followupsKey.currentState?.reload();
    try {
      await controller.fetchNextAppointment();
      if (mounted) setState(() => _appointmentError = null);
    } catch (error) {
      if (mounted) setState(() => _appointmentError = error);
    }
  }

  Widget _appointmentErrorBanner() => ListTile(
    leading: const Icon(Icons.cloud_off_rounded),
    title: const Text('Booked appointments could not be loaded.'),
    subtitle: Text(_appointmentError.toString()),
    trailing: TextButton(onPressed: _refresh, child: const Text('Retry')),
  );

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final locale = text.language.code;
    final colors = context.saathiColors;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final appt = controller.nextAppointment;

        return PatientScaffold(
          title: text(T.appointmentTitle),
          controller: controller,
          body: RefreshIndicator(
            color: colors.primaryStrong,
            onRefresh: _refresh,
            child: appt == null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _ReportFollowups(
                        key: _followupsKey,
                        controller: controller,
                      ),
                      if (_appointmentError != null) _appointmentErrorBanner(),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.2,
                      ),
                      PatientStateView(
                        icon: Icons.event_busy_rounded,
                        tone: colors.info,
                        title: text(T.appointmentNobooked),
                        body: text(T.appointmentNoBookedBody),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _ReportFollowups(
                        key: _followupsKey,
                        controller: controller,
                      ),
                      if (_appointmentError != null) _appointmentErrorBanner(),
                      Container(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.line),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Teal hero header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF087FA8),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(15),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.event_available_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      text(T.appointmentUpcoming),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      appt.status.toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF17617D),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                20,
                                18,
                                18,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Date & Time
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: colors.primaryTint,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.calendar_today_rounded,
                                          color: colors.primaryStrong,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              DateFormat(
                                                'EEEE,\nd MMMM yyyy',
                                                locale,
                                              ).format(appt.date),
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: colors.text,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.schedule_rounded,
                                                  color: colors.primaryStrong,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  DateFormat(
                                                    'hh:mm a',
                                                    locale,
                                                  ).format(appt.date),
                                                  style: TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w600,
                                                    color: colors.primaryStrong,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Divider(color: colors.line, height: 1),
                                  const SizedBox(height: 16),

                                  // Doctor
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0x1A2196F3),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.person_rounded,
                                          color: Colors.blue,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Dr. ${appt.doctorName}',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: colors.text,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              appt.department,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: colors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Divider(color: colors.line, height: 1),
                                  const SizedBox(height: 18),

                                  // Hospital
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0x1A009688),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.local_hospital_rounded,
                                          color: Colors.teal,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          appt.hospitalName,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: colors.text,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (appt.reason != null &&
                                      appt.reason!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 18),
                                    Divider(color: colors.line, height: 1),
                                    const SizedBox(height: 14),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: colors.primaryTint,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: colors.line),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.assignment_rounded,
                                            color: colors.primaryStrong,
                                            size: 28,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  text(
                                                    T.appointmentReasonForVisit,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: colors.textMuted,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  appt.reason!,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: colors.text,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  if (appt.notes != null &&
                                      appt.notes!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: colors.primaryTint,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: colors.line),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.info_outline_rounded,
                                            color: colors.primaryStrong,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  text(T.appointmentNote),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: colors.primaryStrong,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  appt.notes!,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: colors.text,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (appt.rescheduleRequest != null) ...[
                        const SizedBox(height: 12),
                        _RescheduleStatusCard(
                          request: appt.rescheduleRequest!,
                          locale: locale,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        text(T.appointmentActions),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _ActionCard(
                        icon: Icons.notifications_none_rounded,
                        label: text(T.appointmentAddReminder),
                        onTap: () => _showReminder(context, appt),
                      ),
                      const SizedBox(height: 12),
                      _ActionCard(
                        icon: Icons.refresh_rounded,
                        label: text(
                          appt.rescheduleRequest?.status == 'pending'
                              ? T.appointmentReschedulePending
                              : T.appointmentRequestReschedule,
                        ),
                        onTap: appt.rescheduleRequest?.status == 'pending'
                            ? null
                            : () => _requestReschedule(context, appt),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Future<void> _showReminder(
    BuildContext context,
    PatientAppointment appt,
  ) async {
    final text = AppText.of(context);
    var selectedOffset = 60;
    final offset = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(text(T.appointmentRemindMe)),
          content: RadioGroup<int>(
            groupValue: selectedOffset,
            onChanged: (value) => setState(() => selectedOffset = value ?? 60),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ReminderOption(1440, text(T.appointmentOneDayBefore)),
                _ReminderOption(120, text(T.appointmentTwoHoursBefore)),
                _ReminderOption(60, text(T.appointmentOneHourBefore)),
                _ReminderOption(30, text(T.appointmentThirtyMinutesBefore)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selectedOffset),
              child: Text(text(T.appointmentSaveReminder)),
            ),
          ],
        ),
      ),
    );
    if (offset == null || !context.mounted) return;
    try {
      final updated = await ReminderService.instance.scheduleAppointment(
        appointmentId: appt.appointmentId,
        appointmentTime: appt.date,
        offsetMinutes: offset,
        title: text(T.appointmentUpcoming),
        body: 'Dr. ${appt.doctorName} • ${appt.hospitalName}',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              text(
                updated
                    ? T.appointmentReminderUpdated
                    : T.appointmentReminderAdded,
              ),
            ),
          ),
        );
      }
    } on StateError {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text(T.appointmentReminderPassed))),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text(T.appointmentReminderFailed))),
        );
      }
    }
  }

  Future<void> _requestReschedule(
    BuildContext context,
    PatientAppointment appt,
  ) async {
    final text = AppText.of(context);
    final locale = text.language.code;
    final colors = context.saathiColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogTextColor = isDark ? Colors.white : colors.text;
    final dialogSecondaryColor = isDark ? Colors.white70 : colors.textMuted;
    DateTime selected = appt.date.add(const Duration(days: 1));
    final reason = TextEditingController();
    var recognizedBase = '';
    final speech = stt.SpeechToText();
    var listening = false;
    var available = true;
    final send = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            text(T.appointmentRequestReschedule),
            style: TextStyle(color: dialogTextColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${text(T.appointmentCurrent)}: ${DateFormat.yMMMd(locale).add_jm().format(appt.date)}',
                style: TextStyle(color: dialogTextColor),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  text(T.appointmentPreferredDate),
                  style: TextStyle(color: dialogTextColor),
                ),
                subtitle: Text(
                  DateFormat.yMMMd(locale).add_jm().format(selected),
                  style: TextStyle(color: dialogSecondaryColor),
                ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: dialogContext,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDate: selected,
                  );
                  if (d == null || !dialogContext.mounted) return;
                  final tm = await showTimePicker(
                    context: dialogContext,
                    initialTime: TimeOfDay.fromDateTime(selected),
                    helpText: text(T.appointmentPreferredTime),
                  );
                  if (tm != null) {
                    setState(() {
                      selected = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        tm.hour,
                        tm.minute,
                      );
                    });
                  }
                },
              ),
              TextField(
                controller: reason,
                decoration: InputDecoration(
                  labelText:
                      '${text(T.appointmentReason)} (${text(T.appointmentOptional)})',
                  filled: true,
                  fillColor: colors.primaryTint,
                  labelStyle: TextStyle(color: colors.textMuted),
                  hintStyle: TextStyle(color: colors.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.line),
                  ),
                  suffixIcon: Semantics(
                    button: true,
                    label: 'Speak reason',
                    child: IconButton(
                      tooltip: listening ? 'Stop listening' : 'Speak reason',
                      icon: Icon(
                        listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      ),
                      color: listening ? Colors.red : colors.textMuted,
                      style: IconButton.styleFrom(
                        backgroundColor: listening
                            ? Colors.red.withValues(alpha: 0.12)
                            : null,
                        shape: const CircleBorder(),
                      ),
                      onPressed: !available
                          ? null
                          : () async {
                              if (listening) {
                                await speech.stop();
                                setState(() => listening = false);
                                return;
                              }
                              final ok = await speech.initialize(
                                onStatus: (status) {
                                  if ((status == 'done' ||
                                          status == 'notListening') &&
                                      dialogContext.mounted) {
                                    setState(() => listening = false);
                                  }
                                },
                                onError: (_) {
                                  if (dialogContext.mounted) {
                                    setState(() => listening = false);
                                  }
                                },
                              );
                              if (!ok || !dialogContext.mounted) {
                                setState(() => available = false);
                                return;
                              }
                              final lang = switch (AppText.of(
                                dialogContext,
                              ).language.code) {
                                'hi' => 'hi-IN',
                                'kn' => 'kn-IN',
                                _ => 'en-IN',
                              };
                              recognizedBase = reason.text.trim();
                              await speech.listen(
                                listenOptions: stt.SpeechListenOptions(
                                  localeId: lang,
                                ),
                                onResult: (result) {
                                  if (!dialogContext.mounted) return;
                                  final value = result.recognizedWords.trim();
                                  if (value.isNotEmpty) {
                                    final prefix = recognizedBase.isEmpty
                                        ? ''
                                        : '$recognizedBase ';
                                    reason.value = reason.value.copyWith(
                                      text: '$prefix$value',
                                      selection: TextSelection.collapsed(
                                        offset: prefix.length + value.length,
                                      ),
                                    );
                                  }
                                  setState(
                                    () => listening = result.finalResult
                                        ? false
                                        : true,
                                  );
                                },
                              );
                              if (dialogContext.mounted) {
                                setState(() => listening = true);
                              }
                            },
                    ),
                  ),
                ),
                style: TextStyle(color: colors.text),
                cursorColor: colors.primaryStrong,
              ),
              if (listening)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Listening…',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () async {
                await speech.stop();
                if (dialogContext.mounted) Navigator.pop(dialogContext, false);
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 46),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                side: BorderSide(color: isDark ? Colors.white54 : colors.line),
                foregroundColor: dialogTextColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                MaterialLocalizations.of(context).cancelButtonLabel,
                style: TextStyle(color: dialogTextColor),
              ),
            ),
            FilledButton(
              onPressed: () async {
                await speech.stop();
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              },
              child: Text(text(T.appointmentSendRequest)),
            ),
          ],
        ),
      ),
    );
    if (send != true || !context.mounted) return;
    try {
      await controller.requestAppointmentReschedule(
        appt.appointmentId,
        selected,
        reason.text,
      );
      if (context.mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final dialogPrimary = isDark ? Colors.white : colors.text;
        final dialogSecondary = isDark ? Colors.white70 : colors.textMuted;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: Icon(
              Icons.schedule_send_rounded,
              color: isDark ? Colors.lightBlueAccent : colors.primaryStrong,
              size: 34,
            ),
            title: Text(
              text(T.appointmentRescheduleSent),
              style: TextStyle(
                color: dialogPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text(T.appointmentReschedulePending),
                  style: TextStyle(
                    color: dialogPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  text(T.appointmentRescheduleWait),
                  style: TextStyle(color: dialogSecondary),
                ),
                const SizedBox(height: 14),
                Text(
                  text(T.appointmentRescheduleUnchanged),
                  style: TextStyle(color: dialogSecondary),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: FilledButton.styleFrom(foregroundColor: Colors.white),
                child: Text(text(T.appointmentOk)),
              ),
            ],
          ),
        );
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              text(
                error.statusCode == 409
                    ? T.appointmentRescheduleAlreadyPending
                    : T.appointmentRescheduleFailed,
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text(T.appointmentRescheduleFailed))),
        );
      }
    }
  }
}

class _ReportFollowups extends StatefulWidget {
  const _ReportFollowups({super.key, required this.controller});
  final AppController controller;

  @override
  State<_ReportFollowups> createState() => _ReportFollowupsState();
}

class _ReportFollowupsState extends State<_ReportFollowups> {
  late Future<List<Map<String, dynamic>>> _reports;

  Future<void> _enableFollowup(
    Map<String, dynamic> report,
    Map item,
    int index,
  ) async {
    final patient = widget.controller.patient;
    final reportId = report['report_id'];
    final date = parseCarePlanDate(item['date']);
    if (patient == null || reportId is! int || date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A documented follow-up date is needed for a reminder.',
          ),
        ),
      );
      return;
    }
    final written = explicitClockTimes(item['time']?.toString() ?? '');
    TimeOfDay? clock = written.isNotEmpty ? written.first : null;
    if (clock == null) {
      clock = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        helpText: 'Choose your personal follow-up reminder time',
      );
      if (clock == null) return;
    }
    final followupTime = DateTime(
      date.year,
      date.month,
      date.day,
      clock.hour,
      clock.minute,
    );
    if (!mounted) return;
    final offset = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recommended follow-up — not booked'),
        content: Text(
          'Follow-up: ${item['purpose'] ?? 'Review'}\n'
          'Date: ${item['date']} · ${ReminderService.formatTimeOfDay(clock!)}\n'
          'Choose when Saathi should remind you. Contact the clinic to book.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 1440),
            child: const Text('1 day before'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 60),
            child: const Text('1 hour before'),
          ),
        ],
      ),
    );
    if (offset == null) return;
    try {
      await ReminderService.instance.scheduleRecommendedFollowup(
        patientId: patient.id,
        reportId: reportId,
        followupIndex: index,
        reminderTime: followupTime.subtract(Duration(minutes: offset)),
        description: item['purpose']?.toString() ?? 'Follow-up review',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Personal follow-up reminder scheduled on this phone.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not set follow-up reminder: $error')),
        );
      }
    }
  }

  void reload() => setState(() {
    _reports = widget.controller.fetchDischargeReports();
  });

  @override
  void initState() {
    super.initState();
    _reports = widget.controller.fetchDischargeReports();
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _reports,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const ListTile(title: Text('Loading recommended follow-ups…'));
      }
      if (snapshot.hasError) {
        return ListTile(
          title: const Text('Recommended follow-ups could not be loaded.'),
          subtitle: Text(snapshot.error.toString()),
          trailing: TextButton(onPressed: reload, child: const Text('Retry')),
        );
      }
      final reports = snapshot.data ?? const <Map<String, dynamic>>[];
      final followups = <(Map<String, dynamic>, Map, int)>[];
      for (final report in reports) {
        final data = report['structured_data'];
        final items = data is Map ? data['follow_up'] : null;
        if (items is List) {
          for (var index = 0; index < items.length; index++) {
            final item = items[index];
            if (item is! Map) continue;
            if (item.values.any(
              (value) => value != null && value.toString().trim().isNotEmpty,
            )) {
              followups.add((report, item, index));
            }
          }
        }
      }
      if (followups.isEmpty) return const SizedBox.shrink();
      final colors = context.saathiColors;
      return Card(
        color: colors.surface,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Follow-up mentioned in discharge reports',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'These are report instructions; they do not confirm a hospital appointment is booked.',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
              for (final entry in followups) ...[
                const Divider(height: 16),
                Text(
                  (entry.$2.values
                      .where((v) => v != null && v.toString().trim().isNotEmpty)
                      .join(' · ')),
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Source: ${entry.$1['hospital_name'] ?? entry.$1['original_filename']}',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
                TextButton.icon(
                  onPressed: () =>
                      _enableFollowup(entry.$1, entry.$2, entry.$3),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Set personal follow-up reminder'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _ReminderOption extends StatelessWidget {
  const _ReminderOption(this.value, this.label);

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => RadioListTile<int>(
    value: value,
    title: Text(label),
    contentPadding: EdgeInsets.zero,
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    final disabled = onTap == null;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120B6FA4),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: disabled ? colors.textMuted : colors.primaryStrong,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: disabled ? colors.textMuted : colors.text,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: disabled ? colors.textMuted : colors.primaryStrong,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RescheduleStatusCard extends StatelessWidget {
  const _RescheduleStatusCard({required this.request, required this.locale});

  final PatientAppointmentReschedule request;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final colors = context.saathiColors;
    final key = switch (request.status) {
      'approved' => T.appointmentRescheduleApproved,
      'rejected' => T.appointmentRescheduleRejected,
      _ => T.appointmentReschedulePending,
    };
    final (icon, accent, background) = switch (request.status) {
      'approved' => (
        Icons.check_rounded,
        const Color(0xFF119B72),
        const Color(0x1A119B72),
      ),
      'rejected' => (
        Icons.close_rounded,
        const Color(0xFFC94B52),
        const Color(0x1AC94B52),
      ),
      _ => (
        Icons.schedule_rounded,
        const Color(0xFFB87818),
        const Color(0x1AB87818),
      ),
    };
    final preferred = DateTime.tryParse(request.preferredDatetime);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text(key),
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (request.status == 'pending' && preferred != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${text(T.appointmentPreferredDate)}: '
                    '${DateFormat.yMMMd(locale).add_jm().format(preferred)}',
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
