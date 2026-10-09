import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_text.dart';
import '../theme.dart';

/// A primary patient action — the large white cards on the home screen.
///
/// These are deliberately *not* solid colour blocks. Dark text on white is the
/// most legible combination for a low-vision reader, and it leaves solid fill
/// free to mean one thing only: emergency. Each action is told apart by four
/// signals at once — icon, icon colour, border colour, and position — so the
/// screen still works for a patient with red-green colour blindness, which
/// affects roughly one man in twelve.
class PatientActionButton extends StatelessWidget {
  const PatientActionButton({
    super.key,
    required this.accent,
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final Color accent;
  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tileSize = scaledIcon(context, 76);
    final colors = context.saathiColors;
    return Semantics(
      button: true,
      label: '$label. $hint',
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent, width: 3),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kPatientActionHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: tileSize,
                      height: tileSize,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        icon,
                        size: tileSize * .55,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              color: colors.text,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            hint,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colors.textMuted,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: scaledIcon(context, 34),
                      color: accent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The emergency control.
///
/// Three things make this safe against a mis-tap while still being the fastest
/// thing on the screen to find:
///
///  1. It is the only solid-filled, only red element in the entire patient app.
///     Nothing else can be mistaken for it and it cannot be mistaken for
///     anything else.
///  2. It sits below a divider, separated from the everyday actions, so it is
///     not inside the block of buttons a patient taps casually.
///  3. Tapping it opens a confirmation — it never places a call on one tap.
class EmergencyButton extends StatelessWidget {
  const EmergencyButton({super.key, required this.onConfirmed});

  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final iconSize = scaledIcon(context, 40);
    final colors = context.saathiColors;
    return Semantics(
      button: true,
      label: '${text(T.emergency)}. ${text(T.emergencyHint)}',
      excludeSemantics: true,
      child: Material(
        color: colors.emergency,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () async {
            HapticFeedback.heavyImpact();
            final confirmed = await showEmergencyConfirmation(context);
            if (confirmed) onConfirmed();
          },
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.emergencyStrong, width: 3),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kPatientActionHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.emergency_rounded,
                      size: iconSize,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            text(T.emergency),
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.1,
                              letterSpacing: .5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            text(T.emergencyHint),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              // Pure white rather than white70: the old
                              // white70-on-red fell below AA contrast.
                              color: Color(0xFFFFE9E7),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen confirmation for the emergency action.
///
/// Note the button order: CALL is above, GO BACK is below. The emergency
/// button sits at the bottom of the home screen, so if a patient double-taps
/// it by accident the second tap lands near the bottom of this sheet — which
/// is the safe, cancelling option. The dangerous option is never under the
/// finger that just tapped.
Future<bool> showEmergencyConfirmation(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      final text = AppText.of(context);
      final colors = context.saathiColors;
      return Dialog.fullscreen(
        backgroundColor: colors.emergencyTint,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 32, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: scaledIcon(context, 96),
                    height: scaledIcon(context, 96),
                    decoration: BoxDecoration(
                      color: colors.emergency,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emergency_rounded,
                      color: Colors.white,
                      size: scaledIcon(context, 52),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  text(T.emergencyConfirmTitle),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFFFF5F4),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  text(T.emergencyConfirmBody),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFFDAD6),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 36),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.emergency,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(88),
                    textStyle: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  icon: Icon(
                    Icons.phone_in_talk_rounded,
                    size: scaledIcon(context, 28),
                  ),
                  label: Text(text(T.emergencyConfirmYes)),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.text,
                    side: BorderSide(color: colors.text, width: 2),
                    minimumSize: const Size.fromHeight(88),
                    textStyle: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  child: Text(text(T.emergencyConfirmNo)),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
}

/// The app's primary action button.
///
/// One component for every primary action in the patient flow — "Ask staff to
/// start setup", "Link this phone" — so they share metrics, radius and the
/// green glow rather than drifting apart per screen. Pass [trailingArrow] to
/// get the circular arrow badge pinned to the trailing edge.
class PatientPrimaryButton extends StatelessWidget {
  const PatientPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailingArrow = true,
    this.busy = false,
  });

  final String label;

  /// Null disables the button — used while a link request is in flight.
  final VoidCallback? onPressed;
  final bool trailingArrow;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final colors = context.saathiColors;
    final fill = enabled
        ? colors.primaryStrong
        : colors.primaryStrong.withValues(alpha: .45);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: colors.primaryStrong.withValues(alpha: .34),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 78),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: trailingArrow ? 40 : 8,
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (trailingArrow)
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: busy
                              ? const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.6,
                                  ),
                                )
                              // Outlined circle, not a filled one: the solid
                              // white disc pulled the eye away from the label.
                              : DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: .85,
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One calm, non-technical screen state, used for loading, empty and error.
///
/// Patients never see a stack trace, an HTTP status code, or the word "error".
/// Every state says what happened in plain words and, where the patient can do
/// something about it, gives them exactly one button.
class PatientStateView extends StatelessWidget {
  const PatientStateView({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.tone = saathiGreen,
    this.busy = false,
  });

  const PatientStateView.loading({super.key, required this.title})
    : icon = Icons.favorite_rounded,
      body = null,
      actionLabel = null,
      onAction = null,
      tone = saathiGreen,
      busy = true;

  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color tone;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final circle = scaledIcon(context, 104);
    final colors = context.saathiColors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: circle,
              height: circle,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: .10),
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (busy)
                    SizedBox(
                      width: circle,
                      height: circle,
                      child: CircularProgressIndicator(
                        color: tone,
                        strokeWidth: 5,
                      ),
                    ),
                  Icon(icon, size: circle * .42, color: tone),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: colors.text,
                height: 1.25,
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 12),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                  height: 1.5,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 30),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: tone,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(74),
                  textStyle: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
