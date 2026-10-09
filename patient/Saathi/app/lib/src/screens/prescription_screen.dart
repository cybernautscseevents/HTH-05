import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../app_controller.dart';
import '../l10n/app_text.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/patient_scaffold.dart';
import '../widgets/patient_widgets.dart';

/// DOCTOR'S PRESCRIPTION screen — real prescription data from FastAPI/MySQL.
///
/// Shows all clinical visits that have an associated prescription, newest
/// first. Each card lists the diagnosis, date, and each medicine with full
/// dosage details. Read-only — patients cannot edit.
class PrescriptionScreen extends StatefulWidget {
  const PrescriptionScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  late Future<
    ({
      List<ClinicalVisit> records,
      List<Map<String, dynamic>> reports,
      Object? recordsError,
      Object? reportsError,
    })
  >
  _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _loadSources();
  }

  Future<
    ({
      List<ClinicalVisit> records,
      List<Map<String, dynamic>> reports,
      Object? recordsError,
      Object? reportsError,
    })
  >
  _loadSources() async {
    final recordsFuture = widget.controller
        .fetchClinicalVisits()
        .then<(List<ClinicalVisit>, Object?)>((value) => (value, null))
        .catchError((Object error) => (<ClinicalVisit>[], error));
    final reportsFuture = widget.controller
        .fetchDischargeReports()
        .then<(List<Map<String, dynamic>>, Object?)>((value) => (value, null))
        .catchError((Object error) => (<Map<String, dynamic>>[], error));
    final records = await recordsFuture;
    final reports = await reportsFuture;
    return (
      records: records.$1,
      reports: reports.$1,
      recordsError: records.$2,
      reportsError: reports.$2,
    );
  }

  void _retry() => setState(_load);

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final colors = context.saathiColors;
    final locale = text.language.code;

    return PatientScaffold(
      title: 'Consultation Reports',
      controller: widget.controller,
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_load);
          await _future;
        },
        color: colors.primary,
        child:
            FutureBuilder<
              ({
                List<ClinicalVisit> records,
                List<Map<String, dynamic>> reports,
                Object? recordsError,
                Object? reportsError,
              })
            >(
              future: _future,
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
                          'Loading reports…',
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
                if (snapshot.data?.recordsError != null &&
                    snapshot.data?.reportsError != null) {
                  final err = snapshot.data!.reportsError;
                  final msg = err is ApiException
                      ? err.message
                      : 'Unable to load consultation reports.';
                  return PatientStateView(
                    icon: Icons.cloud_off_rounded,
                    tone: colors.emergency,
                    title: 'Unable to load reports',
                    body: msg,
                    actionLabel: 'Retry',
                    onAction: _retry,
                  );
                }

                final records = snapshot.data?.records ?? <ClinicalVisit>[];
                // Include visits that have a report or prescription items
                final relevantVisits = records
                    .where(
                      (cv) =>
                          cv.reportDatetime != null ||
                          cv.diagnosis != null ||
                          cv.reportNotes != null ||
                          (cv.prescription != null &&
                              cv.prescription!.items.isNotEmpty),
                    )
                    .toList();

                final reports =
                    snapshot.data?.reports ?? const <Map<String, dynamic>>[];
                if (relevantVisits.isEmpty &&
                    reports.isEmpty &&
                    snapshot.data?.reportsError == null &&
                    snapshot.data?.recordsError == null) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.15,
                      ),
                      PatientStateView(
                        icon: Icons.assignment_late_rounded,
                        tone: colors.info,
                        title: 'No Reports Available',
                        body:
                            'No medical reports or prescriptions have been recorded for you yet.',
                      ),
                    ],
                  );
                }
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    for (final cv in relevantVisits)
                      _PrescriptionCard(
                        record: cv,
                        locale: locale,
                        colors: colors,
                      ),
                    if (snapshot.data?.recordsError != null ||
                        snapshot.data?.reportsError != null)
                      ListTile(
                        leading: Icon(Icons.info_outline_rounded),
                        title: Text(
                          snapshot.data?.reportsError != null
                              ? 'Uploaded reports could not be loaded.'
                              : 'Doctor prescriptions could not be loaded.',
                        ),
                        trailing: TextButton(
                          onPressed: _retry,
                          child: const Text('Retry'),
                        ),
                      ),
                    if (reports.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 12),
                        child: Text(
                          'Prescriptions from uploaded reports',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    for (final report in reports)
                      _UploadedReportPrescriptionCard(
                        report: report,
                        colors: colors,
                      ),
                  ],
                );
              },
            ),
      ),
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  const _PrescriptionCard({
    required this.record,
    required this.locale,
    required this.colors,
  });

  final ClinicalVisit record;
  final String locale;
  final SaathiColors colors;

  @override
  Widget build(BuildContext context) {
    final reportDate =
        DateTime.tryParse(record.visit.visitDate ?? '') ?? DateTime.now();
    final prescription = record.prescription;
    final items = prescription?.items ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — diagnosis + date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  record.diagnosis ?? 'Doctor Consultation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat.yMMMd(locale).format(reportDate),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),

          // Doctor name
          if (record.doctorName != null && record.doctorName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Dr. ${record.doctorName!}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
          ],

          // Clinical notes
          if (record.reportNotes != null && record.reportNotes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Clinical Notes:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              record.reportNotes!,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colors.textMuted,
                height: 1.35,
              ),
            ),
          ],

          // Medicines or Advice
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Medicines (${items.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in items) _MedicineRow(item: item, colors: colors),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.primaryTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: colors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Consultation report recorded. Follow doctor\'s guidance.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UploadedReportPrescriptionCard extends StatelessWidget {
  const _UploadedReportPrescriptionCard({
    required this.report,
    required this.colors,
  });
  final Map<String, dynamic> report;
  final SaathiColors colors;

  @override
  Widget build(BuildContext context) {
    final data = Map<String, dynamic>.from(
      report['structured_data'] as Map? ?? {},
    );
    final medicines = data['medicines'] is List
        ? data['medicines'] as List
        : const [];
    final uploaded = DateTime.tryParse(report['uploaded_at']?.toString() ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['diagnosis']?.toString().trim().isNotEmpty == true
                ? data['diagnosis'].toString()
                : 'Uploaded discharge report',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Source: ${report['hospital_name'] ?? report['original_filename']}',
            style: TextStyle(color: colors.textMuted),
          ),
          if (uploaded != null)
            Text(
              'Uploaded ${DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(uploaded)}',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
          if (medicines.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Medicines (${medicines.length})',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            for (final raw in medicines.whereType<Map>()) ...[
              const SizedBox(height: 6),
              Text(
                raw['name']?.toString() ?? 'Medicine',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                [
                      raw['dose'],
                      raw['route'],
                      raw['frequency'],
                      raw['duration'],
                      raw['timing'],
                      raw['instructions'],
                    ]
                    .where(
                      (v) =>
                          v != null &&
                          v.toString().trim().isNotEmpty &&
                          v.toString() != 'null',
                    )
                    .join(' · '),
                style: TextStyle(color: colors.textMuted),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MedicineRow extends StatelessWidget {
  const _MedicineRow({required this.item, required this.colors});
  final PrescriptionItem item;
  final SaathiColors colors;

  @override
  Widget build(BuildContext context) {
    final durationStr = item.durationDays != null
        ? '${item.durationDays} days'
        : null;
    final instructionStr = item.instructions ?? item.foodTiming;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primaryTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Medicine name + strength
          Text(
            item.strength != null
                ? '${item.name}  •  ${item.strength}'
                : item.name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.text,
            ),
          ),
          if (item.genericName != null) ...[
            const SizedBox(height: 2),
            Text(
              item.genericName!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (item.dosage != null)
                _DetailChip(
                  label: 'Dosage',
                  value: item.dosage!,
                  colors: colors,
                ),
              if (item.frequency != null)
                _DetailChip(
                  label: 'Frequency',
                  value: item.frequency!,
                  colors: colors,
                ),
              if (durationStr != null)
                _DetailChip(
                  label: 'Duration',
                  value: durationStr,
                  colors: colors,
                ),
              if (instructionStr != null)
                _DetailChip(
                  label: 'Instructions',
                  value: instructionStr,
                  colors: colors,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.label,
    required this.value,
    required this.colors,
  });
  final String label;
  final String value;
  final SaathiColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.line),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 12, color: colors.textMuted),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(fontWeight: FontWeight.w700, color: colors.text),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
