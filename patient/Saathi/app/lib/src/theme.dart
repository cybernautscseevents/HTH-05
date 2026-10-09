import 'package:flutter/material.dart';

// Brand colours remain public for assets and places where a compile-time
// colour is required. Patient widgets should use context.saathiColors so they
// follow the active light/dark/high-contrast theme.
const saathiGreen = Color(0xFF2563EB);
const saathiTeal = Color(0xFF0EA5E9);
const saathiMint = Color(0xFFE0F2FE);
const saathiInk = Color(0xFF0F172A);
const saathiCream = Color(0xFFF7FBFF);
const saathiBlue = Color(0xFF275D8C);
const saathiAmber = Color(0xFFF4B740);
const saathiLine = Color(0xFFD5E7F5);
const saathiNavy = Color(0xFF16233F);
const saathiBodyGrey = Color(0xFF5A6B7C);
const saathiInkSoft = Color(0xFF475569);
const saathiGreenDeep = Color(0xFF1D4ED8);
const saathiInfoNavy = Color(0xFF1E3A5F);
const saathiInfoTint = Color(0xFFE9F0F9);
const saathiEmergency = Color(0xFFB3261E);
const saathiEmergencyDeep = Color(0xFF8C1D18);
const saathiEmergencyTint = Color(0xFFFCEEEC);

const double kPatientMinTarget = 54;
const double kPatientActionHeight = 84;
const double kDashboardRadius = 20;

/// DASHBOARD METRICS — the single source of truth for how big and how roomy
/// the home screen is.
///
/// These are deliberately theme-independent. Light and dark must lay out
/// identically down to the pixel: only colour, gradient and shadow may differ
/// between them. Sizing that forked per theme was how the two modes silently
/// drifted apart once before — dark ended up noticeably more spacious than
/// light, which meant a spacing fix applied to one mode did nothing for the
/// other. Every dashboard size below is read by both.
///
/// Vertical budget: the tightest supported phone is 360x640, where the whole
/// screen must still fit at the normal font scale with nothing to scroll to
/// (see dashboard_one_screen_test.dart). Raising any of the vertical values
/// here spends that budget, so re-run that test after changing them. Below
/// 360x640 — a 320x568-class phone — the content genuinely does not fit at a
/// legible size; that scrolls, deliberately, rather than shrinking text or
/// icons to force a fit.
const double kHeroCardMinHeight = 116;
const double kHeroCardPadX = 12;
const double kHeroCardPadY = 10;
const double kHeroBadgeSize = 56;
const double kHeroArrowSize = 40;

const double kFeatureDiscSize = 46;
const double kFeatureCardExtraHeight = 10;
const double kFeatureCardPadX = 8;
const double kFeatureCardPadTop = 6;
const double kFeatureCardPadBottom = 6;

const double kEmergencyDiscSize = 48;
const double kEmergencyExtraHeight = 10;
const double kEmergencyCardPad = 10;

const double kHeaderLogoSize = 42;
const double kHeaderWordmarkSize = 27;

/// The circular menu button's diameter, unscaled and its scaled maximum.
/// Shared between the button itself and the header's own layout budget
/// calculation, so the two can never disagree about how much room the
/// button needs.
const double kMoreButtonBaseSize = 46;
const double kMoreButtonMaxSize = 64;

const double kNavItemPadY = 8;
const double kNavIndicatorWidth = 46;
const double kNavIconSize = 28;

@immutable
class SaathiColors extends ThemeExtension<SaathiColors> {
  const SaathiColors({
    required this.page,
    required this.surface,
    required this.surfaceRaised,
    required this.primary,
    required this.primaryStrong,
    required this.primaryTint,
    required this.teal,
    required this.info,
    required this.infoTint,
    required this.text,
    required this.textMuted,
    required this.brand,
    required this.line,
    required this.navInactive,
    required this.emergency,
    required this.emergencyStrong,
    required this.emergencyTint,
    required this.amber,
    required this.onStrong,
    required this.shadow,
  });

  final Color page;
  final Color surface;
  final Color surfaceRaised;
  final Color primary;
  final Color primaryStrong;
  final Color primaryTint;
  final Color teal;
  final Color info;
  final Color infoTint;
  final Color text;
  final Color textMuted;
  final Color brand;
  final Color line;
  final Color navInactive;
  final Color emergency;
  final Color emergencyStrong;
  final Color emergencyTint;
  final Color amber;
  final Color onStrong;
  final Color shadow;

  static const light = SaathiColors(
    page: saathiCream,
    surface: Colors.white,
    surfaceRaised: Colors.white,
    primary: saathiGreen,
    primaryStrong: saathiGreenDeep,
    primaryTint: saathiMint,
    teal: saathiTeal,
    info: saathiInfoNavy,
    infoTint: saathiInfoTint,
    text: saathiInk,
    textMuted: saathiInkSoft,
    brand: saathiNavy,
    line: saathiLine,
    navInactive: saathiBodyGrey,
    emergency: saathiEmergency,
    emergencyStrong: saathiEmergencyDeep,
    emergencyTint: saathiEmergencyTint,
    amber: saathiAmber,
    onStrong: Colors.white,
    shadow: Color(0x1417211E),
  );

