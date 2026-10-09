import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../theme.dart';
import 'draggable_listen_ball.dart';
import 'language_switch.dart';

/// Common chrome for every patient screen past the home screen: a title, an
/// obvious back arrow, and the language switch always in the same place
/// (top-right of the app bar) so a patient never has to relearn where it is.
class PatientScaffold extends StatelessWidget {
  const PatientScaffold({
    super.key,
    required this.title,
    required this.controller,
    required this.body,
    this.backgroundColor,
    this.bottomNavigationBar,
    this.onListen,
  });

  final String title;
  final AppController controller;
  final Widget body;
  final Color? backgroundColor;
  final Widget? bottomNavigationBar;

  /// When set, floats a [DraggableListenBall] above [body] that speaks via
  /// this callback on tap, the same AssistiveTouch-style control the
  /// dashboard uses. Leave null for a screen with no listen action of its
  /// own — most secondary screens rely on the dashboard's ball instead of
  /// carrying a second one. Mutually exclusive with [bottomNavigationBar] in
  /// practice: a screen using this has no bottom bar to share space with.
  final VoidCallback? onListen;

  @override
  Widget build(BuildContext context) {
    // Material's app bar is a fixed 56dp tall with a non-flexible actions row,
    // so at a large system font scale the language pill was taller than the bar
    // and wider than the space left beside the title — it overflowed the
    // toolbar on a narrow phone. The bar grows with the text instead, and the
    // pill is capped at a share of the width so its label ellipsises rather
    // than pushing the title off the screen.
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final width = MediaQuery.sizeOf(context).width;
    final onListen = this.onListen;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        toolbarHeight: 56 * scale.clamp(1.0, 2.0),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width * .60),
            child: LanguageSwitchButton(controller: controller),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: onListen == null
            ? body
            : LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Positioned.fill(child: body),
                    DraggableListenBall(
                      controller: controller,
                      bounds: constraints.biggest,
                      onListen: onListen,
                    ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// A section label used inside patient screens (e.g. "Doctor", "Medicines").
class PatientFieldLabel extends StatelessWidget {
  const PatientFieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: colors.textMuted,
        letterSpacing: .6,
      ),
    );
  }
}
