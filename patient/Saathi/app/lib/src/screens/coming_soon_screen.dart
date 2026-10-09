import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n/app_text.dart';
import '../theme.dart';
import '../widgets/patient_scaffold.dart';
import '../widgets/patient_widgets.dart';

/// Destination for a dashboard tile whose real screen does not exist yet.
///
/// Deliberately a real screen rather than a dead tap or a snackbar. A patient
/// who taps something and gets no response concludes the phone is broken or
/// that they pressed it wrong, and an elderly patient will often stop trying
/// the rest of the app after that. Opening a calm screen that says, in their
/// language, that this part is not ready and letting them press back is the
/// honest outcome.
///
/// Built on [PatientScaffold], so the language switch stays in the app bar
/// exactly where it is on every other screen.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.controller,
    required this.title,
    required this.icon,
    this.tone = saathiInfoNavy,
  });

  final AppController controller;

  /// The name of the feature as it appears on the dashboard tile, so the
  /// patient can see they landed where they aimed.
  final String title;

  /// The same icon as the tile, for the same reason.
  final IconData icon;

  final Color tone;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return PatientScaffold(
      title: title,
      controller: controller,
      body: PatientStateView(
        icon: icon,
        tone: tone == saathiInfoNavy ? context.saathiColors.info : tone,
        title: text(T.comingSoonTitle),
        body: text(T.comingSoonBody),
      ),
    );
  }
}
