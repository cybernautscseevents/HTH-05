import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../api_client.dart';
import '../app_controller.dart';
import '../l10n/app_text.dart';
import '../services/reminder_service.dart';
import '../theme.dart';
import '../utils/patient_facing_text.dart';
import '../widgets/saathi_logo.dart';
import 'discharge_summary_screen.dart';

/// Report-grounded chat shown over the patient dashboard.
class AskSaathiSheet extends StatefulWidget {
  const AskSaathiSheet({
    super.key,
    required this.controller,
    this.initialDraft = '',
    this.submitInitial = false,
    this.initialReportId,
  });

  final AppController controller;
  final String initialDraft;
  final bool submitInitial;
  final int? initialReportId;

  @override
  State<AskSaathiSheet> createState() => _AskSaathiSheetState();
}

class _AskSaathiSheetState extends State<AskSaathiSheet> {
  late final TextEditingController _input;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final List<_ChatMessage> _messages = [];
  double _emptySheetSize = .5;
  ScrollController? _scroll;
  List<Map<String, dynamic>> _reports = [];
  int? _selectedReportId;
  bool _loadingReports = true;
  bool _sending = false;
  bool _uploading = false;
  bool _listening = false;
  bool _initialSubmitted = false;
  String? _reportsError;
  String _recognizedBase = '';

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: widget.initialDraft);
    _selectedReportId = widget.initialReportId;
    _loadReports(preferred: widget.initialReportId);
  }

  @override
  void dispose() {
    _speech.stop();
    _sheetController.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _loadReports({int? preferred}) async {
    setState(() {
      _loadingReports = true;
      _reportsError = null;
    });
    try {
      final reports = await widget.controller.fetchDischargeReports();
      if (!mounted) return;
      final ids = reports.map((r) => r['report_id']).whereType<int>().toSet();
      setState(() {
        _reports = reports;
        _selectedReportId = ids.contains(preferred)
            ? preferred
            : (ids.contains(_selectedReportId)
                  ? _selectedReportId
                  : (reports.isEmpty
                        ? null
                        : reports.first['report_id'] as int?));
        _loadingReports = false;
      });
      if (widget.submitInitial && !_initialSubmitted) {
        _initialSubmitted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _send();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingReports = false;
        _reportsError = 'Unable to load saved reports.';
      });
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final conversationSize = (_emptySheetSize + .08).clamp(.72, .9);
      if (_messages.isNotEmpty &&
          _sheetController.isAttached &&
          _sheetController.size < conversationSize) {
        await _sheetController.animateTo(
          conversationSize,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      if (!mounted) return;
      final scroll = _scroll;
      if (scroll != null && scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final question = _input.text.trim();
    if (_sending || question.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(question, true));
      _input.clear();
    });
    _scrollToLatest();
    final reportId = _selectedReportId;
    if (reportId == null) {
      setState(
        () => _messages.add(
          const _ChatMessage(
            'To answer a question about your health, add a document or select a saved report first.',
            false,
          ),
        ),
      );
      _scrollToLatest();
      return;
    }
    setState(() => _sending = true);
    try {
      final response = await widget.controller.askDischargeQuestion(
        reportId: reportId,
        question: question,
        language: widget.controller.language == AppLanguage.kannada
            ? 'Kannada'
            : 'English',
      );
      if (!mounted) return;
      final source = response['source'] as Map?;
      final hospital = source?['hospital']?.toString();
      final file = source?['filename']?.toString() ?? 'selected report';
      setState(
        () => _messages.add(
          _ChatMessage(
            response['answer']?.toString() ?? '',
            false,
            source: conciseReportSource(
              hospital?.isNotEmpty == true ? hospital! : file,
            ),
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _messages.add(_ChatMessage(error.message, false, error: true)),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _messages.add(
            const _ChatMessage(
              'Could not reach Saathi. Check your connection and try again.',
              false,
              error: true,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToLatest();
      }
    }
  }

  Future<void> _addDocument({bool capture = false}) async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final reportId = await pickAndReviewDischargeDocument(
        context,
        widget.controller,
        capture: capture,
      );
      if (mounted && reportId != null) {
        await _loadReports(preferred: reportId);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _toggleMicrophone() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final available = await _speech.initialize(
      onStatus: (status) {
        if (mounted && (status == 'done' || status == 'notListening')) {
          setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!available || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech input is unavailable on this device.'),
          ),
        );
      }
      return;
    }
    _recognizedBase = _input.text.trim();
    final locale = widget.controller.language == AppLanguage.kannada
        ? 'kn-IN'
        : 'en-IN';
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(localeId: locale),
      onResult: (result) {
        if (!mounted) return;
        final words = result.recognizedWords.trim();
        if (words.isNotEmpty) {
          final value = _recognizedBase.isEmpty
              ? words
              : '$_recognizedBase $words';
          _input.value = TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: value.length),
          );
        }
        if (result.finalResult) setState(() => _listening = false);
      },
    );
    if (mounted) setState(() => _listening = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    // An empty conversation needs only enough height for its controls. The
    // sheet grows when messages arrive and remains draggable on every device.
    final shortPhoneExtra = (850.0 - availableHeight).clamp(0.0, 210.0) * .36;
    final emptySize =
        ((390.0 + shortPhoneExtra + 110 * (textScale - 1)) / availableHeight)
            .clamp(.35, .85)
            .toDouble();
    _emptySheetSize = emptySize;
    final minSize = (300.0 / availableHeight).clamp(.25, emptySize).toDouble();
    final compactWithKeyboard = availableHeight < 500 && textScale > 1.4;
    final header = Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 46,
          height: 5,
          decoration: BoxDecoration(
            color: colors.line,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Ask Saathi',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: colors.brand,
                  ),
                ),
              ),
              IconButton.filledTonal(
                key: const Key('askSaathiClose'),
                tooltip: 'Close Ask Saathi',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ],
    );
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: emptySize,
      minChildSize: minSize,
      maxChildSize: .96,
      expand: false,
      builder: (context, scrollController) {
        _scroll = scrollController;
        return Container(
          key: const Key('askSaathiSheetSurface'),
          decoration: BoxDecoration(
            color: colors.page,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                if (!compactWithKeyboard) header,
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    children: [
                      if (compactWithKeyboard) header,
                      _reportSelector(colors),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 3, right: 8),
                            child: SaathiLogo(size: 42, showWordmark: false),
                          ),
                          Expanded(
                            child: _messageCard(
                              "Hi, I'm Saathi. How can I help you today?",
                              colors,
                              fromPatient: false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _documentButton(
                              'Add Document',
                              Icons.description_outlined,
                              () => _addDocument(),
                              colors,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _documentButton(
                              'Capture Document',
                              Icons.camera_alt_outlined,
                              () => _addDocument(capture: true),
                              colors,
                            ),
                          ),
                        ],
                      ),
                      if (_uploading)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(),
                        ),
                      const SizedBox(height: 12),
                      for (final message in _messages)
                        _ChatBubble(
                          message: message,
                          language: widget.controller.language,
                        ),
                      if (_sending)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _messageCard(
                            'Saathi is typing…',
                            colors,
                            fromPatient: false,
                          ),
                        ),
                    ],
                  ),
                ),
                _composer(colors),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _reportSelector(SaathiColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Expanded(
            child: _loadingReports
                ? const LinearProgressIndicator(minHeight: 2)
                : _reportsError != null
                ? TextButton.icon(
                    onPressed: _loadReports,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(_reportsError!),
                  )
                : _reports.isEmpty
                ? Text(
                    'Add a document to ask about your report',
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      key: const Key('askSaathiReportSelector'),
                      value: _selectedReportId,
                      isExpanded: true,
                      items: _reports
                          .map(
                            (report) => DropdownMenuItem<int>(
                              value: report['report_id'] as int,
                              child: Text(
                                (report['hospital_name'] ??
                                        report['original_filename'])
                                    .toString(),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.text,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) => setState(() => _selectedReportId = id),
                    ),
                  ),
          ),
          PopupMenuButton<AppLanguage>(
            tooltip: 'Answer language',
            icon: Icon(Icons.translate_rounded, color: colors.primary),
            onSelected: (language) {
              widget.controller.setLanguage(language);
              setState(() {});
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: AppLanguage.english, child: Text('English')),
              PopupMenuItem(value: AppLanguage.kannada, child: Text('ಕನ್ನಡ')),
            ],
          ),
          IconButton(
            tooltip: 'Clear chat',
            onPressed: _messages.isEmpty
                ? null
                : () => setState(_messages.clear),
            icon: Icon(Icons.delete_outline_rounded, color: colors.primary),
          ),
        ],
      ),
    );
  }

  Widget _documentButton(
    String label,
    IconData icon,
    VoidCallback action,
    SaathiColors colors,
  ) {
    return OutlinedButton.icon(
      onPressed: _uploading ? null : action,
      icon: Icon(icon, size: 19),
      label: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.brand,
        backgroundColor: colors.primaryTint,
        side: BorderSide(color: colors.primary.withValues(alpha: .28)),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      ),
    );
  }

  Widget _composer(SaathiColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 10),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: colors.primary.withValues(alpha: .32)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('askSaathiComposer'),
                controller: _input,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Ask about your report...',
                  hintStyle: const TextStyle(fontSize: 14),
                  filled: true,
                  fillColor: colors.primaryTint.withValues(alpha: .42),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            IconButton(
              key: const Key('askSaathiMicrophone'),
              tooltip: _listening ? 'Stop listening' : 'Speak question',
              onPressed: _toggleMicrophone,
              icon: Icon(
                _listening ? Icons.stop_rounded : Icons.mic_rounded,
                color: colors.primary,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton.filled(
                key: const Key('askSaathiSend'),
                tooltip: 'Send question',
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage(
    this.text,
    this.fromPatient, {
    this.source,
    this.error = false,
  });
  final String text;
  final bool fromPatient;
  final String? source;
  final bool error;
}

Widget _messageCard(
  String value,
  SaathiColors colors, {
  required bool fromPatient,
  bool error = false,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: error
          ? colors.emergencyTint
          : (fromPatient ? colors.primaryTint : colors.surface),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: colors.line.withValues(alpha: .42)),
    ),
    child: Text(
      cleanPatientFacingText(value),
      style: TextStyle(color: colors.text, height: 1.45),
    ),
  );
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.language});
  final _ChatMessage message;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    return Align(
      alignment: message.fromPatient
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .86,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.fromPatient)
              const Padding(
                padding: EdgeInsets.only(top: 3, right: 7),
                child: SaathiLogo(size: 34, showWordmark: false),
              ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _messageCard(
                    message.text,
                    colors,
                    fromPatient: message.fromPatient,
                    error: message.error,
                  ),
                  if (message.source != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 8),
                      child: Text(
                        'Source: ${message.source}',
                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                      ),
                    ),
                  if (!message.fromPatient &&
                      !message.error &&
                      message.source != null)
                    TextButton.icon(
                      onPressed: () => ReminderService.instance.speakSentence(
                        cleanPatientFacingText(message.text, forSpeech: true),
                        language,
                      ),
                      icon: const Icon(Icons.volume_up_rounded, size: 17),
                      label: const Text('Listen'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