  static const dark = SaathiColors(
    page: Color(0xFFABD2DF),
    surface: Color(0xFFBBDDE7),
    surfaceRaised: Color(0xFFD8EDF3),
    primary: Color(0xFF287A9B),
    primaryStrong: Color(0xFF125776),
    primaryTint: Color(0xFFDCEFF5),
    teal: Color(0xFF3187A8),
    info: Color(0xFF1A5B7A),
    infoTint: Color(0xFFD3EAF2),
    text: Color(0xFF0C2432),
    textMuted: Color(0xFF294C5C),
    brand: Color(0xFF10374C),
    line: Color(0xFF729EAF),
    navInactive: Color(0xFF3C6273),
    emergency: Color(0xFFFF8A80),
    emergencyStrong: Color(0xFFFFB4AB),
    emergencyTint: Color(0xFF3D1C1B),
    amber: Color(0xFFFFD166),
    onStrong: Colors.white,
    shadow: Color(0x240C2432),
  );

  SaathiColors highContrast() => copyWith(
    line: textMuted,
    textMuted: text,
    navInactive: text,
    primary: brightness == Brightness.dark
        ? const Color(0xFF4AB9E6)
        : const Color(0xFF07573F),
    info: brightness == Brightness.dark
        ? const Color(0xFFC4DEFF)
        : const Color(0xFF102E52),
  );

  Brightness get brightness =>
      page.computeLuminance() < .2 ? Brightness.dark : Brightness.light;

  @override
  SaathiColors copyWith({
    Color? page,
    Color? surface,
    Color? surfaceRaised,
    Color? primary,
    Color? primaryStrong,
    Color? primaryTint,
    Color? teal,
    Color? info,
    Color? infoTint,
    Color? text,
    Color? textMuted,
    Color? brand,
    Color? line,
    Color? navInactive,
    Color? emergency,
    Color? emergencyStrong,
    Color? emergencyTint,
    Color? amber,
    Color? onStrong,
    Color? shadow,
  }) => SaathiColors(
    page: page ?? this.page,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    primary: primary ?? this.primary,
    primaryStrong: primaryStrong ?? this.primaryStrong,
    primaryTint: primaryTint ?? this.primaryTint,
    teal: teal ?? this.teal,
    info: info ?? this.info,
    infoTint: infoTint ?? this.infoTint,
    text: text ?? this.text,
    textMuted: textMuted ?? this.textMuted,
    brand: brand ?? this.brand,
    line: line ?? this.line,
    navInactive: navInactive ?? this.navInactive,
    emergency: emergency ?? this.emergency,
    emergencyStrong: emergencyStrong ?? this.emergencyStrong,
    emergencyTint: emergencyTint ?? this.emergencyTint,
    amber: amber ?? this.amber,
    onStrong: onStrong ?? this.onStrong,
    shadow: shadow ?? this.shadow,
  );

  @override
  SaathiColors lerp(covariant SaathiColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return SaathiColors(
      page: mix(page, other.page),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      primary: mix(primary, other.primary),
      primaryStrong: mix(primaryStrong, other.primaryStrong),
      primaryTint: mix(primaryTint, other.primaryTint),
      teal: mix(teal, other.teal),
      info: mix(info, other.info),
      infoTint: mix(infoTint, other.infoTint),
      text: mix(text, other.text),
      textMuted: mix(textMuted, other.textMuted),
      brand: mix(brand, other.brand),
      line: mix(line, other.line),
      navInactive: mix(navInactive, other.navInactive),
      emergency: mix(emergency, other.emergency),
      emergencyStrong: mix(emergencyStrong, other.emergencyStrong),
      emergencyTint: mix(emergencyTint, other.emergencyTint),
      amber: mix(amber, other.amber),
      onStrong: mix(onStrong, other.onStrong),
      shadow: mix(shadow, other.shadow),
    );
  }
}

extension SaathiThemeContext on BuildContext {
  SaathiColors get saathiColors =>
      Theme.of(this).extension<SaathiColors>() ?? SaathiColors.light;
}

List<BoxShadow> softCardShadow(BuildContext context) => [
  BoxShadow(
    color: context.saathiColors.shadow,
    blurRadius: 18,
    offset: const Offset(0, 6),
  ),
  BoxShadow(
    color: context.saathiColors.shadow.withValues(alpha: .45),
    blurRadius: 3,
    offset: const Offset(0, 1),
  ),
];

double scaledIcon(BuildContext context, double base) {
  final scale = MediaQuery.textScalerOf(context).scale(base) / base;
  return base * scale.clamp(1.0, 1.6);
}

