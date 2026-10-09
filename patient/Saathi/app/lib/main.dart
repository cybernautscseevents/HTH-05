import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/app_controller.dart';
import 'src/l10n/app_text.dart';
import 'src/screens/app_shell.dart';
import 'src/screens/next_appointment_screen.dart';
import 'src/services/reminder_service.dart';
import 'src/settings.dart';
import 'src/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SaathiBootstrap());
}

class SaathiBootstrap extends StatefulWidget {
  const SaathiBootstrap({super.key});

  @override
  State<SaathiBootstrap> createState() => _SaathiBootstrapState();
}

class _SaathiBootstrapState extends State<SaathiBootstrap> {
  late final AppController controller;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) AppText.debugAssertComplete();
    controller = AppController()..initialize();
    controller.addListener(_onControllerChange);
    ReminderService.instance.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ReminderService.instance.flushPendingNavigation();
    });
  }

  void _onControllerChange() {
    if (controller.status != AppStatus.patientLinked) return;
    ReminderService.instance.onAppointmentTap = () {
      final nav = ReminderService.instance.navigatorKey.currentState;
      if (nav == null) return;
      nav.push(
        MaterialPageRoute(
          builder: (_) => NextAppointmentScreen(controller: controller),
        ),
      );
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ReminderService.instance.flushPendingNavigation();
    });
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChange);
    ReminderService.instance.onAppointmentTap = null;
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds MaterialApp's locale whenever the patient changes language
    // from the picker available on every screen.
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: ReminderService.instance.navigatorKey,
          // Shown in the Android task switcher, so it matches the launcher.
          title: 'Saathi',
          debugShowCheckedModeBanner: false,
          theme: buildSaathiTheme(
            highContrast: controller.highContrast,
            boldText: controller.boldText,
          ),
          darkTheme: buildSaathiDarkTheme(
            highContrast: controller.highContrast,
            boldText: controller.boldText,
          ),
          themeMode: switch (controller.themeMode) {
            SaathiThemeMode.system => ThemeMode.system,
            SaathiThemeMode.light => ThemeMode.light,
            SaathiThemeMode.dark => ThemeMode.dark,
          },
          locale: controller.language.locale,
          supportedLocales: AppText.supportedLocales,
          localizationsDelegates: const [
            AppText.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Applies the patient's own text-size setting on top of the phone's
          // system font scale, for every screen at once. Sits above the
          // navigator so pushed routes inherit it too.
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                boldText: media.boldText || controller.boldText,
                textScaler: AppTextScaler(
                  media.textScaler,
                  controller.textSize.factor,
                ),
              ),
              child: child!,
            );
          },
          home: AppShell(controller: controller),
        );
      },
    );
  }
}
