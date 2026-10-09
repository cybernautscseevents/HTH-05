import 'package:flutter/material.dart';
import '../api_client.dart';
import '../app_controller.dart';
import '../l10n/app_text.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/patient_scaffold.dart';
import '../widgets/patient_widgets.dart';
import 'medicine_reminders_screen.dart';
import '../services/reminder_plan.dart';
import '../services/reminder_service.dart';

/// MEDICINES SCREEN
///
/// Displays ONLY the patient's assigned medicines in square boxes.
/// Consultations, visit headers, and clinical notes are intentionally omitted.
/// Each square box shows the medicine name, its type badge, and a distinct symbol
/// matching the medicine type (tablet, capsule, syrup, injection, drops, etc.).
class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  late Future<
    ({
      List<ClinicalVisit> visits,
      List<Map<String, dynamic>> reports,
      bool reportLoadFailed,
      bool clinicalLoadFailed,
    })
  >
  _recordsFuture;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _recordsFuture = _loadPatientMedicationData();
  }

  Future<
    ({
      List<ClinicalVisit> visits,
      List<Map<String, dynamic>> reports,
      bool reportLoadFailed,
      bool clinicalLoadFailed,
    })
  >
  _loadPatientMedicationData() async {
    final visitsFuture = widget.controller
        .fetchClinicalVisits()
        .then<(List<ClinicalVisit>, bool)>((value) => (value, false))
        .catchError((Object _) => (<ClinicalVisit>[], true));
    final reportsFuture = widget.controller
        .fetchDischargeReports()
        .then<(List<Map<String, dynamic>>, bool)>((value) => (value, false))
        .catchError((Object _) => (<Map<String, dynamic>>[], true));
    final visits = await visitsFuture;
    final reports = await reportsFuture;
    return (
      visits: visits.$1,
      reports: reports.$1,
      reportLoadFailed: reports.$2,
      clinicalLoadFailed: visits.$2,
    );
  }

  void _retry() => setState(_load);

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final colors = context.saathiColors;

    return PatientScaffold(
      title: text(T.dashboardMedicines),
      controller: widget.controller,
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_load);
          await _recordsFuture;
        },
        color: colors.primary,
        child:
            FutureBuilder<
              ({
                List<ClinicalVisit> visits,
                List<Map<String, dynamic>> reports,
                bool reportLoadFailed,
                bool clinicalLoadFailed,
              })
            >(
              future: _recordsFuture,
              builder: (context, snapshot) {
                // ── Loading ──────────────────────────────────────────────────────
                if (snapshot.connectionState != ConnectionState.done) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: colors.primary),
                        const SizedBox(height: 16),
                        Text(
                          'Loading medicines…',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // ── Error ────────────────────────────────────────────────────────
                if (snapshot.hasError ||
                    (snapshot.data?.clinicalLoadFailed == true &&
                        snapshot.data?.reportLoadFailed == true)) {
                  final err = snapshot.error;
                  final msg = err is ApiException
                      ? err.message
                      : 'Unable to load assigned medicines.';
                  return PatientStateView(
                    icon: Icons.cloud_off_rounded,
                    tone: colors.emergency,
                    title: 'Unable to load medicines',
                    body: msg,
                    actionLabel: 'Retry',
                    onAction: _retry,
                  );
                }

                final records = snapshot.data?.visits ?? <ClinicalVisit>[];

                // Extract ONLY assigned medicines from all prescriptions
                final List<(ClinicalVisit, PrescriptionItem)>
                assignedMedicines = [];

                for (final cv in records) {
                  if (cv.prescription != null) {
                    for (final item in cv.prescription!.items) {
                      final name = item.name.trim();
                      if (name.isNotEmpty) {
                        assignedMedicines.add((cv, item));
                      }
                    }
                  }
                }

                final uploadedMedicines = <(Map<String, dynamic>, Map)>[];
                for (final report
                    in snapshot.data?.reports ??
                        const <Map<String, dynamic>>[]) {
                  final extraction = report['structured_data'];
                  final medicines = extraction is Map
                      ? extraction['medicines']
                      : null;
                  if (medicines is! List) continue;
                  for (final raw in medicines.whereType<Map>()) {
                    final name = raw['name']?.toString().trim() ?? '';
                    if (name.isEmpty) continue;
                    uploadedMedicines.add((report, raw));
                  }
                }
                final regularUploaded = uploadedMedicines
                    .where(
                      (entry) =>
                          entry.$2['as_needed'] != true &&
                          !isAsNeeded(
                            '${entry.$2['frequency'] ?? ''} '
                            '${entry.$2['instructions'] ?? ''}',
                          ),
                    )
                    .toList();
                final asNeededUploaded = uploadedMedicines
                    .where(
                      (entry) =>
                          entry.$2['as_needed'] == true ||
                          isAsNeeded(
                            '${entry.$2['frequency'] ?? ''} '
                            '${entry.$2['instructions'] ?? ''}',
                          ),
                    )
                    .toList();

                // ── Empty ────────────────────────────────────────────────────────
                if (assignedMedicines.isEmpty && uploadedMedicines.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.15,
                      ),
                      PatientStateView(
                        icon: Icons.medication_outlined,
                        tone: colors.info,
                        title: 'No Medicines Assigned',
                        body:
                            snapshot.data?.reportLoadFailed == true ||
                                snapshot.data?.clinicalLoadFailed == true
                            ? 'Some medicine sources could not be loaded. Please retry.'
                            : 'No medicines have been assigned for you yet. Visit your doctor to receive a prescription.',
                        actionLabel:
                            snapshot.data?.reportLoadFailed == true ||
                                snapshot.data?.clinicalLoadFailed == true
                            ? 'Retry'
                            : null,
                        onAction:
                            snapshot.data?.reportLoadFailed == true ||
                                snapshot.data?.clinicalLoadFailed == true
                            ? _retry
                            : null,
                      ),
                    ],
                  );
                }

                // ── Small Square Boxes Wrap Layout ──────────────────────────────
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (snapshot.data?.reportLoadFailed == true) ...[
                          const Text(
                            'Uploaded report medicines could not be loaded. Pull down to retry.',
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (snapshot.data?.clinicalLoadFailed == true) ...[
                          const Text(
                            'Doctor prescriptions could not be loaded.',
                          ),
                          TextButton(
                            onPressed: _retry,
                            child: const Text('Retry'),
                          ),
                        ],
                        if (assignedMedicines.isNotEmpty) ...[
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MedicineRemindersScreen(
                                  controller: widget.controller,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.checklist_rounded),
                            label: const Text(
                              'Doctor medicine checklist and reminders',
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Saathi doctor prescriptions',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              for (final entry in assignedMedicines)
                                SizedBox.square(
                                  dimension: 125,
                                  child: _MedicineSquareBox(
                                    item: entry.$2,
                                    colors: colors,
                                    onTap: () => _showMedicineDetails(
                                      context,
                                      entry.$2,
                                      entry.$1,
                                      colors,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (regularUploaded.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Medicines from uploaded reports',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          for (final entry in regularUploaded)
                            _UploadedReportMedicine(
                              report: entry.$1,
                              medicine: entry.$2,
                              controller: widget.controller,
                            ),
                        ],
                        if (asNeededUploaded.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text(
                            'As Needed',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final entry in asNeededUploaded)
                            _UploadedReportMedicine(
                              report: entry.$1,
                              medicine: entry.$2,
                              controller: widget.controller,
                            ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }

  void _showMedicineDetails(
    BuildContext context,
    PrescriptionItem item,
    ClinicalVisit visit,
    SaathiColors colors,
  ) {
    final typeInfo = _MedicineTypeHelper.resolve(item);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.line, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: typeInfo.bgColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: typeInfo.color.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: typeInfo.buildSymbol(size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          typeInfo.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: typeInfo.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colors.textMuted),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: colors.line, height: 1),
              const SizedBox(height: 14),
              if (item.dosage != null && item.dosage!.isNotEmpty)
                _detailRow('Dosage', item.dosage!, colors),
              _detailRow(
                'Source',
                'Prescribed by Saathi doctor${visit.doctorName == null ? '' : ' · ${visit.doctorName}'}${visit.visit.visitDate == null ? '' : ' · ${visit.visit.visitDate}'}',
                colors,
              ),
              if (item.frequency != null && item.frequency!.isNotEmpty)
                _detailRow('Frequency', item.frequency!, colors),
              if (item.durationDays != null)
                _detailRow('Duration', '${item.durationDays} days', colors),
              if (item.instructions != null && item.instructions!.isNotEmpty)
                _detailRow('Instructions', item.instructions!, colors),
              if (item.foodTiming != null && item.foodTiming!.isNotEmpty)
                _detailRow('Food Timing', item.foodTiming!, colors),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, SaathiColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: colors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A square card representing a single assigned medicine.
class _MedicineSquareBox extends StatelessWidget {
  const _MedicineSquareBox({
    required this.item,
    required this.colors,
    required this.onTap,
  });

  final PrescriptionItem item;
  final SaathiColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typeInfo = _MedicineTypeHelper.resolve(item);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: colors.primary.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.line, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Medicine Type Symbol Badge ──────────────────────────────
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: typeInfo.bgColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: typeInfo.color.withValues(alpha: 0.28),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: typeInfo.buildSymbol(size: 24),
              ),
              const SizedBox(height: 6),

              // ── Medicine Name ───────────────────────────────────────────
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: colors.text,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),

              // ── Medicine Type Pill Badge ────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: typeInfo.bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  typeInfo.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: typeInfo.color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resolves medicine type (Tablet, Capsule, Syrup, Injection, Drops, etc.)
/// and produces appropriate symbol, colors, and badge label.
class _MedicineTypeHelper {
  final String label;
  final Color color;
  final Color bgColor;
  final Widget Function({required double size}) builder;

  const _MedicineTypeHelper({
    required this.label,
    required this.color,
    required this.bgColor,
    required this.builder,
  });

  Widget buildSymbol({double size = 32}) => builder(size: size);

  static _MedicineTypeHelper resolve(PrescriptionItem item) {
    final raw = '${item.medicineType ?? ""} ${item.dosage ?? ""} ${item.name}'
        .toLowerCase();

    // 1. Syrup / Liquid / Suspension
    if (raw.contains('syrup') ||
        raw.contains('suspension') ||
        raw.contains('liquid') ||
        raw.contains('solution') ||
        raw.contains('tonic') ||
        raw.contains('bottle') ||
        raw.contains('ml')) {
      return _MedicineTypeHelper(
        label: 'Syrup',
        color: const Color(0xFFEA580C),
        bgColor: const Color(0xFFFFEDD5),
        builder: ({required size}) => Icon(
          Icons.water_drop_rounded,
          color: const Color(0xFFEA580C),
          size: size,
        ),
      );
    }

    // 2. Injection / Vaccine / IV
    if (raw.contains('injection') ||
        raw.contains('inj') ||
        raw.contains('vaccine') ||
        raw.contains('shot') ||
        raw.contains('vial') ||
        raw.contains('ampoule') ||
        raw.contains('iv')) {
      return _MedicineTypeHelper(
        label: 'Injection',
        color: const Color(0xFFDC2626),
        bgColor: const Color(0xFFFEE2E2),
        builder: ({required size}) => Icon(
          Icons.vaccines_rounded,
          color: const Color(0xFFDC2626),
          size: size,
        ),
      );
    }

    // 3. Drops (Eye, Ear, Nasal)
    if (raw.contains('drop')) {
      return _MedicineTypeHelper(
        label: 'Drops',
        color: const Color(0xFF0D9488),
        bgColor: const Color(0xFFCCFBF1),
        builder: ({required size}) => Icon(
          Icons.opacity_rounded,
          color: const Color(0xFF0D9488),
          size: size,
        ),
      );
    }

    // 4. Ointment / Cream / Gel
    if (raw.contains('cream') ||
        raw.contains('ointment') ||
        raw.contains('gel') ||
        raw.contains('lotion') ||
        raw.contains('tube')) {
      return _MedicineTypeHelper(
        label: 'Ointment',
        color: const Color(0xFF16A34A),
        bgColor: const Color(0xFFDCFCE7),
        builder: ({required size}) => Icon(
          Icons.healing_rounded,
          color: const Color(0xFF16A34A),
          size: size,
        ),
      );
    }

    // 5. Inhaler / Spray
    if (raw.contains('inhaler') ||
        raw.contains('spray') ||
        raw.contains('puff') ||
        raw.contains('rotahaler') ||
        raw.contains('respicap')) {
      return _MedicineTypeHelper(
        label: 'Inhaler',
        color: const Color(0xFF0284C7),
        bgColor: const Color(0xFFE0F2FE),
        builder: ({required size}) =>
            Icon(Icons.air_rounded, color: const Color(0xFF0284C7), size: size),
      );
    }

    // 6. Capsule
    if (raw.contains('capsule') || raw.contains('cap')) {
      return _MedicineTypeHelper(
        label: 'Capsule',
        color: const Color(0xFF8B5CF6),
        bgColor: const Color(0xFFEDE9FE),
        builder: ({required size}) => Icon(
          Icons.medication_rounded,
          color: const Color(0xFF8B5CF6),
          size: size,
        ),
      );
    }

    // 7. Tablet (Default & explicit)
    return _MedicineTypeHelper(
      label: 'Tablet',
      color: const Color(0xFF0284C7),
      bgColor: const Color(0xFFE0F2FE),
      builder: ({required size}) =>
          _TabletSymbol(size: size, color: const Color(0xFF0284C7)),
    );
  }
}

/// Custom circular pill / tablet symbol with authentic pharma score line.
class _TabletSymbol extends StatelessWidget {
  const _TabletSymbol({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _TabletPainter(color: color),
    );
  }
}

class _TabletPainter extends CustomPainter {
  final Color color;
  _TabletPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Outer circular rim of tablet
    final rimPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6;
    canvas.drawCircle(center, radius, rimPaint);

    // Subtle internal fill
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, fillPaint);

    // Center break/score line
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - radius * 0.72, center.dy),
      Offset(center.dx + radius * 0.72, center.dy),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TabletPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _UploadedReportMedicine extends StatelessWidget {
  const _UploadedReportMedicine({
    required this.report,
    required this.medicine,
    required this.controller,
  });
  final Map<String, dynamic> report;
  final Map medicine;
  final AppController controller;

  void _showKannadaExplanation(BuildContext context) {
    final reportId = report['report_id'];
    final items = (report['structured_data'] as Map?)?['medicines'];
    if (reportId is! int || items is! List) return;
    final index = items.indexOf(medicine);
    if (index < 0) return;
    final future = controller.cachedKannadaMedicineExplanation(
      reportId: reportId,
      medicineIndex: index,
      medicineName: medicine['name']?.toString() ?? '',
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(medicine['name']?.toString() ?? 'Medicine'),
        content: FutureBuilder<String>(
          future: future,
          builder: (ctx, snapshot) {
            if (!snapshot.hasData && !snapshot.hasError) {
              return const CircularProgressIndicator();
            }
            if (snapshot.hasError) {
              return const Text(
                'Kannada explanation is unavailable. Check the original prescription.',
              );
            }
            return SingleChildScrollView(child: Text(snapshot.data!));
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _enable(BuildContext context) async {
    final patient = controller.patient;
    final reportId = report['report_id'];
    final items = (report['structured_data'] as Map?)?['medicines'];
    if (patient == null || reportId is! int || items is! List) return;
    final index = items.indexOf(medicine);
    if (index < 0) return;
    final writtenTimes = explicitClockTimes(
      '${medicine['timing'] ?? ''} ${medicine['instructions'] ?? ''}',
    );
    final times = <TimeOfDay>[...writtenTimes];
    if (times.isEmpty) {
      final frequency = medicine['frequency']?.toString().toLowerCase() ?? '';
      final count =
          RegExp(r'\b(twice|two times|2 times|bid)\b').hasMatch(frequency)
          ? 2
          : 1;
      for (var i = 0; i < count; i++) {
        if (!context.mounted) return;
        final chosen = await showTimePicker(
          context: context,
          helpText: 'Choose personal reminder time ${i + 1} of $count',
          initialTime: TimeOfDay.now(),
        );
        if (chosen == null) return;
        times.add(chosen);
      }
    }
    final plan = MedicineReminderPlan.fromReport(
      patientId: patient.id,
      reportId: reportId,
      medicineIndex: index,
      medicine: medicine,
      times: times,
    );
    if (!context.mounted) return;
    if (plan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A fixed reminder needs documented start and end dates. As-needed medicines have no daily reminder.',
          ),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm medicine reminders'),
        content: Text(
          '${plan.name}\n${plan.dose ?? 'Dose not documented'}\n'
          '${times.map(ReminderService.formatTimeOfDay).join(', ')}\n'
          '${plan.startDate.day}/${plan.startDate.month}/${plan.startDate.year} – '
          '${plan.endDate.day}/${plan.endDate.month}/${plan.endDate.year}\n'
          'Source: uploaded discharge report',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Turn on'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final count = await ReminderService.instance.enableMedicinePlan(
        plan,
        patientName: patient.name,
        language: controller.language,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count local reminder times scheduled.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not enable reminders: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    final details =
        [
              medicine['dose'],
              medicine['route'],
              medicine['frequency'],
              medicine['duration'],
              medicine['timing'],
              medicine['start_date'],
              medicine['end_date'],
              medicine['instructions'],
            ]
            .where(
              (v) =>
                  v != null &&
                  v.toString().trim().isNotEmpty &&
                  v.toString() != 'null',
            )
            .join(' · ');
    return Card(
      color: colors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              medicine['name']?.toString() ?? 'Medicine',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(details, style: TextStyle(color: colors.text)),
            ],
            if (medicine['source_text']?.toString().trim().isNotEmpty == true)
              Text('Original: ${medicine['source_text']}'),
            if (medicine['patient_explanation']?.toString().trim().isNotEmpty ==
                true)
              Text('In simple words: ${medicine['patient_explanation']}'),
            if (controller.language == AppLanguage.kannada)
              TextButton.icon(
                onPressed: () => _showKannadaExplanation(context),
                icon: const Icon(Icons.translate_rounded),
                label: const Text('ಕನ್ನಡದಲ್ಲಿ ವಿವರಿಸಿ'),
              ),
            const SizedBox(height: 6),
            Text(
              'Source: ${report['hospital_name'] ?? report['original_filename']}',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
            if ((medicine['timing']?.toString().trim().isEmpty ?? true) &&
                !RegExp(
                  r'\b(as needed|if needed|prn)\b',
                  caseSensitive: false,
                ).hasMatch(
                  '${medicine['frequency'] ?? ''} ${medicine['instructions'] ?? ''}',
                ))
              Text(
                'Medicine timing is unclear. Please confirm with your treating doctor or pharmacist.',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            if (medicine['as_needed'] != true &&
                !isAsNeeded(
                  '${medicine['frequency'] ?? ''} ${medicine['instructions'] ?? ''}',
                ))
              TextButton.icon(
                onPressed: () => _enable(context),
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Review and enable phone reminders'),
              ),
          ],
        ),
      ),
    );
  }
}
