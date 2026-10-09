import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n/app_text.dart';
import '../services/reminder_service.dart';
import '../theme.dart';
import '../widgets/patient_scaffold.dart';
import 'settings_screen.dart';
import 'visit_history_screen.dart';

/// MORE — everything that isn't frequent enough to earn a spot on the
/// dashboard grid: help, settings, past visits, support and the privacy
/// note.
///
/// A plain list of equal-sized rows rather than the dashboard's cards,
/// deliberately: this screen has to look different from the dashboard at a
/// glance, or a patient skimming past it would mistake it for a second
/// feature grid.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final colors = context.saathiColors;
    return PatientScaffold(
      title: text(T.moreTitle),
      controller: controller,
      // Reads the list of what's on this screen — there is no single fact
      // this page exists to convey the way the dashboard's appointment and
      // medicine are, so the ball reads the menu itself, in order.
      onListen: () => ReminderService.instance.speakSentence(
        [
          text(T.moreTitle),
          text(T.settingsHelpSection),
          text(T.settingsTitle),
          text(T.pastVisits),
          text(T.supportTitle),
          text(T.privacySecurityTitle),
        ].join('. '),
        text.language,
      ),
      // Rows packed together near the top rather than spread to fill the
      // page: a short list of options reads as a deliberate, scannable menu
      // this way, the way it does on the reference design. Below the rows,
      // the page is free for the floating Listen ball to rest without
      // sitting on top of anything.
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _MoreGreeting(),
            const SizedBox(height: 20),
            // "How to use this app" leads the list: a patient who is lost
            // anywhere else in the app is most likely to come here first.
            _MoreMenuRow(
              key: const Key('more-help-row'),
              icon: Icons.help_outline_rounded,
              title: text(T.settingsHelpSection),
              hint: text(T.settingsHelpStep3),
              onTap: () => _push(context, HelpScreen(controller: controller)),
            ),
            const SizedBox(height: 10),
            _MoreMenuRow(
              key: const Key('more-settings-row'),
              icon: Icons.settings_rounded,
              title: text(T.settingsTitle),
              hint: text(T.settingsHint),
              onTap: () =>
                  _push(context, SettingsScreen(controller: controller)),
            ),
            const SizedBox(height: 10),
            _MoreMenuRow(
              key: const Key('more-visits-row'),
              icon: Icons.history_rounded,
              title: text(T.pastVisits),
              hint: text(T.pastVisitsHint),
              onTap: () =>
                  _push(context, VisitHistoryScreen(controller: controller)),
            ),
            const SizedBox(height: 10),
            _MoreMenuRow(
              key: const Key('more-support-row'),
              icon: Icons.support_agent_rounded,
              title: text(T.supportTitle),
              hint: text(T.supportHint),
              onTap: () =>
                  _push(context, SupportScreen(controller: controller)),
            ),
            const SizedBox(height: 10),
            _MoreMenuRow(
              key: const Key('more-privacy-row'),
              icon: Icons.security_rounded,
              title: text(T.privacySecurityTitle),
              hint: text(T.privacySecurityHint),
              onTap: () =>
                  _push(context, PrivacyScreen(controller: controller)),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: colors.primaryTint,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.line),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings_rounded,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text(T.deviceManaged),
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

/// The greeting above the menu: a friendly line telling the patient what this
/// screen is for, beside a soft decorative mark.
///
/// The illustration is drawn from the app's own icon set on a tinted disc
/// rather than a bespoke asset — it is decoration, so it carries no semantics
/// of its own and is excluded from the accessibility tree; the greeting text
/// beside it is what a screen reader announces.
class _MoreGreeting extends StatelessWidget {
  const _MoreGreeting();

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final colors = context.saathiColors;
    final disc = scaledIcon(context, 76).clamp(76.0, 104.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            width: disc,
            height: disc,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colors.primaryTint,
                    shape: BoxShape.circle,
                  ),
                ),
                Icon(
                  Icons.forum_rounded,
                  size: disc * .46,
                  color: colors.primary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text(T.moreGreeting),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: colors.primary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                text(T.moreGreetingBody),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One row of the More menu: icon, title, chevron — nothing else.
///
/// Every row reserves the same title-block height regardless of how long its
/// own title is, via [lineHeightOf] — the same technique
/// [DashboardFeatureCard] uses and for the same reason: "Privacy & Security"
/// and "How to use this app" are long enough to wrap onto a second line at a
/// large accessibility text scale, while "Settings" and "Support" never do,
/// and without a shared reservation the rows wrapping to two lines would grow
/// taller than the ones that don't.
class _MoreMenuRow extends StatelessWidget {
  const _MoreMenuRow({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String title;

  /// Spoken to screen readers alongside [title] — the row shows only the
  /// title and an icon, but a patient using TalkBack or VoiceOver still gets
  /// the fuller context a sighted patient reads from the icon alone.
  final String hint;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    const titleStyle = TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w900,
      height: 1.2,
    );
    final titleBlockHeight = lineHeightOf(context, titleStyle) * 2;

    return Semantics(
      button: true,
      label: '$title. $hint',
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.line),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.primaryTint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: colors.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: titleBlockHeight,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle.copyWith(color: colors.text),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: colors.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
