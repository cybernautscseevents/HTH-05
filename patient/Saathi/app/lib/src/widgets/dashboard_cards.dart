import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/placeholder_data.dart';
import '../l10n/app_text.dart';
import '../l10n/patient_time.dart';
import '../theme.dart';
import 'listen_button.dart';

/// Text scale past which side-by-side layouts inside a card are abandoned for
/// stacked ones.
///
/// Below this, an icon and a paragraph fit comfortably beside each other on a
/// small phone. Above it the text column gets squeezed into a two-word-wide
/// ribbon, which is worse to read than simply putting the icon on its own row.
const double _stackedLayoutScale = 1.45;

double _textScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(16) / 16;

/// The spoken form of today's dose — what to take, how much, how and when.
///
/// Shared by every "Listen" control that reads a medicine out, so the sentence
/// a patient hears is identical wherever they press it.
String medicineSentence(AppText text, MockTodayMedicine? medicine) {
  if (medicine == null) {
    return '${text(T.dashboardTodaysMedicine)}. '
        '${text(T.dashboardNoMedicineToday)}.';
  }
  return '${text(T.dashboardTodaysMedicine)}. '
      '${medicine.medicineName}. ${medicine.dosage}. '
      '${text(medicine.instruction)}. '
      '${formatPatientTime(medicine.scheduledAtToday(), text)}.';
}

/// The hero card: when the patient next has to come to the hospital.
///
/// The single most important thing on the dashboard after the brand, so it is
/// the only large solid-green surface on the screen. Everything else is white,
/// tinted, or (once) red.
///
/// The whole card is one tap target rather than the arrow being its own
/// button. A 300dp-wide target cannot be missed by an unsteady hand, and a
/// small arrow sitting inside a large tappable card teaches the patient that
/// they must aim for the arrow, which is exactly the wrong lesson.
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
  });

  /// Null when the patient has no upcoming appointment — rendered as an
  /// explicit, calm empty state rather than an absent card, so the layout of
  /// the screen does not change shape between patients.
  final MockAppointment? appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final colors = context.saathiColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = text.language.code;
    final booked = appointment;

    final semantics = booked == null
        ? '${text(T.dashboardNextAppointment)}. '
              '${text(T.appointmentNobooked)}'
        : '${text(T.dashboardNextAppointment)}. '
              '${DateFormat.yMMMMEEEEd(locale).format(booked.date)}. '
              '${DateFormat.jm(locale).format(booked.date)}.';

    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      // The lift lives on an outer box, not on the Material's own Ink
      // decoration. A BoxShadow inside an Ink decoration that has no fill
      // colour is painted *through* the card, tinting its whole face.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kDashboardRadius),
          boxShadow: [
            BoxShadow(
              color: (isDark ? colors.primary : colors.primaryStrong)
                  .withValues(alpha: isDark ? .24 : .38),
              blurRadius: isDark ? 28 : 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kHeroCardMinHeight),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(kDashboardRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: Ink(
                decoration: BoxDecoration(
                  color: colors.primaryStrong,
                  gradient: isDark
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.lerp(colors.primaryStrong, colors.teal, .13)!,
                            Color.lerp(colors.primaryStrong, colors.page, .18)!,
                          ],
                        )
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kHeroCardPadX,
                    vertical: kHeroCardPadY,
                  ),
                  child: _textScale(context) > _stackedLayoutScale
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const _CalendarBadge(),
                                const _ForwardChip(),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _AppointmentDetails(appointment: booked),
                          ],
                        )
                      : Row(
                          children: [
                            const _CalendarBadge(),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _AppointmentDetails(appointment: booked),
                            ),
                            const SizedBox(width: 8),
                            const _ForwardChip(),
                          ],
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

