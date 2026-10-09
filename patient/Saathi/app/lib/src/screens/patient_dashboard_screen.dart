import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../app_controller.dart';
import '../data/placeholder_data.dart';
import '../l10n/app_text.dart';
import '../l10n/patient_time.dart';
import '../services/reminder_service.dart';
import '../theme.dart';
import '../utils/camera_lifecycle.dart';
import '../widgets/dashboard_cards.dart';
import '../widgets/draggable_listen_ball.dart';
import '../widgets/language_switch.dart';
import '../widgets/patient_widgets.dart';
import '../widgets/saathi_logo.dart';
import 'emergency_calling_screen.dart';
import 'more_screen.dart';
import 'next_appointment_screen.dart';
import 'prescription_screen.dart';
import 'medicines_screen.dart';
import 'health_summary_screen.dart';
import 'ask_saathi_sheet.dart';
import 'discharge_summary_screen.dart';

/// PATIENT DASHBOARD — the screen a patient lands on once their device is
/// linked, and the one they will open every day thereafter.
///
/// The whole screen is built around one assumption: the patient may not be
/// able to read it. So every element carries at least two of {icon, colour,
/// position, word}, the two facts that actually matter day to day (when to
/// come back, what to take today) are the largest things on the page, and both
/// can be heard rather than read.
///
/// PLACEHOLDER DATA: the appointment and today's dose come from
/// [mockNextAppointment] and [mockTodaysMedicine] in
/// lib/src/data/placeholder_data.dart, not from the backend. Phase 2 swaps
/// those two function bodies for `ApiClient` calls; nothing in this file or in
/// the cards it builds has to change.
class PatientDashboardScreen extends StatelessWidget {
  const PatientDashboardScreen({super.key, required this.controller});
  final AppController controller;

  /// Horizontal page padding. Read by [_FeatureGrid] to work out how much
  /// width the tiles actually get without a [LayoutBuilder].
  static const double hPadding = 16;

