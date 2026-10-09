import 'package:flutter/material.dart';
import '../theme.dart';

/// A simple reusable header widget used on multiple screens.
///
/// Displays a [title] with the app's headline style and a [subtitle]
/// using the body style. The layout matches the header used in
/// `RegistrationSuccessScreen`.
class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: saathiNavy,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );

    if (trailing == null) {
      return textColumn;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: textColumn),
        const SizedBox(width: 16),
        trailing!,
      ],
    );
  }
}