class _AppointmentDetails extends StatelessWidget {
  const _AppointmentDetails({required this.appointment});
  final MockAppointment? appointment;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final locale = text.language.code;
    final booked = appointment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text(T.dashboardNextAppointment),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFFDCEEFF),
            height: 1.15,
          ),
        ),
        const SizedBox(height: 2),
        if (booked == null)
          Text(
            text(T.appointmentNobooked),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.2,
            ),
          )
        else ...[
          // The date and the weekday/time line are kept to one line each.
          // Wrapped, "26 August 2026" splits after the month and reads as two
          // separate facts; shrunk very slightly, it stays one date. Both fall
          // back to full size the moment there is room — and past
          // [_stackedLayoutScale] the card restacks and gives them the full
          // width instead of shrinking them further.
          _OneLine(
            child: Text(
              // "15 May 2025" — day first, which is how the date is written
              // and spoken in India, and how the hospital's own slip prints
              // it.
              DateFormat('d MMMM yyyy', locale).format(booked.date),
              maxLines: 1,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 2),
          _OneLine(
            child: Text(
              '${DateFormat.EEEE(locale).format(booked.date)}  •  '
              '${formatPatientTime(booked.date, text)}',
              maxLines: 1,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFFDCEEFF),
                height: 1.2,
              ),
            ),
          ),
          if (booked.note?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    booked.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

/// Holds a single line of text at its natural size, shrinking it only as far
/// as the available width actually requires.
class _OneLine extends StatelessWidget {
  const _OneLine({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}

/// Calendar disc with a "confirmed" tick, matching the approved design.
class _CalendarBadge extends StatelessWidget {
  const _CalendarBadge();

  @override
  Widget build(BuildContext context) {
    const baseSize = kHeroBadgeSize;
    final size = scaledIcon(context, baseSize).clamp(baseSize, 88.0);
    final colors = context.saathiColors;
    final tick = size * .34;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: Color(0xFFE5F4FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_month_rounded,
              size: size * .52,
              color: colors.primaryStrong,
            ),
          ),
          Positioned(
            right: 0,
            bottom: size * .08,
            child: Container(
              width: tick,
              height: tick,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5F4FF), width: 2),
              ),
              child: Icon(
                Icons.check_rounded,
                size: tick * .62,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The circular arrow on the hero card. Decoration, not a second tap target —
/// see the note on [AppointmentCard].
class _ForwardChip extends StatelessWidget {
  const _ForwardChip();

  @override
  Widget build(BuildContext context) {
    const baseSize = kHeroArrowSize;
    final size = scaledIcon(context, baseSize).clamp(baseSize, 60.0);
    final colors = context.saathiColors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: colors.onStrong, shape: BoxShape.circle),
      child: Icon(
        Icons.arrow_forward_rounded,
        size: size * .52,
        color: colors.primaryStrong,
      ),
    );
  }
}

/// One tile of the 2x2 dashboard grid.
///
/// Four signals distinguish the tiles from each other — icon, accent colour,
/// position and label — so the grid still works for a patient with red-green
/// colour blindness, and for one who cannot read the labels at all.
class DashboardFeatureCard extends StatelessWidget {
  const DashboardFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String title;

  /// Spoken to screen readers alongside [title] so the tile's purpose is
  /// still announced even though the grid no longer prints it — the visual
  /// design calls for icon, title and arrow only.
  final String description;

  /// Icon and title colour. One of [saathiGreen] or [saathiInfoNavy].
  final Color accent;

  /// Pale disc behind the icon. The tint that pairs with [accent].
  final Color tint;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const baseDisc = kFeatureDiscSize;
    final disc = scaledIcon(context, baseDisc).clamp(baseDisc, 80.0);
    final colors = context.saathiColors;
    final borderColor = isDark
        ? Color.lerp(colors.line, colors.textMuted, .62)!
        : colors.line;
    const titleStyle = TextStyle(
      fontSize: 15.5,
      fontWeight: FontWeight.w900,
      height: 1.15,
    );
    // Reserved at two lines' height regardless of how many the title
    // actually uses — "My Prescription" and "Appointments" fit on one line,
    // "Medicine Reminders" and "Health Summary" wrap to two. Without this,
    // whichever pair shares a grid row with a two-line title stretches to
    // match it (via the row's IntrinsicHeight below) while the other row
    // does not, so the two rows end up visibly different heights. Reserving
    // the same title-block height on every card makes all four the same
    // height by construction, independent of row pairing or which titles
    // happen to wrap.
    final titleBlockHeight = lineHeightOf(context, titleStyle) * 2;
    return Semantics(
      button: true,
      label: '$title. $description',
      excludeSemantics: true,
      // Shadow on the outside, fill and border on the Material — see the note
      // in [AppointmentCard] on why the shadow cannot live on the Ink.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kDashboardRadius),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .34),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : softCardShadow(context),
        ),
        child: Material(
          color: isDark
              ? Color.lerp(colors.surface, colors.page, .16)
              : colors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kDashboardRadius),
            side: BorderSide(color: borderColor, width: isDark ? 1.2 : 1),
          ),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kPatientActionHeight + kFeatureCardExtraHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  kFeatureCardPadX,
                  kFeatureCardPadTop,
                  kFeatureCardPadX,
                  kFeatureCardPadBottom,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: disc,
                        height: disc,
                        decoration: BoxDecoration(
                          color: tint,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: disc * .52, color: accent),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: titleBlockHeight,
                        child: Center(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle.copyWith(color: accent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: scaledIcon(context, 18),
                        color: accent,
                      ),
                    ],
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

/// The emergency control.
///
/// Three things keep this both instantly findable and safe against a mis-tap:
///
///  1. It is the only red thing on the screen, and the only card with a
///     coloured fill and a coloured border. Nothing else can be mistaken for
///     it, and it cannot be mistaken for anything else.
///  2. It sits apart from the feature grid, below extra space, so it is not
///     inside the block of tiles a patient taps casually.
///  3. It never dials on one tap. [onTap] is expected to confirm first, on a
///     full-screen prompt, before anything irreversible happens.
class EmergencyCard extends StatelessWidget {
  const EmergencyCard({super.key, required this.onTap});

  /// Invoked on tap. The caller is responsible for confirming before anything
  /// irreversible happens; see `showEmergencyConfirmation`.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const baseDisc = kEmergencyDiscSize;
    final disc = scaledIcon(context, baseDisc).clamp(baseDisc, 80.0);
    final colors = context.saathiColors;

    return Semantics(
      button: true,
      label: '${text(T.emergency)}. ${text(T.dashboardEmergencyHint)}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(kDashboardRadius),
        child: InkWell(
          onTap: () {
            HapticFeedback.heavyImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(kDashboardRadius),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kDashboardRadius),
              color: colors.emergencyTint,
              gradient: isDark
                  ? LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color.lerp(
                          colors.emergencyTint,
                          colors.emergency,
                          .10,
                        )!,
                        Color.lerp(colors.emergencyTint, colors.page, .10)!,
                      ],
                    )
                  : null,
              border: Border.all(color: colors.emergency, width: 2),
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: colors.emergency.withValues(alpha: .16),
                        blurRadius: 20,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : null,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kPatientMinTarget + kEmergencyExtraHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.all(kEmergencyCardPad),
                // Past the stacking threshold the icon and the arrow move to
                // their own row. Left beside the text at 2x, the label column
                // is narrower than the word "EMERGENCY" itself, and Flutter
                // then breaks it mid-word — "EMER / GENC / Y". A safety
                // control that a patient has to decipher is a broken one.
                child: _textScale(context) > _stackedLayoutScale
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _EmergencyDisc(size: disc),
                              const _EmergencyChevron(),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const _EmergencyLabels(),
                        ],
                      )
                    : Row(
                        children: [
                          _EmergencyDisc(size: disc),
                          const SizedBox(width: 14),
                          const Expanded(child: _EmergencyLabels()),
                          const SizedBox(width: 8),
                          const _EmergencyChevron(),
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

class _EmergencyDisc extends StatelessWidget {
  const _EmergencyDisc({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.emergency,
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.emergency, colors.emergencyStrong],
              )
            : null,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colors.emergency.withValues(alpha: .32),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.phone_in_talk_rounded,
            size: size * .38,
            color: colors.onStrong,
          ),
          Text(
            'SOS',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: colors.onStrong,
              fontSize: size * .16,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyChevron extends StatelessWidget {
  const _EmergencyChevron();

  @override
  Widget build(BuildContext context) {
    final size = scaledIcon(context, 34).clamp(34.0, 48.0);
    final colors = context.saathiColors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.emergency.withValues(alpha: .14),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.chevron_right_rounded,
        size: scaledIcon(context, 22),
        color: colors.emergency,
      ),
    );
  }
}

class _EmergencyLabels extends StatelessWidget {
  const _EmergencyLabels();

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final colors = context.saathiColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text(T.emergency),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: colors.emergency,
            height: 1.15,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          text(T.dashboardEmergencyHint),
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            // Darker than the heading's red would suggest: this line has to
            // clear AA on the pale tint at a smaller size.
            color: colors.emergencyStrong,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

/// Today's dose, with the control that reads it aloud.
///
/// The visual anchor for the spoken-reminder feature: the same three facts the
/// reminder speaks — what to take, how much, and when — laid out so a patient
/// who cannot read them can still press one green circle and hear them.
class MedicineReminderCard extends StatelessWidget {
  const MedicineReminderCard({
    super.key,
    required this.medicine,
    required this.onListen,
  });

  /// Null when nothing is due today; rendered as an explicit empty state.
  final MockTodayMedicine? medicine;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final dose = medicine;
    final disc = scaledIcon(context, 54).clamp(54.0, 74.0);
    final colors = context.saathiColors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryTint,
        borderRadius: BorderRadius.circular(kDashboardRadius),
        border: Border.all(color: colors.primary.withValues(alpha: .4)),
      ),
      // Same stacking rule as the other cards: at a large font scale a
      // medicine name is longer than the column left beside two circles, and
      // "Metformin" broken across lines is not a name a patient can match
      // against the strip in their hand.
      child: _textScale(context) > _stackedLayoutScale
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MedicineBell(size: disc),
                    ListenButton.play(
                      label: text(T.dashboardListen),
                      semanticLabel: _listenSemantics(text, dose),
                      onPressed: onListen,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _MedicineDetails(dose: dose),
              ],
            )
          : Row(
              children: [
                _MedicineBell(size: disc),
                const SizedBox(width: 14),
                Expanded(child: _MedicineDetails(dose: dose)),
                const SizedBox(width: 8),
                ListenButton.play(
                  label: text(T.dashboardListen),
                  semanticLabel: _listenSemantics(text, dose),
                  onPressed: onListen,
                ),
              ],
            ),
    );
  }

  static String _listenSemantics(AppText text, MockTodayMedicine? dose) {
    if (dose == null) {
      return '${text(T.dashboardListen)}. '
          '${text(T.dashboardNoMedicineToday)}';
    }
    return '${text(T.dashboardListen)}. ${dose.medicineName}, ${dose.dosage}';
  }
}

class _MedicineBell extends StatelessWidget {
  const _MedicineBell({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
      child: Icon(
        Icons.notifications_active_rounded,
        size: size * .5,
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF052019)
            : colors.onStrong,
      ),
    );
  }
}

class _MedicineDetails extends StatelessWidget {
  const _MedicineDetails({required this.dose});
  final MockTodayMedicine? dose;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final dose = this.dose;
    final colors = context.saathiColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text(T.dashboardTodaysMedicine),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colors.textMuted,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        if (dose == null)
          Text(
            text(T.dashboardNoMedicineToday),
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: colors.text,
              height: 1.2,
            ),
          )
        else ...[
          // Name and dosage in one paragraph, weighted differently: the name
          // is what identifies the tablet in the strip, the dosage is what
          // stops a double dose.
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: dose.medicineName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: colors.text,
                  ),
                ),
                const TextSpan(text: '  '),
                TextSpan(
                  text: dose.dosage,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
              ],
            ),
            style: const TextStyle(height: 1.2),
          ),
          const SizedBox(height: 2),
          Text(
            '${text(dose.instruction)}  •  '
            '${formatPatientTime(dose.scheduledAtToday(), text)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }
}
