import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../app_controller.dart';
import '../l10n/app_text.dart';
import '../models.dart';
import '../services/reminder_service.dart';
import '../services/reminder_plan.dart';
import '../theme.dart';
import '../widgets/patient_scaffold.dart';
import '../widgets/patient_widgets.dart';

/// MEDICINE REMINDERS screen — shows the current prescription's items using
/// real data from the FastAPI backend and provides interactive adherence logging.
class MedicineRemindersScreen extends StatefulWidget {
  const MedicineRemindersScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<MedicineRemindersScreen> createState() =>
      _MedicineRemindersScreenState();
}

class _MedicineRemindersScreenState extends State<MedicineRemindersScreen> {
  late Future<List<ClinicalVisit>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _recordsFuture = widget.controller.fetchClinicalVisits();
  }

  void _retry() => setState(_load);

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final colors = context.saathiColors;

    return PatientScaffold(
      title: text(T.dashboardMedicineReminders),
      controller: widget.controller,
      body: FutureBuilder<List<ClinicalVisit>>(
        future: _recordsFuture,
        builder: (context, snapshot) {
          // ── Loading ──────────────────────────────────────────────────────
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: colors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Loading medicines…',
                    style: TextStyle(color: colors.textMuted, fontSize: 15),
                  ),
                ],
              ),
            );
          }

          // ── Error ────────────────────────────────────────────────────────
          if (snapshot.hasError) {
            final err = snapshot.error;
            final msg = err is ApiException
                ? err.message
                : 'Unable to load medicine information.';
            return PatientStateView(
              icon: Icons.cloud_off_rounded,
              tone: colors.emergency,
              title: 'Unable to load medicines',
              body: msg,
              actionLabel: 'Retry',
              onAction: _retry,
            );
          }

          final records = snapshot.data ?? [];
          // Find the most recent visit that has a prescription with items
          final withPrescription = records
              .where(
                (cv) =>
                    cv.prescription != null &&
                    cv.prescription!.items.isNotEmpty,
              )
              .toList();

          // ── Empty ────────────────────────────────────────────────────────
          if (withPrescription.isEmpty) {
            return PatientStateView(
              icon: Icons.medication_outlined,
              tone: colors.info,
              title: 'No Active Prescription',
              body:
                  'No medicines have been prescribed for you yet. '
                  'Visit your doctor to receive a prescription.',
            );
          }

          final latest = withPrescription.first;
          final prescription = latest.prescription!;
          final locale = text.language.code;
          final visitDate = DateTime.tryParse(latest.visit.visitDate ?? '');

          // ── Data ─────────────────────────────────────────────────────────
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              ClinicalDisclaimerCard(colors: colors),

              // Prescription header
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.medication_rounded,
                          color: colors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Current Prescription',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: colors.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (latest.diagnosis != null &&
                        latest.diagnosis!.isNotEmpty) ...[
                      Text(
                        latest.diagnosis!,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (latest.doctorName != null) ...[
                      Text(
                        'Prescribed by ${latest.doctorName}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    if (visitDate != null)
                      Text(
                        'Date: ${DateFormat.yMMMd(locale).format(visitDate)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Notification status & pop-up test banner
              _NotificationStatusBanner(
                colors: colors,
                controller: widget.controller,
                prescription: prescription,
                diagnosis: latest.diagnosis,
              ),
              const SizedBox(height: 16),

              // Medicine count
              Text(
                '${prescription.items.length} '
                '${prescription.items.length == 1 ? 'medicine' : 'medicines'} prescribed',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 10),

              // Medicine cards
              for (final item in prescription.items)
                _MedicineCard(
                  item: item,
                  colors: colors,
                  controller: widget.controller,
                ),
            ],
          );
        },
      ),
    );
  }
}

class ClinicalDisclaimerCard extends StatelessWidget {
  const ClinicalDisclaimerCard({super.key, required this.colors});
  final SaathiColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.infoTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.info.withValues(alpha: .3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: colors.info, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Clinical Disclaimer: Medication schedules and dosages are based on your doctor\'s prescription. Take all medications exactly as directed. Consult your physician before changing any dose.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.info,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicineCard extends StatefulWidget {
  const _MedicineCard({
    required this.item,
    required this.colors,
    required this.controller,
  });

  final PrescriptionItem item;
  final SaathiColors colors;
  final AppController controller;

  @override
  State<_MedicineCard> createState() => _MedicineCardState();
}

class _MedicineCardState extends State<_MedicineCard> {
  String? _status; // 'taken', 'snoozed', 'skipped'
  bool _isSaving = false;

