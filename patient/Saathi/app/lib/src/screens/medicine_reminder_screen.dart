import 'package:flutter/material.dart';

import '../l10n/app_text.dart';
import '../services/reminder_service.dart';
import '../theme.dart';

/// Medicine-time reminder screen.
///
/// This is what opens when the patient taps the medicine reminder
/// notification, or right after it fires while the app is open. The brief
/// asks the notification to speak three things — patient name, medicine name,
/// local disease name — and this screen visually repeats the same three, in
/// that order, in large type, so a patient who missed part of what was said
/// (or cannot hear well) still gets the full message by reading it.
class MedicineReminderScreen extends StatefulWidget {
  const MedicineReminderScreen({super.key, required this.content});
  final ReminderContent content;

  @override
  State<MedicineReminderScreen> createState() => _MedicineReminderScreenState();
}

enum _TakenState { pending, confirmed, skipped }

class _MedicineReminderScreenState extends State<MedicineReminderScreen> {
  var taken = _TakenState.pending;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final content = widget.content;
    final colors = context.saathiColors;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: colors.primaryTint,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: scaledIcon(context, 84),
                    height: scaledIcon(context, 84),
                    decoration: BoxDecoration(
                      color: colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.alarm_rounded,
                      color: saathiInk,
                      size: scaledIcon(context, 44),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  text(T.reminderTitle),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colors.textMuted,
                    letterSpacing: .5,
                  ),
                ),
                const SizedBox(height: 6),
                // 1. Patient name — spoken first, shown first.
                Text(
                  content.patientName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: colors.text,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text(T.reminderItIsTimeFor),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 26),
                // 2. Medicine name.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.primary, width: 2),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: colors.primaryTint,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.medication_rounded,
                          color: colors.primary,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        content.medicineName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        content.instruction,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 3. Local / familiar disease name.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: colors.infoTint,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.info.withValues(alpha: .5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.monitor_heart_rounded, color: colors.info),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          '${text(T.reminderYourMedicineFor)} '
                          '${content.diseaseName}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: colors.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                if (taken == _TakenState.confirmed)
                  _ConfirmedBanner(text: text(T.reminderTakenConfirm))
                else if (taken == _TakenState.skipped)
                  const _ConfirmedBanner(text: 'Skipped and recorded')
                else ...[
                  FilledButton.icon(
                    onPressed: () async {
                      try {
                        await ReminderService.instance.recordReminderAction(
                          content,
                          'taken',
                        );
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not record dose: $error'),
                            ),
                          );
                        }
                        return;
                      }
                      ReminderService.instance.stopSpeaking();
                      if (mounted) {
                        setState(() => taken = _TakenState.confirmed);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primaryStrong,
                      minimumSize: const Size.fromHeight(78),
                      textStyle: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 26),
                    label: Text(text(T.reminderTaken)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await ReminderService.instance.snoozeMedicineReminder(
                          content,
                        );
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not snooze: $error')),
                          );
                        }
                        return;
                      }
                      ReminderService.instance.stopSpeaking();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: colors.surface,
                      minimumSize: const Size.fromHeight(68),
                    ),
                    icon: const Icon(Icons.snooze_rounded),
                    label: Text(text(T.reminderSnooze)),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () async {
                      try {
                        await ReminderService.instance.recordReminderAction(
                          content,
                          'skipped',
                        );
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not record skip: $error'),
                            ),
                          );
                        }
                        return;
                      }
                      ReminderService.instance.stopSpeaking();
                      if (mounted) setState(() => taken = _TakenState.skipped);
                    },
                    icon: const Icon(Icons.not_interested_rounded),
                    label: const Text('Skip this dose'),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => ReminderService.instance.speak(content),
                    icon: Icon(Icons.volume_up_rounded, color: colors.info),
                    label: Text(
                      text(T.reminderHearAgain),
                      style: TextStyle(
                        color: colors.info,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmedBanner extends StatelessWidget {
  const _ConfirmedBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryStrong,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
