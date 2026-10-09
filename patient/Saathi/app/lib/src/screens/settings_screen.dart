import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
// placeholder_data removed — test reminder uses a generic medicine name
import '../l10n/app_text.dart';
import '../services/reminder_service.dart';
import '../settings.dart';
import '../theme.dart';
import '../widgets/patient_scaffold.dart';

/// The app version shown in About.
///
/// Hardcoded rather than read from the package: `package_info_plus` is not in
/// this app's approved package list. Keep in step with `version:` in
/// pubspec.yaml.
const String kAppVersion = '1.0.0';

/// SETTINGS.
///
/// Everything on this screen is either a display control or read-only
/// information. There is deliberately no sign-out, no unlink, no "delete my
/// data" and no account management anywhere on it: this device was linked by
/// hospital staff, and a patient who can undo that has to travel back to the
/// hospital to be let back in. That control stays with the people who granted
/// it.
///
/// The layout is one flat scrolling page rather than a menu of sub-pages. For
/// a patient who navigates by recognising where things are on a screen, a
/// setting hidden one tap deeper is a setting they will not find twice.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => PatientScaffold(
        title: text(T.settingsTitle),
        controller: controller,
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LanguageSection(controller: controller),
              const SizedBox(height: 18),
              _TextSizeSection(controller: controller),
              const SizedBox(height: 18),
              _AppearanceSection(controller: controller),
              const SizedBox(height: 18),
              _VoiceSection(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return PatientScaffold(
      title: text(T.settingsHelpSection),
      controller: controller,
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: _HelpSection(),
      ),
    );
  }
}

/// SUPPORT — reachable from the More menu.
///
/// Reuses [_HospitalSection] rather than duplicating it: "how do I get help"
/// and "who is my hospital and how do I reach them" are the same question
/// for this app, since every patient's support line is their own hospital's
/// reception, not a Saathi help desk.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return PatientScaffold(
      title: text(T.supportTitle),
      controller: controller,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: _HospitalSection(controller: controller),
      ),
    );
  }
}

/// PRIVACY & SECURITY — reachable from the More menu.
///
/// Reuses [_AboutSection]: the privacy note and the app version are the same
/// content this screen would otherwise show, so this is that section given
/// its own reachable page rather than a copy of it.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return PatientScaffold(
      title: text(T.privacySecurityTitle),
      controller: controller,
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: _AboutSection(),
      ),
    );
  }
}

/// A titled block. Every section on this screen is one of these, so a patient
/// scanning the page sees the same shape repeat rather than six layouts.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final colors = context.saathiColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(kDashboardRadius),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.primary, size: scaledIcon(context, 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: colors.text,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// A horizontal row of equal-width pill buttons — one per [values] entry.
///
/// Replaces the old stacked _ChoiceRow list in Language and Text Size sections.
/// All buttons share available width equally (using [Expanded]) so they sit
/// neatly side by side without overflowing on narrow phones.
class _SegmentedChoice<T> extends StatelessWidget {
  const _SegmentedChoice({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onTap,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final void Function(T) onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _SegmentButton<T>(
              value: values[i],
              label: labelOf(values[i]),
              selected: values[i] == selected,
              onTap: onTap,
              colors: colors,
            ),
          ),
        ],
      ],
    );
  }
}

