import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_controller.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/patient_scaffold.dart';
import 'vitals_history_screen.dart';
import '../l10n/app_text.dart';
import '../services/reminder_service.dart';
import '../utils/patient_facing_text.dart';
import 'discharge_summary_screen.dart';

String _tr(BuildContext context, T key) => AppText.of(context)(key);

class HealthSummaryScreen extends StatefulWidget {
  const HealthSummaryScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<HealthSummaryScreen> createState() => _HealthSummaryScreenState();
}

class _HealthSummaryScreenState extends State<HealthSummaryScreen> {
  late Future<HealthSummary> _summary;
  @override
  void initState() {
    super.initState();
    _summary = widget.controller.fetchHealthSummary();
  }

  void _retry() =>
      setState(() => _summary = widget.controller.fetchHealthSummary());
  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    return PatientScaffold(
      title: _tr(context, T.healthTitle),
      controller: widget.controller,
      backgroundColor: colors.page,
      body: FutureBuilder<HealthSummary>(
        future: _summary,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SavedCarePlanPanel(controller: widget.controller),
                  const SizedBox(height: 16),
                  Text(_tr(context, T.healthLoading)),
                ],
              ),
            );
          }
          if (snap.hasError) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SavedCarePlanPanel(controller: widget.controller),
                  const SizedBox(height: 16),
                  _ErrorState(onRetry: _retry, message: snap.error.toString()),
                ],
              ),
            );
          }
          final data = snap.data ?? const HealthSummary(hasData: false);
          return data.hasData
              ? _SummaryBody(summary: data, controller: widget.controller)
              : _EmptyState(controller: widget.controller);
        },
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.summary, required this.controller});
  final HealthSummary summary;
  final AppController controller;
  String _date(BuildContext c) {
    final d = DateTime.tryParse(summary.visitDate ?? '');
    return d == null
        ? 'Date not available'
        : DateFormat.yMMMMd(
            Localizations.localeOf(c).toString(),
          ).add_jm().format(d);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    final doctor = summary.doctorName?.trim();
    final doctorText = doctor == null || doctor.isEmpty
        ? 'your doctor'
        : 'Dr. $doctor';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (MediaQuery.sizeOf(context).height - 90).clamp(0, 900),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SavedCarePlanPanel(controller: controller),
            const SizedBox(height: 18),
            Text(
              _tr(context, T.healthLatestCheck),
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: .6,
              ),
            ),
            const SizedBox(height: 8),
            _Panel(
              child: Row(
                children: [
                  _RoundIcon(icon: Icons.calendar_month_outlined),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_tr(context, T.healthRecordedOn)} ${_date(context)}',
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          doctorText,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _tr(context, T.healthVitalsHeading),
              style: TextStyle(
                color: colors.text,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _VitalsPanel(
              summary: summary,
              doctorText: doctorText,
              date: _date(context),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VitalsHistoryScreen(controller: controller),
                ),
              ),
              icon: const Icon(Icons.history),
              label: Text(_tr(context, T.vitalsHistoryButton)),
            ),
          ],
        ),
      ),
    );
  }
}

