import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_text.dart';
import '../theme.dart';

/// The four destinations in the patient app's bottom bar.
///
/// An enum rather than bare indices so a caller cannot silently select the
/// wrong tab by passing the wrong number.
enum SaathiTab {
  home(icon: Icons.home_rounded, label: T.navHome),
  appointments(icon: Icons.calendar_month_rounded, label: T.navAppointments),
  medicines(icon: Icons.medication_rounded, label: T.navMedicines),
  more(icon: Icons.more_horiz_rounded, label: T.navMore);

  const SaathiTab({required this.icon, required this.label});

  final IconData icon;
  final T label;
}

/// Bottom navigation for the patient app.
///
/// Hand-built rather than Material's [BottomNavigationBar] for one reason:
/// that widget lays its items out at a fixed height and clips or overflows
/// them once the system font scale goes past roughly 1.3x. This app's whole
/// audience is people likely to have turned that setting up, so the bar has to
/// grow with the text instead of fighting it.
///
/// The selected tab is marked three ways at once — a bar above the icon, a
/// green icon, and a green bolded label — so it is still obvious to a patient
/// who cannot distinguish the green from the grey.
class SaathiBottomNavigation extends StatelessWidget {
  const SaathiBottomNavigation({
    super.key,
    required this.current,
    required this.onSelected,
    this.immersive = false,
  });

  final SaathiTab current;
  final ValueChanged<SaathiTab> onSelected;

  /// Uses the roomier dark-glass treatment from the patient home design.
  final bool immersive;

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final useImmersive = immersive && isDark;
    return Material(
      color: useImmersive
          ? Color.lerp(colors.surface, colors.page, .36)
          : colors.surface,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: useImmersive
                  ? Color.lerp(colors.line, colors.textMuted, .45)!
                  : colors.line,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              for (final tab in SaathiTab.values)
                Expanded(
                  child: _NavItem(
                    tab: tab,
                    selected: tab == current,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelected(tab);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final SaathiTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final label = text(tab.label);
    final colors = context.saathiColors;
    final colour = selected ? colors.primary : colors.navInactive;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kPatientMinTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: kNavItemPadY,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Indicator bar. Always laid out, only painted when selected,
                // so selecting a tab never shifts the row's height.
                Container(
                  width: kNavIndicatorWidth,
                  height: 4,
                  decoration: BoxDecoration(
                    color: selected ? colors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                Icon(
                  tab.icon,
                  size: scaledIcon(context, kNavIconSize),
                  color: colour,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                    color: colour,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
