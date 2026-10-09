import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_client.dart';
import '../app_controller.dart';
import '../theme.dart';
import '../utils/patient_facing_text.dart';

const _documentChannel = MethodChannel('saathi/discharge_document');

/// Shared picker/camera -> Groq review -> save flow used by the dashboard,
/// Ask Saathi sheet, and the existing discharge-summary page.
Future<int?> pickAndReviewDischargeDocument(
  BuildContext context,
  AppController controller, {
  bool capture = false,
}) async {
  void showMessage(String message, {bool isError = true}) {
    if (!context.mounted) return;
    if (isError && ModalRoute.of(context) is ModalBottomSheetRoute) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Map<Object?, Object?>? selection;
  try {
    selection = await _documentChannel.invokeMapMethod<Object?, Object?>(
      capture ? 'captureDocument' : 'pickDocument',
    );
  } on PlatformException catch (error) {
    showMessage(error.message ?? 'Unable to open documents on this device.');
    return null;
  } catch (_) {
    showMessage(
      capture
          ? 'Unable to open the camera on this device.'
          : 'Unable to open documents on this device.',
    );
    return null;
  }
  if (selection == null || !context.mounted) return null;
  final fileName = selection['name'] as String? ?? '';
  final bytes = selection['bytes'] as Uint8List?;
  if (bytes == null || fileName.isEmpty) {
    showMessage('Unable to read the selected document.');
    return null;
  }
  if (bytes.length > 12 * 1024 * 1024) {
    showMessage('Choose a document smaller than 12 MB.');
    return null;
  }
  try {
    final result = await controller.summarizeDischargeDocument(fileName, bytes);
    if (!context.mounted) return null;
    var saving = false;
    String? saveError;
    return await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            icon: const Icon(Icons.summarize_rounded, color: saathiGreen),
            title: const Text('Your discharge summary'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
              child: SingleChildScrollView(
                key: const Key('dischargeSummaryContent'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      cleanPatientFacingText(
                        result['summary']?.toString() ?? '',
                      ),
                    ),
                    if (result['extracted'] is Map<String, dynamic>) ...[
                      const SizedBox(height: 20),
                      _ExtractedCarePlan(
                        data: result['extracted'] as Map<String, dynamic>,
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(
                      result['disclaimer']?.toString() ??
                          'AI-generated explanation. Check instructions with your care team.',
                      style: Theme.of(dialogContext).textTheme.bodySmall
                          ?.copyWith(
                            color: Theme.of(
                              dialogContext,
                            ).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (saveError != null)
                SizedBox(
                  width: double.infinity,
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      saveError!,
                      key: const Key('dischargeReportSaveError'),
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              FilledButton.icon(
                key: const Key('saveDischargeReport'),
                onPressed: saving
                    ? null
                    : () async {
                        if (saving) return;
                        updateDialog(() {
                          saving = true;
                          saveError = null;
                        });
                        try {
                          final saved = await controller.saveDischargeReport(
                            result,
                            fileName,
                          );
                          if (!dialogContext.mounted) return;
                          Navigator.of(
                            dialogContext,
                          ).pop(saved['report_id'] as int?);
                          showMessage(
                            'Report saved successfully',
                            isError: false,
                          );
                        } on ApiException catch (error) {
                          if (dialogContext.mounted) {
                            updateDialog(() => saveError = error.message);
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            updateDialog(
                              () => saveError =
                                  'Unable to save this report. Your extraction is still here. Please retry.',
                            );
                          }
                        } finally {
                          if (dialogContext.mounted) {
                            updateDialog(() => saving = false);
                          }
                        }
                      },
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  saving
                      ? 'Saving report...'
                      : saveError != null
                      ? 'Retry'
                      : 'Save report',
                ),
              ),
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  } on ApiException catch (error) {
    showMessage(error.message);
  } catch (_) {
    showMessage(
      'Unable to summarize this document. Check your connection and try again.',
    );
  }
  return null;
}

class DischargeSummaryScreen extends StatefulWidget {
  const DischargeSummaryScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<DischargeSummaryScreen> createState() => _DischargeSummaryScreenState();
}

class _DischargeSummaryScreenState extends State<DischargeSummaryScreen> {
  bool _busy = false;

  Future<void> _chooseAndSummarize() async {
    setState(() => _busy = true);
    try {
      await pickAndReviewDischargeDocument(context, widget.controller);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(title: const Text('Discharge summary')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 76,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Understand your discharge instructions',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Take a clear photo of your discharge paper or choose a PDF or image. We’ll explain the main points in simple language.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _chooseAndSummarize,
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_rounded),
                      label: Text(
                        _busy ? 'Reading your document…' : 'Choose a document',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'PDF, JPG or PNG · up to 12 MB. Review the extracted details, then save the report to your medical records.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This AI summary may miss details. Follow your original discharge instructions and contact your care team if anything is unclear.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExtractedCarePlan extends StatelessWidget {
  const _ExtractedCarePlan({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[];
    void add(String title, String? value) {
      if (value == null ||
          value.trim().isEmpty ||
          value.toLowerCase() == 'null') {
        return;
      }
      sections.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(value),
            ],
          ),
        ),
      );
    }

    add('Condition', data['diagnosis']?.toString());
    add('What this means', data['condition_explanation']?.toString());
    final medicines = data['medicines'];
    if (medicines is List && medicines.isNotEmpty) {
      sections.add(
        const Text('Medicines', style: TextStyle(fontWeight: FontWeight.w800)),
      );
      for (final item in medicines.whereType<Map>()) {
        add('Original prescription', item['source_text']?.toString());
        add('In simple words', item['patient_explanation']?.toString());
        final lines =
            [
              item['name'],
              item['strength'],
              item['dose'],
              item['route'],
              item['frequency'],
              item['duration'],
              item['timing'],
              item['food_timing'],
              item['start_date'],
              item['end_date'],
              item['instructions'],
            ].where(
              (v) =>
                  v != null &&
                  v.toString().trim().isNotEmpty &&
                  v.toString() != 'null',
            );
        sections.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text(lines.join(' · ')),
          ),
        );
      }
    }
    void addList(String title, dynamic values) {
      if (values is List && values.isNotEmpty) {
        add(title, values.map((v) => '• ${v.toString()}').join('\n'));
      }
    }

    addList('Warning signs mentioned in the report', data['warning_signs']);
    addList('Discharge instructions', data['discharge_instructions']);
    addList('Things to clarify with your care team', data['unclear_details']);
    final followUps = data['follow_up'];
    if (followUps is List && followUps.isNotEmpty) {
      add(
        'Follow-up',
        followUps
            .whereType<Map>()
            .map(
              (item) =>
                  [
                        item['date'],
                        item['time'],
                        item['doctor'],
                        item['hospital'],
                        item['purpose'],
                        item['instructions'],
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
            .join('\n'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }
}