  @override
  Widget build(BuildContext context) {
    stopCameraHardware();
    controller.startClinicalRecordsSync();
    final colors = context.saathiColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final medicine = mockTodaysMedicine();

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final realAppointment = controller.nextAppointment;
        final appointment = realAppointment != null
            ? MockAppointment(
                date: realAppointment.date,
                doctorName: 'Dr. ${realAppointment.doctorName}',
                hospitalName: realAppointment.hospitalName,
                note: realAppointment.reason,
              )
            : mockNextAppointment();

        return Scaffold(
          backgroundColor: colors.page,
          body: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.page,
              gradient: isDark
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0, .48, 1],
                      colors: [
                        Color.lerp(colors.page, colors.primaryStrong, .20)!,
                        colors.page,
                        Color.lerp(colors.page, colors.primaryStrong, .09)!,
                      ],
                    )
                  : null,
            ),
            child: SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            await controller.fetchClinicalVisits(notify: true);
                          },
                          color: colors.primary,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              hPadding,
                              2,
                              hPadding,
                              MediaQuery.paddingOf(context).bottom,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight:
                                    constraints.maxHeight -
                                    2 -
                                    MediaQuery.paddingOf(context).bottom,
                              ),
                              child: IntrinsicHeight(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _Header(
                                      controller: controller,
                                      onMore: () => _open(
                                        context,
                                        MoreScreen(controller: controller),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _PatientGreeting(controller: controller),
                                    const SizedBox(height: 12),
                                    _AskSaathiBar(controller: controller),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: _FeatureGrid(controller: controller),
                                    ),
                                    const SizedBox(height: 16),
                                    EmergencyCard(
                                      onTap: () => _confirmEmergency(context),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      DraggableListenBall(
                        controller: controller,
                        bounds: constraints.biggest,
                        onListen: () =>
                            _speakScreen(context, appointment, medicine),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _confirmEmergency(BuildContext context) async {
    // Never dials on one tap. And even after confirming, nothing is dialled
    // yet: EmergencyCallingScreen is a placeholder that shows the calling
    // state and returns — see the note at the top of that file.
    final confirmed = await showEmergencyConfirmation(context);
    if (!confirmed || !context.mounted) return;
    _open(context, const EmergencyCallingScreen());
  }

  /// Reads the two facts on this screen that a patient came here for.
  void _speakScreen(
    BuildContext context,
    MockAppointment? appointment,
    MockTodayMedicine? medicine,
  ) {
    final text = AppText.of(context);
    final locale = text.language.code;
    final parts = <String>[];

    // Greet patient
    final greeting = text(greetingKeyForTime());
    final patientName = controller.patient?.name.trim();
    if (patientName != null && patientName.isNotEmpty) {
      parts.add('$greeting, $patientName.');
    } else {
      parts.add('$greeting.');
    }

    if (appointment != null) {
      parts.add(
        '${text(T.dashboardNextAppointment)}. '
        '${DateFormat.yMMMMEEEEd(locale).format(appointment.date)}. '
        '${formatPatientTime(appointment.date, text)}. '
        '${appointment.hospitalName}.',
      );
    }
    // Today's dose still gets read out here even though its card now lives on
    // the Medicines tab. A patient who presses Listen on the home screen wants
    // both facts, and hearing them costs no space.
    parts.add(medicineSentence(text, medicine));

    ReminderService.instance.speakSentence(parts.join(' '), text.language);
  }
}

enum _DocumentAction { add, capture }

/// Compact composer that opens the report-aware chat without leaving Home.
class _AskSaathiBar extends StatefulWidget {
  const _AskSaathiBar({required this.controller});
  final AppController controller;

  @override
  State<_AskSaathiBar> createState() => _AskSaathiBarState();
}

class _AskSaathiBarState extends State<_AskSaathiBar> {
  final _draft = TextEditingController();
  final _speech = stt.SpeechToText();
  bool _busy = false;
  bool _listening = false;
  String _recognizedBase = '';

  @override
  void dispose() {
    _speech.stop();
    _draft.dispose();
    super.dispose();
  }

  Future<void> _openSheet({bool submit = false, int? reportId}) async {
    FocusScope.of(context).unfocus();
    final draft = _draft.text;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      enableDrag: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: AskSaathiSheet(
          controller: widget.controller,
          initialDraft: draft,
          submitInitial: submit,
          initialReportId: reportId,
        ),
      ),
    );
    if (mounted) {
      FocusScope.of(context).unfocus();
      _draft.clear();
    }
  }

  Future<void> _chooseDocument(_DocumentAction action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final reportId = await pickAndReviewDischargeDocument(
        context,
        widget.controller,
        capture: action == _DocumentAction.capture,
      );
      if (mounted && reportId != null) await _openSheet(reportId: reportId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleMicrophone() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final ready = await _speech.initialize(
      onStatus: (status) {
        if (mounted && (status == 'done' || status == 'notListening')) {
          setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!ready || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Speech input is unavailable on this device.'),
        ));
      }
      return;
    }
    _recognizedBase = _draft.text.trim();
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: widget.controller.language == AppLanguage.kannada
            ? 'kn-IN'
            : 'en-IN',
      ),
      onResult: (result) {
        if (!mounted) return;
        final words = result.recognizedWords.trim();
        if (words.isNotEmpty) {
          final value = _recognizedBase.isEmpty ? words : '$_recognizedBase $words';
          _draft.value = TextEditingValue(
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
    return Container(
      key: const Key('askSaathiBar'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.primary.withValues(alpha: .30)),
        boxShadow: [BoxShadow(
          color: colors.brand.withValues(alpha: .08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        )],
      ),
      child: Row(children: [
        PopupMenuButton<_DocumentAction>(
          key: const Key('askSaathiPlus'),
          tooltip: 'Add or capture document',
          enabled: !_busy,
          position: PopupMenuPosition.under,
          offset: const Offset(0, 6),
          onSelected: _chooseDocument,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: _DocumentAction.add,
              child: Row(children: [
                Icon(Icons.description_outlined), SizedBox(width: 12),
                Flexible(child: Text('Add Document', style: TextStyle(fontSize: 14))),
              ]),
            ),
            PopupMenuItem(
              value: _DocumentAction.capture,
              child: Row(children: [
                Icon(Icons.camera_alt_outlined), SizedBox(width: 12),
                Flexible(child: Text('Capture Document', style: TextStyle(fontSize: 14))),
              ]),
            ),
          ],
          child: CircleAvatar(
            radius: 23,
            backgroundColor: colors.primaryTint,
            child: _busy
                ? const SizedBox.square(dimension: 19,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.add_rounded, color: colors.primary, size: 29),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          key: const Key('askSaathiDraft'),
          controller: _draft,
          onTap: () => _openSheet(),
          onSubmitted: (_) => _openSheet(submit: true),
          decoration: InputDecoration(
            hintText: 'Ask Saathi',
            isDense: true,
            filled: true,
            fillColor: colors.primaryTint.withValues(alpha: .45),
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(25),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        )),
        const SizedBox(width: 7),
        IconButton.filledTonal(
          key: const Key('askSaathiBarMicrophone'),
          tooltip: _listening ? 'Stop listening' : 'Speak to Saathi',
          onPressed: _toggleMicrophone,
          icon: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded),
        ),
        const SizedBox(width: 5),
        IconButton.filled(
          key: const Key('askSaathiBarSend'),
          tooltip: 'Send to Saathi',
          onPressed: () => _openSheet(submit: true),
          icon: const Icon(Icons.send_rounded),
        ),
      ]),
    );
  }
}

class _PatientGreeting extends StatelessWidget {
  const _PatientGreeting({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final text = AppText.of(context);
        final colors = context.saathiColors;
        final greeting = text(greetingKeyForTime());
        final patientName = controller.patient?.name.trim() ?? '';
        final hasName = patientName.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: hasName ? '$greeting, ' : greeting,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: colors.brand,
                  letterSpacing: -0.2,
                ),
                children: [
                  if (hasName)
                    TextSpan(
                      text: patientName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: colors.brand,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        );
      },
    );
  }
}