class _SegmentButton<T> extends StatelessWidget {
  const _SegmentButton({
    required this.value,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  final T value;
  final String label;
  final bool selected;
  final void Function(T) onTap;
  final SaathiColors colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.primary : colors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap(value);
          },
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? colors.primary : colors.line,
                width: selected ? 2 : 1,
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: selected ? colors.surface : colors.text,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageSection extends StatelessWidget {
  const _LanguageSection({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return _Section(
      icon: Icons.language_rounded,
      title: text(T.settingsLanguageSection),
      subtitle: text(T.chooseLanguageHint),
      child: _SegmentedChoice<AppLanguage>(
        values: AppLanguage.values,
        selected: controller.language,
        labelOf: (language) => language.nativeLabel,
        onTap: (language) => controller.setLanguage(language),
      ),
    );
  }
}

class _TextSizeSection extends StatelessWidget {
  const _TextSizeSection({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    const labels = {
      PatientTextSize.normal: T.settingsTextSizeNormal,
      PatientTextSize.large: T.settingsTextSizeLarge,
      PatientTextSize.largest: T.settingsTextSizeLargest,
    };

    return _Section(
      icon: Icons.format_size_rounded,
      title: text(T.settingsTextSizeSection),
      subtitle: text(T.settingsTextSizeHint),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SegmentedChoice<PatientTextSize>(
            values: PatientTextSize.values,
            selected: controller.textSize,
            labelOf: (size) => text(labels[size]!),
            onTap: (size) => controller.setTextSize(size),
          ),
          const SizedBox(height: 4),
          // Live sample. Already inside the MediaQuery the setting drives, so
          // it resizes the instant a row is pressed.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.saathiColors.primaryTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              text(T.settingsTextSizePreview),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.saathiColors.text,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    const labels = {
      SaathiThemeMode.system: T.settingsThemeSystem,
      SaathiThemeMode.light: T.settingsThemeLight,
      SaathiThemeMode.dark: T.settingsThemeDark,
    };

    return _Section(
      icon: Icons.contrast_rounded,
      title: text(T.settingsAppearanceSection),
      subtitle: text(T.settingsThemeHint),
      child: Column(
        children: [
          _SegmentedChoice<SaathiThemeMode>(
            values: SaathiThemeMode.values,
            selected: controller.themeMode,
            labelOf: (mode) => text(labels[mode]!),
            onTap: (mode) => controller.setThemeMode(mode),
          ),
          const SizedBox(height: 10),
          _PreferenceSwitch(
            icon: Icons.format_bold_rounded,
            title: text(T.settingsBoldText),
            subtitle: text(T.settingsBoldTextHint),
            value: controller.boldText,
            onChanged: controller.setBoldText,
          ),
          const SizedBox(height: 10),
          _PreferenceSwitch(
            icon: Icons.visibility_rounded,
            title: text(T.settingsHighContrast),
            subtitle: text(T.settingsHighContrastHint),
            value: controller.highContrast,
            onChanged: controller.setHighContrast,
          ),
        ],
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    return Semantics(
      toggled: value,
      child: Material(
        color: value ? colors.primaryTint : colors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: kPatientMinTarget),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: value ? colors.primary : colors.line,
                width: value ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceSection extends StatelessWidget {
  const _VoiceSection({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    const labels = {
      VoiceSpeed.slow: T.settingsVoiceSlow,
      VoiceSpeed.normal: T.settingsVoiceNormal,
      VoiceSpeed.fast: T.settingsVoiceFast,
    };

    return _Section(
      icon: Icons.record_voice_over_rounded,
      title: text(T.settingsVoiceSection),
      subtitle: text(T.settingsVoiceHint),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SegmentedChoice<VoiceSpeed>(
            values: VoiceSpeed.values,
            selected: controller.voiceSpeed,
            labelOf: (speed) => text(labels[speed]!),
            // Speaks the sample as it changes, so the setting is judged by
            // ear instead of by guessing what "Slow" means.
            onTap: (speed) async {
              await controller.setVoiceSpeed(speed);
              await ReminderService.instance.speakSentence(
                text(T.settingsVoiceSample),
                controller.language,
              );
            },
          ),
          const SizedBox(height: 4),
          _SpeakButton(
            label: text(T.settingsVoiceTry),
            onPressed: () => ReminderService.instance.speakSentence(
              text(T.settingsVoiceSample),
              controller.language,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            text(T.settingsTestReminderHint),
            style: TextStyle(
              color: context.saathiColors.textMuted,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('test-medicine-reminder'),
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
                    SnackBar(
                      content: Text('Notifications unavailable: $error'),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.notifications_active_rounded),
            label: const Text('Test notification in 30 seconds'),
          ),
          TextButton.icon(
            onPressed: controller.patient == null
                ? null
                : () {
                    final history = ReminderService.instance.reminderHistory(
                      controller.patient!.id,
                    );
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Reminder history on this phone'),
                        content: SizedBox(
                          width: 360,
                          height: 340,
                          child: FutureBuilder<List<Map<String, dynamic>>>(
                            future: history,
                            builder: (ctx, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final entries = snapshot.data!;
                              if (entries.isEmpty) {
                                return const Text(
                                  'No doses recorded on this phone.',
                                );
                              }
                              return ListView.builder(
                                itemCount: entries.length,
                                itemBuilder: (ctx, index) {
                                  final entry = entries[index];
                                  return ListTile(
                                    title: Text(
                                      entry['medicineName']?.toString() ??
                                          'Medicine',
                                    ),
                                    subtitle: Text(
                                      '${entry['scheduledDate']} · ${entry['timeSlot']} · '
                                      '${entry['sourceKey']?.toString().startsWith('pdf:') == true ? 'Uploaded report' : 'Saathi doctor'}',
                                    ),
                                    trailing: Text(
                                      entry['status']?.toString() ?? '',
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
            icon: const Icon(Icons.history_rounded),
            label: const Text('Reminder history'),
          ),
          const SizedBox(height: 8),
          FutureBuilder(
            future: ReminderService.instance.status(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final status = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${status.notifications ? 'Notifications enabled' : 'Notifications disabled'} · '
                    '${status.exact ? 'Exact timing available' : 'Android may delay reminders'} · '
                    '${status.pending} pending alerts. Battery restrictions may also delay delivery.',
                    style: TextStyle(color: context.saathiColors.textMuted),
                  ),
                  if (!status.exact)
                    TextButton(
                      onPressed: () async {
                        final allowed = await ReminderService.instance
                            .requestExactTiming();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                allowed
                                    ? 'Precise timing allowed. Reopen reminders to refresh schedules.'
                                    : 'Precise timing unavailable; Android may delay alerts.',
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Check precise timing access'),
                    ),
                  if (!status.notifications)
                    const Text(
                      'Allow Saathi notifications in Android app settings, then retry the test.',
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// "Read this out" — an outlined button whose label can wrap.
///
/// Not [OutlinedButton.icon]: that lays its icon and label out in a Row with
/// neither made flexible, so at a large font scale on a narrow phone the label
/// runs past the button's edge instead of wrapping.
///
/// Turns into a Stop button while the shared TTS engine is speaking, same as
/// [ListenButton] elsewhere in the app — there is one engine, so whichever
/// button reads something out, this one can always silence it.
class _SpeakButton extends StatelessWidget {
  const _SpeakButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final colors = context.saathiColors;
    return ValueListenableBuilder<bool>(
      valueListenable: ReminderService.instance.isSpeaking,
      builder: (context, speaking, _) {
        final label = speaking ? text(T.dashboardStop) : this.label;
        final onPressed = speaking
            ? ReminderService.instance.stopSpeaking
            : this.onPressed;

        return OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: colors.surfaceRaised,
            side: BorderSide(
              color: speaking ? colors.emergency : colors.primary,
              width: 2,
            ),
            foregroundColor: speaking ? colors.emergency : colors.primary,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                size: scaledIcon(context, 24),
              ),
              const SizedBox(width: 10),
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          ),
        );
      },
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection();

  static const _steps = [
    T.settingsHelpStep1,
    T.settingsHelpStep2,
    T.settingsHelpStep3,
    T.settingsHelpStep4,
  ];

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return _Section(
      icon: Icons.help_outline_rounded,
      title: text(T.settingsHelpSection),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _HelpStep(number: i + 1, body: text(_steps[i])),
          ],
          const SizedBox(height: 16),
          // The help text can itself be heard — the patients least likely to
          // read four paragraphs of instructions are exactly the ones this
          // section is written for.
          _SpeakButton(
            label: text(T.settingsHelpListen),
            onPressed: () => ReminderService.instance.speakSentence(
              _steps.map(text.call).join(' '),
              text.language,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpStep extends StatelessWidget {
  const _HelpStep({required this.number, required this.body});
  final int number;
  final String body;

  @override
  Widget build(BuildContext context) {
    final disc = scaledIcon(context, 30).clamp(30.0, 44.0);
    final colors = context.saathiColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: disc,
          height: disc,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primaryTint,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: colors.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            body,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: colors.text,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Read-only hospital and device information.
///
/// Hospital name and contact details will be pulled from the backend once a
/// /hospitals endpoint is added. For now, shows placeholder text alongside
/// the real patient name and ID from the linked session.
class _HospitalSection extends StatelessWidget {
  const _HospitalSection({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final colors = context.saathiColors;
    final patient = controller.patient;

    return _Section(
      icon: Icons.local_hospital_rounded,
      title: text(T.settingsHospitalSection),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(
            label: text(T.settingsHospitalSection),
            value: 'Your linked hospital',
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: text(T.settingsHospitalReception),
            value: (patient?.receptionistName?.trim().isNotEmpty ?? false)
                ? patient!.receptionistName!.trim()
                : 'Receptionist',
            emphasise: true,
          ),
          const SizedBox(height: 4),
          Text(
            'Hospital contact details will appear here once available.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text(T.settingsHospitalCallNote),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
              height: 1.35,
            ),
          ),
          if (patient != null) ...[
            const SizedBox(height: 16),
            Divider(color: colors.line, height: 1),
            const SizedBox(height: 16),
            _InfoRow(
              label: text(T.settingsYourDetailsSection),
              value: patient.name,
            ),
            const SizedBox(height: 12),
            _InfoRow(label: text(T.yourId), value: patient.uid),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.admin_panel_settings_rounded,
                color: colors.primary,
                size: scaledIcon(context, 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text(T.deviceManaged),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.textMuted,
                    height: 1.3,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: colors.textMuted,
            letterSpacing: .6,
          ),
        ),
        const SizedBox(height: 3),
        SelectableText(
          value,
          style: TextStyle(
            fontSize: emphasise ? 24 : 19,
            fontWeight: FontWeight.w900,
            color: colors.text,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final colors = context.saathiColors;
    return _Section(
      icon: Icons.info_outline_rounded,
      title: text(T.settingsAboutSection),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(label: text(T.settingsVersion), value: kAppVersion),
          const SizedBox(height: 14),
          Text(
            text(T.settingsPrivacyBody),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
