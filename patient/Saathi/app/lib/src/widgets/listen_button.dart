import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_text.dart';
import '../services/reminder_service.dart';
import '../theme.dart';

/// A circular "read this aloud" control with its label underneath.
///
/// The label is not decoration. A speaker glyph on its own is one of the least
/// reliably understood icons for an older, low-digital-literacy user — several
/// patients read it as "volume" or "mute". The word underneath, in their own
/// language, is what makes it legible; the icon is what makes it findable
/// again on the second visit.
///
/// Two variants, matching the two jobs on the dashboard:
///  * [ListenButton.speaker] — the header control that reads the whole screen.
///    Tinted, so it stays clearly secondary to the appointment card below it.
///  * [ListenButton.play] — the medicine card's control. Solid green, because
///    it is the primary action of the spoken-reminder feature, which is the
///    one thing on this screen a patient with very low literacy can use
///    unaided.
///
/// While the shared TTS engine is speaking — whichever button started it —
/// this button turns into a Stop control instead, so a patient who pressed
/// Listen by mistake, or has heard enough, always has a way to silence it
/// without hunting for a different screen.
class ListenButton extends StatelessWidget {
  const ListenButton.speaker({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
  }) : _filled = false;

  const ListenButton.play({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
  }) : _filled = true;

  /// Visible word under the circle — already translated by the caller.
  final String label;

  /// What a screen reader announces. Spelled out more fully than [label],
  /// which has to stay short enough to sit under a circle.
  final String semanticLabel;

  final VoidCallback onPressed;
  final bool _filled;

  @override
  Widget build(BuildContext context) {
    // Grows with the system font setting, so the control does not shrink
    // relative to the text beside it at large accessibility scales.
    final diameter = scaledIcon(context, 50).clamp(50.0, 74.0);
    final text = AppText.of(context);
    final colors = context.saathiColors;

    return ValueListenableBuilder<bool>(
      valueListenable: ReminderService.instance.isSpeaking,
      builder: (context, speaking, _) {
        final label = speaking ? text(T.dashboardStop) : this.label;
        final semanticLabel = speaking
            ? text(T.dashboardStopSpeaking)
            : this.semanticLabel;
        final onPressed = speaking
            ? ReminderService.instance.stopSpeaking
            : this.onPressed;

        return Semantics(
          button: true,
          label: semanticLabel,
          excludeSemantics: true,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onPressed();
            },
            borderRadius: BorderRadius.circular(diameter),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: diameter,
                    height: diameter,
                    decoration: BoxDecoration(
                      // Solid red while speaking regardless of variant — a
                      // stop control reads as a warning colour everywhere
                      // else in this app, so it stays consistent here too.
                      color: speaking
                          ? colors.emergency
                          : (_filled ? colors.primary : colors.primaryTint),
                      shape: BoxShape.circle,
                      boxShadow: (_filled || speaking)
                          ? [
                              BoxShadow(
                                color:
                                    (speaking
                                            ? colors.emergency
                                            : colors.primary)
                                        .withValues(alpha: .30),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      speaking
                          ? Icons.stop_rounded
                          : (_filled
                                ? Icons.play_arrow_rounded
                                : Icons.volume_up_rounded),
                      size: diameter * .52,
                      color: speaking || _filled
                          ? colors.onStrong
                          : colors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Bounded so a long translation ("ಈ ಪರದೆಯನ್ನು ಕೇಳಿ") cannot
                  // stretch the header row and push the logo out of the
                  // screen.
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: diameter + 26),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: speaking ? colors.emergency : colors.primary,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