  Future<void> _updateStatus(String nextStatus) async {
    setState(() {
      _isSaving = true;
    });

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final hour = DateTime.now().hour;
    final currentSlot = hour < 11
        ? 'morning'
        : hour < 16
        ? 'afternoon'
        : hour < 20
        ? 'evening'
        : 'night';
    try {
      await widget.controller.recordAdherence(
        prescriptionItemId: widget.item.itemId,
        scheduledDate: today,
        timeSlot: currentSlot,
        status: nextStatus,
      );
      if (mounted) {
        setState(() {
          _status = nextStatus;
          _isSaving = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save medicine status: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final item = widget.item;
    final scheduledTimes = ReminderService.parseExplicitTimes(item);

    Color badgeColor = colors.primaryTint;
    Color textColor = colors.text;
    String badgeText = item.medicineType ?? 'MEDICINE';

    if (_status == 'taken') {
      badgeColor = colors.primaryTint;
      textColor = colors.primary;
      badgeText = 'TAKEN ✓';
    } else if (_status == 'snoozed') {
      badgeColor = colors.emergencyTint;
      textColor = colors.emergency;
      badgeText = 'SNOOZED';
    } else if (_status == 'skipped') {
      badgeColor = colors.line;
      textColor = colors.textMuted;
      badgeText = 'SKIPPED';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.line),
        boxShadow: softCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Medicine name + strength
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primaryTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.medication_rounded,
                  color: colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: colors.text,
                      ),
                    ),
                    if (item.strength != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        item.strength!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Detail rows
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              if (item.dosage != null)
                _DetailBadge(
                  icon: Icons.format_list_numbered_rounded,
                  label: 'Dose',
                  value: item.dosage!,
                  colors: colors,
                ),
              if (item.frequency != null)
                _DetailBadge(
                  icon: Icons.schedule_rounded,
                  label: 'Frequency',
                  value: item.frequency!,
                  colors: colors,
                ),
              if (item.durationDays != null)
                _DetailBadge(
                  icon: Icons.date_range_rounded,
                  label: 'Duration',
                  value: '${item.durationDays} days',
                  colors: colors,
                ),
              if (item.foodTiming != null)
                _DetailBadge(
                  icon: Icons.restaurant_rounded,
                  label: 'Food',
                  value: item.foodTiming!,
                  colors: colors,
                ),
            ],
          ),

          // Instructions
          if (item.instructions != null && item.instructions!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primaryTint.withValues(alpha: .6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: colors.primary,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.instructions!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (scheduledTimes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colors.primaryTint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.alarm_on_rounded, color: colors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Daily Pop-up Alarm: ${scheduledTimes.map(ReminderService.formatTimeOfDay).join(", ")}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (item.startDate != null || item.endDate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Prescription dates: ${item.startDate ?? 'not recorded'} to ${item.endDate ?? 'not recorded'}',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
          ],
          const SizedBox(height: 12),
          // Action Buttons: Taken, Snooze, Skip
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : () => _updateStatus('taken'),
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                  ),
                  label: const Text('Taken'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : () => _updateStatus('snoozed'),
                  icon: const Icon(Icons.snooze_rounded, size: 16),
                  label: const Text('Snooze'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.emergency,
                    side: BorderSide(color: colors.emergency),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : () => _updateStatus('skipped'),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Skip'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textMuted,
                    side: BorderSide(color: colors.line),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailBadge extends StatelessWidget {
  const _DetailBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
  });
  final IconData icon;
  final String label;
  final String value;
  final SaathiColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.primaryTint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.primary, size: 14),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: colors.textMuted,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colors.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationStatusBanner extends StatelessWidget {
  const _NotificationStatusBanner({
    required this.colors,
    required this.controller,
    required this.prescription,
    this.diagnosis,
  });

  final SaathiColors colors;
  final AppController controller;
  final PatientPrescription prescription;
  final String? diagnosis;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
        boxShadow: softCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: colors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medicine reminder times',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: colors.text,
                      ),
                    ),
                    Text(
                      'Review exact times before turning on reminders',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Reminders are only available for clock times written in the prescription. As-needed medicines do not get daily reminders.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.textMuted,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Review and turn on reminders'),
            onPressed: () async {
              final patient = controller.patient;
              if (patient == null) return;
              final exact = prescription.items
                  .map(
                    (item) => (item, ReminderService.parseExplicitTimes(item)),
                  )
                  .where(
                    (entry) =>
                        MedicineReminderPlan.fromDoctor(
                          patientId: patient.id,
                          prescriptionId: prescription.id,
                          item: entry.$1,
                          times: entry.$2,
                        ) !=
                        null,
                  )
                  .toList();
              if (exact.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'A fixed reminder needs documented clock times and start/end dates. Please confirm missing details with your doctor or pharmacist.',
                    ),
                  ),
                );
                return;
              }
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Confirm reminder times'),
                  content: SingleChildScrollView(
                    child: Text(
                      exact
                          .map(
                            (entry) =>
                                '${entry.$1.name}: ${entry.$2.map(ReminderService.formatTimeOfDay).join(', ')} · ${entry.$1.startDate} – ${entry.$1.endDate}',
                          )
                          .join('\n'),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Turn on'),
                    ),
                  ],
                ),
              );
              if (confirmed != true || !context.mounted) return;
              try {
                final count = await ReminderService.instance
                    .syncPrescriptionReminders(
                      patient: patient,
                      prescriptionId: prescription.id,
                      diseaseName: diagnosis ?? patient.condition,
                      items: prescription.items,
                      language: controller.language,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$count reminder times activated.')),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not activate reminders: $error'),
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await ReminderService.instance.scheduleTestNotification();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Test notification scheduled in 30 seconds.',
                      ),
                    ),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not schedule test: $error')),
                  );
                }
              }
            },
            icon: const Icon(Icons.timer_rounded),
            label: const Text('Test notification in 30 seconds'),
          ),
        ],
      ),
    );
  }
}
