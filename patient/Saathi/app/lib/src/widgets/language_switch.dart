import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n/app_text.dart';
import '../theme.dart';

/// Language switch, reachable from every patient screen.
///
/// Deliberately a single always-visible icon button rather than something
/// tucked into a settings menu — a low-literacy patient who cannot read the
/// current language cannot be expected to find a menu labelled in a language
/// they don't read, either. The translate glyph — an "A" beside a non-Latin
/// character — reads as "this changes the language" at a glance in a way a
/// globe does not (a globe reads as "the internet" or "location" to several
/// testers); paired with the current language's own name in its own script
/// (e.g. "हिन्दी"), it stays legible regardless of which language is active.
class LanguageSwitchButton extends StatelessWidget {
  const LanguageSwitchButton({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    return Semantics(
      button: true,
      label: AppText.of(context)(T.language),
      child: Material(
        color: colors.surface.withValues(alpha: .94),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7),
          side: BorderSide(color: colors.primary.withValues(alpha: .38)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<AppLanguage>(
              value: controller.language,
              isDense: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: colors.primary,
                size: 20,
              ),
              onChanged: (language) {
                if (language != null) controller.setLanguage(language);
              },
              selectedItemBuilder: (context) => [
                for (final language in AppLanguage.values)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.translate_rounded,
                        color: colors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Text(
                          language.nativeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
              items: [
                for (final language in AppLanguage.values)
                  DropdownMenuItem<AppLanguage>(
                    value: language,
                    child: Text(language.nativeLabel),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