/// Centered brand mark with language and menu controls at the right.
///
/// The language pill sits on the dashboard itself rather than only in the app
/// bar of the screens below it. Language is the one control that decides
/// whether a patient can read anything at all, and a patient who has landed on
/// a screen they cannot read cannot be expected to find their way into a
/// settings page to fix that. It is the same [LanguageSwitchButton] used on the
/// linking screens — same globe, same current-language label in its own
/// script, same picker — so it is already familiar by the time they get here.
///
/// It is placed between the wordmark and the Listen button: reachable with the
/// thumb, and next to the other control that helps a patient who cannot read
/// the screen.
class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.onMore});
  final AppController controller;
  final VoidCallback onMore;

  static const double _controlsGap = 10;

  @override
  Widget build(BuildContext context) {
    final more = _MoreButton(onPressed: onMore);
    final language = LanguageSwitchButton(controller: controller);
    final refresh = _RefreshButton(controller: controller);
    final contentWidth =
        MediaQuery.sizeOf(context).width - PatientDashboardScreen.hPadding * 2;
    // On a normal-width screen, the emblem is aligned to the left,
    // with the controls aligned to the right.
    if (contentWidth >= 460) {
      return SizedBox(
        height: 126,
        child: Stack(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: _HeaderBrand(logoSize: 100, labelSize: 19),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  refresh,
                  const SizedBox(width: _controlsGap),
                  language,
                  const SizedBox(width: _controlsGap),
                  more,
                ],
              ),
            ),
          ],
        ),
      );
    }

    // On compact screens, place the brand on the left and controls on the
    // top right, scaling down gracefully at very high text scales so it never overflows.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const _HeaderBrand(logoSize: 56, labelSize: 13),
        const SizedBox(width: 4),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                refresh,
                const SizedBox(width: 5),
                language,
                const SizedBox(width: 5),
                more,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderBrand extends StatelessWidget {
  const _HeaderBrand({required this.logoSize, required this.labelSize});

  final double logoSize;
  final double labelSize;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SaathiLogo(size: logoSize, showWordmark: false),
      const SizedBox(height: 1),
      Text(
        'Saathi Patient App',
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: context.saathiColors.brand,
          fontWeight: FontWeight.w900,
          fontSize: labelSize,
          height: 1.1,
        ),
      ),
    ],
  );
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    return Tooltip(
      message: 'Refresh',
      child: Material(
        color: colors.surface.withValues(alpha: .94),
        shape: CircleBorder(
          side: BorderSide(color: colors.primary.withValues(alpha: .38)),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => controller.fetchClinicalVisits(notify: true),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.refresh_rounded, color: colors.primary),
          ),
        ),
      ),
    );
  }
}

