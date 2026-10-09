import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../app_controller.dart';
import '../l10n/app_text.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/patient_scaffold.dart';
import '../widgets/patient_widgets.dart';

/// PAST VISITS screen — real clinical data from FastAPI/MySQL.
///
/// Fetches the nested clinical records (visits → vitals → report →
/// prescription → items) and displays them newest-first. The patient cannot
/// edit any record; this screen is read-only.
class VisitHistoryScreen extends StatefulWidget {
  const VisitHistoryScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  late Future<List<ClinicalVisit>> _dataFuture;
  Timer? _autoSyncTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(_load);
      }
    });
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  void _load() {
    _dataFuture = widget.controller.fetchClinicalVisits(notify: true);
  }

  void _retry() => setState(_load);

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final colors = context.saathiColors;

    return PatientScaffold(
      title: text(T.visitHistoryTitle),
      controller: widget.controller,
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_load);
          await _dataFuture;
        },
        color: colors.primary,
        child: FutureBuilder<List<ClinicalVisit>>(
          future: _dataFuture,
          builder: (context, snapshot) {
            // ── Loading ──────────────────────────────────────────────────────
            if (snapshot.connectionState == ConnectionState.waiting && widget.controller.clinicalVisits.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: colors.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Loading visit history…',
                      style: TextStyle(color: colors.textMuted, fontSize: 15),
                    ),
                  ],
                ),
              );
            }

            // ── Error ────────────────────────────────────────────────────────
            if (snapshot.hasError && widget.controller.clinicalVisits.isEmpty) {
              final err = snapshot.error;
              final msg = err is ApiException
                  ? err.message
                  : 'Unable to load visit history.';
              return PatientStateView(
                icon: Icons.cloud_off_rounded,
                tone: colors.emergency,
                title: 'Unable to load visit history',
                body: msg,
                actionLabel: 'Retry',
                onAction: _retry,
              );
            }

            final visits = snapshot.data ?? widget.controller.clinicalVisits;

            // ── Empty ────────────────────────────────────────────────────────
            if (visits.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.15),
                  PatientStateView(
                    icon: Icons.folder_open_rounded,
                    tone: colors.info,
                    title: text(T.noVisitsTitle),
                    body: text(T.noVisitsBody),
                  ),
                ],
              );
            }

            // ── Data ─────────────────────────────────────────────────────────
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text(
                  text(T.visitHistoryHint),
                  style: TextStyle(
                    fontSize: 15,
                    color: colors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                for (final cv in visits)
                  _VisitCard(
                    clinicalVisit: cv,
                    controller: widget.controller,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({
    required this.clinicalVisit,
    required this.controller,
  });

  final ClinicalVisit clinicalVisit;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final locale = text.language.code;
    final colors = context.saathiColors;
    final dateBadge = scaledIcon(context, 54).clamp(54.0, 86.0);
    final visit = clinicalVisit.visit;
    final visitDate = DateTime.tryParse(visit.visitDate ?? '') ?? DateTime.now();
    final subtitle = clinicalVisit.diagnosis ?? visit.reason ?? visit.visitType.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VisitDetailScreen(
              clinicalVisit: clinicalVisit,
              controller: controller,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Date badge
              Container(
                width: dateBadge,
                height: dateBadge,
                decoration: BoxDecoration(
                  color: colors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat.d(locale).format(visitDate),
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: colors.primary,
                        height: 1,
                      ),
                    ),
                    Text(
                      DateFormat.MMM(locale).format(visitDate),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat.yMMMMd(locale).format(visitDate),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textMuted,
                      ),
                    ),
                    if (clinicalVisit.doctorName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        clinicalVisit.doctorName!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// VISIT DETAIL SCREEN
// ──────────────────────────────────────────────────────────────────────────────

class VisitDetailScreen extends StatefulWidget {
  const VisitDetailScreen({
    super.key,
    required this.clinicalVisit,
    required this.controller,
  });
  final ClinicalVisit clinicalVisit;
  final AppController controller;

  @override
  State<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

enum _DownloadState { idle, downloading, done }

class _VisitDetailScreenState extends State<VisitDetailScreen> {
  var downloadState = _DownloadState.idle;

  Future<void> _download() async {
    setState(() => downloadState = _DownloadState.downloading);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => downloadState = _DownloadState.done);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final colors = context.saathiColors;
    final locale = text.language.code;
    final cv = widget.clinicalVisit;
    final visit = cv.visit;
    final visitDate = DateTime.tryParse(visit.visitDate ?? '') ?? DateTime.now();

    final hasVitals = visit.temperature != null ||
        visit.bloodPressure != null ||
        visit.pulse != null ||
        visit.spo2 != null ||
        visit.weight != null ||
        visit.height != null;

    final items = cv.prescription?.items ?? [];

    return PatientScaffold(
      title: DateFormat.yMMMd(locale).format(visitDate),
      controller: widget.controller,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Visit summary card ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Doctor
                  if (cv.doctorName != null) ...[
                    PatientFieldLabel('Doctor'),
                    const SizedBox(height: 4),
                    Text(
                      cv.doctorName!,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Visit type
                  PatientFieldLabel('Visit Type'),
                  const SizedBox(height: 4),
                  Text(
                    visit.visitType.toUpperCase(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Reason
                  if (visit.reason != null && visit.reason!.isNotEmpty) ...[
                    PatientFieldLabel('Reason for Visit'),
                    const SizedBox(height: 4),
                    Text(
                      visit.reason!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Diagnosis
                  if (cv.diagnosis != null && cv.diagnosis!.isNotEmpty) ...[
                    PatientFieldLabel('Diagnosis'),
                    const SizedBox(height: 4),
                    Text(
                      cv.diagnosis!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Vitals
                  if (hasVitals) ...[
                    PatientFieldLabel('Patient Vitals'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        if (visit.temperature != null)
                          _VitalChip(label: 'Temp', value: visit.temperature!, unit: '°C'),
                        if (visit.bloodPressure != null)
                          _VitalChip(label: 'BP', value: visit.bloodPressure!, unit: 'mmHg'),
                        if (visit.pulse != null)
                          _VitalChip(label: 'Pulse', value: visit.pulse!, unit: 'bpm'),
                        if (visit.spo2 != null)
                          _VitalChip(label: 'SpO₂', value: visit.spo2!, unit: '%'),
                        if (visit.weight != null)
                          _VitalChip(label: 'Wt', value: visit.weight!, unit: 'kg'),
                        if (visit.height != null)
                          _VitalChip(label: 'Ht', value: visit.height!, unit: 'cm'),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Clinical notes
                  PatientFieldLabel('Clinical Notes'),
                  const SizedBox(height: 4),
                  Text(
                    cv.reportNotes?.isNotEmpty == true
                        ? cv.reportNotes!
                        : visit.notes?.isNotEmpty == true
                            ? visit.notes!
                            : 'No clinical notes recorded for this visit.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colors.textMuted,
                      height: 1.4,
                    ),
                  ),

                  // Prescription items
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    PatientFieldLabel('Prescribed Medicines'),
                    const SizedBox(height: 8),
                    ...items.map((item) => _MedicineCard(item: item, colors: colors)),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),
            _DownloadButton(state: downloadState, onTap: _download),
          ],
        ),
      ),
    );
  }
}

class _VitalChip extends StatelessWidget {
  const _VitalChip({required this.label, required this.value, required this.unit});
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        '$label: $value $unit',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({required this.item, required this.colors});
  final PrescriptionItem item;
  final SaathiColors colors;

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 6),
          _MedRow(label: 'Dosage', value: item.dosage),
          _MedRow(label: 'Frequency', value: item.frequency),
          _MedRow(
            label: 'Duration',
            value: item.durationDays != null ? '${item.durationDays} days' : null,
          ),
          _MedRow(
            label: 'Instructions',
            value: item.instructions ?? item.foodTiming,
          ),
        ],
      ),
    );
  }
}

class _MedRow extends StatelessWidget {
  const _MedRow({required this.label, required this.value});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    final colors = context.saathiColors;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 13, color: colors.textMuted, height: 1.4),
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

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.state, required this.onTap});
  final _DownloadState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final done = state == _DownloadState.done;
    final colors = context.saathiColors;
    return FilledButton.icon(
      onPressed: state == _DownloadState.downloading ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: done ? colors.primaryStrong : colors.info,
        minimumSize: const Size.fromHeight(64),
      ),
      icon: state == _DownloadState.downloading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : Icon(done ? Icons.check_circle_rounded : Icons.download_rounded),
      label: Text(switch (state) {
        _DownloadState.idle => text(T.downloadReport),
        _DownloadState.downloading => text(T.downloading),
        _DownloadState.done => text(T.downloaded),
      }),
    );
  }
}