/// The exact height of one line of [style] at the device's current text
/// scale — the font's own metrics via [TextPainter], not an approximation
/// from fontSize. Devanagari and Kannada glyphs sit taller within their line
/// box than Latin ones at the same nominal size, so a guess like
/// `fontSize * height` would under-reserve space in those languages.
///
/// Used to reserve a fixed title-block height in a row of cards so none of
/// them changes size depending on whether its own title happens to wrap —
/// see [DashboardFeatureCard] and the More screen's menu row.
///
/// [style] is merged onto the ambient [DefaultTextStyle] before measuring,
/// the same resolution a real [Text] widget does — a bare [TextPainter]
/// given [style] directly skips that merge, so a field left unset in [style]
/// (most commonly `fontFamily`) silently measures in a different font than
/// what actually gets painted. That gap is invisible whenever nothing
/// overrides the app's default font, which is normally true, but it is
/// exactly what a test harness does to load a real typeface in place of the
/// test framework's font — which is precisely when an unmerged measurement
/// would go wrong silently instead of loudly.
double lineHeightOf(BuildContext context, TextStyle style) {
  final resolved = DefaultTextStyle.of(context).style.merge(style);
  final painter = TextPainter(
    text: TextSpan(text: '', style: resolved),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  return painter.preferredLineHeight;
}

/// The exact rendered width of [text] in [style] at the device's current
/// text scale, unwrapped — the font's own metrics via [TextPainter], not a
/// guess. Used where a layout has to decide *before* building whether a
/// fixed string will fit in the space a sibling leaves it, so it can choose a
/// different arrangement instead of letting the string ellipsize — see the
/// header's wordmark-vs-two-line decision in `PatientDashboardScreen`.
///
/// [style] is merged onto the ambient [DefaultTextStyle] before measuring —
/// see the note on [lineHeightOf], which the same reasoning applies to.
double textWidthOf(BuildContext context, String text, TextStyle style) {
  final resolved = DefaultTextStyle.of(context).style.merge(style);
  final painter = TextPainter(
    text: TextSpan(text: text, style: resolved),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  return painter.width;
}

ThemeData buildSaathiTheme({
  bool highContrast = false,
  bool boldText = false,
}) => _buildSaathiTheme(
  brightness: Brightness.light,
  highContrast: highContrast,
  boldText: boldText,
);

ThemeData buildSaathiDarkTheme({
  bool highContrast = false,
  bool boldText = false,
}) => _buildSaathiTheme(
  brightness: Brightness.dark,
  highContrast: highContrast,
  boldText: boldText,
);

ThemeData _buildSaathiTheme({
  required Brightness brightness,
  required bool highContrast,
  required bool boldText,
}) {
  var palette = brightness == Brightness.dark
      ? SaathiColors.dark
      : SaathiColors.light;
  if (highContrast) palette = palette.highContrast();
  final scheme =
      ColorScheme.fromSeed(
        seedColor: saathiGreen,
        brightness: brightness,
        surface: palette.surface,
        error: palette.emergency,
      ).copyWith(
        primary: palette.primary,
        onPrimary: brightness == Brightness.dark
            ? const Color(0xFF041D2B)
            : Colors.white,
        secondary: palette.teal,
        onSurface: palette.text,
        outline: palette.line,
        surfaceContainerLowest: palette.page,
        surfaceContainerLow: palette.surface,
        surfaceContainer: palette.surfaceRaised,
      );
  final bodyWeight = boldText ? FontWeight.w700 : FontWeight.w600;
  final mediumWeight = boldText ? FontWeight.w700 : FontWeight.w500;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.page,
    extensions: [palette],
    appBarTheme: AppBarTheme(
      backgroundColor: palette.page,
      foregroundColor: palette.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: palette.text,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    ),
    textTheme: TextTheme(
      displaySmall: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        color: palette.text,
        height: 1.15,
      ),
      headlineMedium: TextStyle(
        fontSize: 27,
        fontWeight: FontWeight.w900,
        color: palette.text,
        height: 1.2,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: palette.text,
        height: 1.25,
      ),
      bodyLarge: TextStyle(
        fontSize: 18,
        fontWeight: bodyWeight,
        color: palette.text,
        height: 1.45,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        fontWeight: mediumWeight,
        color: palette.textMuted,
        height: 1.45,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: palette.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: palette.line, width: highContrast ? 2 : 1),
      ),
    ),
    dividerTheme: DividerThemeData(color: palette.line),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      labelStyle: TextStyle(color: palette.textMuted),
      hintStyle: TextStyle(color: palette.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: palette.line,
          width: highContrast ? 2 : 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.emergency),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(kPatientMinTarget),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(kPatientMinTarget),
        side: BorderSide(color: palette.line, width: highContrast ? 2 : 1),
        foregroundColor: palette.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ),
  );
}