/// The circular menu button in the top-right of the dashboard.
///
/// This is now the only way into [MoreScreen] — and through it, Settings —
/// since the bottom navigation was removed. A three-line hamburger glyph:
/// the 2x2 grid of dots it replaced tested poorly with first-time users, who
/// read it as decoration rather than a menu control. The hamburger is the
/// one "menu" symbol that needs no explanation.
class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onPressed});
  final VoidCallback onPressed;

  /// The button's own diameter, for callers that need to reserve room for it
  /// — see the header's wordmark-vs-two-line budget calculation, which must
  /// agree with this exactly or it could pre-approve a layout that then
  /// doesn't fit.
  static double size(BuildContext context) => scaledIcon(
    context,
    kMoreButtonBaseSize,
  ).clamp(kMoreButtonBaseSize, kMoreButtonMaxSize);

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final colors = context.saathiColors;
    final buttonSize = size(context);

    return Semantics(
      button: true,
      label: text(T.navMore),
      excludeSemantics: true,
      child: Material(
        color: colors.primaryTint,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onPressed();
          },
          child: SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: Icon(
              Icons.menu_rounded,
              size: buttonSize * .46,
              color: colors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The 2x2 grid of everyday features.
///
/// Collapses to a single column on a narrow screen or at a large system font
/// scale. Two cards side by side on a 320dp phone at 2x text leaves each
/// title about four characters wide, which is unreadable however neatly it
/// wraps — one full-width card per row is the better trade.
class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.controller});
  final AppController controller;

  static const _gap = 6.0;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final colors = context.saathiColors;

    final cards = <Widget>[
      DashboardFeatureCard(
        icon: Icons.description_rounded,
        title: text(T.dashboardMyPrescription),
        description: text(T.dashboardMyPrescriptionHint),
        accent: colors.primary,
        tint: colors.primaryTint,
        onTap: () => _push(context, PrescriptionScreen(controller: controller)),
      ),
      DashboardFeatureCard(
        icon: Icons.medication_rounded,
        title: text(T.dashboardMedicines),
        description: text(T.dashboardMedicinesHint),
        accent: colors.info,
        tint: colors.infoTint,
        onTap: () => _push(context, MedicinesScreen(controller: controller)),
      ),
      DashboardFeatureCard(
        icon: Icons.event_available_rounded,
        title: text(T.dashboardAppointments),
        description: text(T.dashboardAppointmentsHint),
        accent: colors.primary,
        tint: colors.primaryTint,
        onTap: () =>
            _push(context, NextAppointmentScreen(controller: controller)),
      ),
      DashboardFeatureCard(
        icon: Icons.assignment_rounded,
        title: text(T.dashboardHealthSummary),
        description: text(T.dashboardHealthSummaryHint),
        accent: colors.info,
        tint: colors.infoTint,
        onTap: () =>
            _push(context, HealthSummaryScreen(controller: controller)),
      ),
    ];
    // Width is taken from the screen rather than a [LayoutBuilder]: the
    // dashboard measures this grid's intrinsic height to distribute its spare
    // vertical space, and intrinsics cannot be computed through a
    // LayoutBuilder. The grid always spans the page's content width, so
    // subtracting the screen padding gives the same answer.
    final available =
        MediaQuery.sizeOf(context).width - PatientDashboardScreen.hPadding * 2;

    // 300dp is the point where two tiles side by side stop being able to hold
    // their titles on one line. Above it — which includes every 360dp-wide
    // phone — the 2x2 grid the design calls for is kept.
    if (scale > 1.45 || available < 300) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: _gap),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }
    return Column(
      children: [
        Expanded(child: _GridRow(left: cards[0], right: cards[1])),
        const SizedBox(height: _gap),
        Expanded(child: _GridRow(left: cards[2], right: cards[3])),
      ],
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

/// Two tiles of equal height, whatever their content.
///
/// [IntrinsicHeight] rather than a fixed aspect ratio: a translation that
/// wraps onto a third line grows the row instead of overflowing it, which is
/// what a fixed-ratio GridView would do here in Hindi and Kannada.
class _GridRow extends StatelessWidget {
  const _GridRow({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: _FeatureGrid._gap),
          Expanded(child: right),
        ],
      ),
    );
  }
}