class _VitalsPanel extends StatelessWidget {
  const _VitalsPanel({
    required this.summary,
    required this.doctorText,
    required this.date,
  });
  final HealthSummary summary;
  final String doctorText;
  final String date;
  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    final items = [
      _VitalCard(
        Icons.favorite_outline,
        _tr(context, T.healthHeartRate),
        summary.heartRate,
        'bpm',
      ),
      _VitalCard(
        Icons.speed_outlined,
        _tr(context, T.healthBloodPressure),
        summary.bloodPressure,
        'mmHg',
      ),
      _VitalCard(Icons.air, _tr(context, T.healthOxygen), summary.spo2, '%'),
      _VitalCard(
        Icons.thermostat_outlined,
        _tr(context, T.healthTemperature),
        summary.temperature,
        '°C',
      ),
      _VitalCard(
        Icons.monitor_weight_outlined,
        _tr(context, T.healthWeight),
        summary.weight,
        'kg',
      ),
      _VitalCard(
        Icons.height,
        _tr(context, T.healthHeight),
        summary.height,
        'cm',
      ),
    ];
    return _Panel(
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final width = (c.maxWidth - 9) / 2;
              return Wrap(
                spacing: 9,
                runSpacing: 9,
                children: items
                    .map((i) => SizedBox(width: width, child: i))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 14),
          Divider(color: colors.line, height: 1),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RoundIcon(icon: Icons.verified_user_outlined, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_tr(context, T.healthRecordedDuring)} $doctorText.',
                      style: TextStyle(color: colors.textMuted, fontSize: 14),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 17, color: colors.textMuted),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            date,
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VitalCard extends StatelessWidget {
  const _VitalCard(this.icon, this.label, this.value, this.unit);
  final IconData icon;
  final String label;
  final String? value;
  final String unit;
  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    final present = value != null && value!.trim().isNotEmpty;
    return Container(
      constraints: const BoxConstraints(minHeight: 108),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RoundIcon(icon: icon, size: 34),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          present
              ? RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                    children: [
                      TextSpan(text: value),
                      TextSpan(
                        text: ' $unit',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : Text(
                  _tr(context, T.healthNotRecorded),
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: c.saathiColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: c.saathiColors.line),
    ),
    child: child,
  );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, this.size = 48});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext c) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: c.saathiColors.primaryTint,
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: c.saathiColors.info, size: size * .52),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext c) => SingleChildScrollView(
    child: Column(
      children: [
        _SavedCarePlanPanel(controller: controller),
        Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.monitor_heart_outlined,
                size: 54,
                color: c.saathiColors.info,
              ),
              const SizedBox(height: 14),
              Text(
                _tr(c, T.healthNoVitals),
                style: TextStyle(
                  color: c.saathiColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _tr(c, T.healthNoVitalsBody),
                style: TextStyle(color: c.saathiColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SavedCarePlanPanel extends StatefulWidget {
  const _SavedCarePlanPanel({required this.controller});
  final AppController controller;

  @override
  State<_SavedCarePlanPanel> createState() => _SavedCarePlanPanelState();
}

class _SavedCarePlanPanelState extends State<_SavedCarePlanPanel> {
  late Future<List<Map<String, dynamic>>> _future;
  int? _selectedId;
  int? _translationId;
  Future<Map<String, dynamic>>? _translation;

  @override
  void initState() {
    super.initState();
    _future = widget.controller.fetchDischargeReports();
  }

  void _reload() => setState(() {
    _future = widget.controller.fetchDischargeReports();
    _selectedId = null;
  });

  Future<void> _openUpload() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DischargeSummaryScreen(controller: widget.controller),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(22),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Unable to load saved discharge reports.'),
                TextButton(onPressed: _reload, child: const Text('Retry')),
              ],
            ),
          );
        }
        final reports = snapshot.data ?? [];
        if (reports.isEmpty) {
          return _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Health Summary',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload a discharge report to build a care plan from its documented instructions.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _openUpload,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload Report'),
                ),
              ],
            ),
          );
        }
        _selectedId ??= reports.first['report_id'] as int;
        final report = reports.firstWhere(
          (r) => r['report_id'] == _selectedId,
          orElse: () => reports.first,
        );
        final data = Map<String, dynamic>.from(
          report['structured_data'] as Map? ?? {},
        );
        final language = widget.controller.language;
        if (language == AppLanguage.kannada &&
            _translationId != report['report_id']) {
          _translationId = report['report_id'] as int;
          _translation = widget.controller.askDischargeQuestion(
            reportId: _translationId!,
            question:
                'Explain the condition and the documented recovery plan in Kannada. Include the documented medicine instructions, warning signs, follow-up and discharge instructions. Clearly mark missing details. Do not add or change medical instructions.',
            language: 'Kannada',
          );
        }
        final translated = language == AppLanguage.kannada
            ? _translation
            : null;
        return _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'AI Health Summary',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Listen to this plan',
                    onPressed: () async {
                      var spokenText = cleanPatientFacingText(
                        report['summary']?.toString() ?? '',
                        forSpeech: true,
                      );
                      if (language == AppLanguage.kannada) {
                        try {
                          final translatedAnswer = await translated!;
                          spokenText = cleanPatientFacingText(
                            translatedAnswer['answer']?.toString() ?? '',
                            forSpeech: true,
                          );
                        } catch (_) {
                          spokenText = 'ಕನ್ನಡ ಸಾರಾಂಶ ಲಭ್ಯವಿಲ್ಲ.';
                        }
                      }
                      if (spokenText.trim().isNotEmpty) {
                        await ReminderService.instance.speakSentence(
                          spokenText,
                          language,
                        );
                      }
                    },
                    icon: const Icon(Icons.volume_up_rounded),
                  ),
                ],
              ),
              DropdownButtonFormField<int>(
                initialValue: _selectedId,
                decoration: const InputDecoration(
                  labelText: 'Summary for report',
                  isDense: true,
                ),
                items: reports
                    .map(
                      (r) => DropdownMenuItem<int>(
                        value: r['report_id'] as int,
                        child: Text(
                          (r['hospital_name'] ?? r['original_filename'])
                              .toString(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) => setState(() {
                  _selectedId = id;
                  _translationId = null;
                  _translation = null;
                }),
              ),
              const SizedBox(height: 12),
              if (translated != null)
                FutureBuilder<Map<String, dynamic>>(
                  future: translated,
                  builder: (context, translatedSnapshot) =>
                      translatedSnapshot.connectionState != ConnectionState.done
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : Text(
                          translatedSnapshot.hasError
                              ? 'Kannada explanation is unavailable right now. The report details below remain in the original language.'
                              : cleanPatientFacingText(
                                  translatedSnapshot.data?['answer']
                                          ?.toString() ??
                                      '',
                                ),
                        ),
                )
              else ...[
                _CarePlanField('Condition', data['diagnosis']?.toString()),
                _CarePlanField(
                  'In simple words',
                  data['condition_explanation']
                              ?.toString()
                              .trim()
                              .toLowerCase() ==
                          data['diagnosis']?.toString().trim().toLowerCase()
                      ? (report['summary']
                            ?.toString()
                            .split(RegExp(r'(?<=[.!?])\s+'))
                            .first)
                      : data['condition_explanation']?.toString(),
                ),
                _CarePlanField(
                  'My medicines (as documented)',
                  _medicineLines(data['medicines']),
                ),
                _CarePlanField(
                  'Warning signs stated in report',
                  _stringList(data['warning_signs']),
                ),
                _CarePlanField(
                  'Follow-up mentioned (not a booked appointment)',
                  _followupLines(data['follow_up']),
                ),
                _CarePlanField(
                  'Recovery instructions',
                  _stringList(data['discharge_instructions']),
                ),
                _CarePlanField(
                  'Things to clarify',
                  _stringList(data['unclear_details']),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Source: ${report['hospital_name'] ?? report['original_filename']} · ${report['uploaded_at']}',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  String? _stringList(dynamic value) => value is List && value.isNotEmpty
      ? value.map((e) => '• ${e.toString().replaceAll('_', ' ')}').join('\n')
      : null;
  String? _medicineLines(dynamic value) {
    if (value is! List || value.isEmpty) return null;
    return value
        .whereType<Map>()
        .map(
          (m) =>
              [
                    m['name'],
                    m['dose'],
                    m['route'],
                    m['frequency'],
                    m['duration'],
                    m['timing'],
                    m['start_date'],
                    m['end_date'],
                    m['instructions'],
                  ]
                  .where(
                    (v) =>
                        v != null &&
                        v.toString().trim().isNotEmpty &&
                        v.toString() != 'null',
                  )
                  .join(' · '),
        )
        .join('\n');
  }

  String? _followupLines(dynamic value) {
    if (value is! List || value.isEmpty) return null;
    return value
        .whereType<Map>()
        .map(
          (f) =>
              [
                    f['date'],
                    f['time'],
                    f['doctor'],
                    f['hospital'],
                    f['purpose'],
                    f['instructions'],
                  ]
                  .where(
                    (v) =>
                        v != null &&
                        v.toString().trim().isNotEmpty &&
                        v.toString() != 'null',
                  )
                  .join(' · '),
        )
        .where((v) => v.isNotEmpty)
        .join('\n');
  }
}

class _CarePlanField extends StatelessWidget {
  const _CarePlanField(this.title, this.value);
  final String title;
  final String? value;
  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(value!),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry, required this.message});
  final VoidCallback onRetry;
  final String message;
  @override
  Widget build(BuildContext c) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_tr(c, T.healthLoadError)),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: Text(_tr(c, T.tryAgain))),
      ],
    ),
  );
}
