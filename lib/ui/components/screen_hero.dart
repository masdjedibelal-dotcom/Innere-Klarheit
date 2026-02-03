import 'package:flutter/material.dart';

class ScreenHero extends StatelessWidget {
  const ScreenHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseTitle = theme.textTheme.headlineMedium ??
        theme.textTheme.displaySmall ??
        const TextStyle(fontSize: 42);
    final baseFontSize = baseTitle.fontSize ?? 42;
    final titleStyle = baseTitle.copyWith(
      fontSize: baseFontSize < 40 ? 42 : baseFontSize,
      fontWeight: FontWeight.bold,
      height: 1.1,
    );
    final subtitleStyle = (theme.textTheme.bodyLarge ?? const TextStyle())
        .copyWith(
          fontSize: 18,
          height: 1.6,
          color: theme.colorScheme.onSurface.withOpacity(0.65),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 60, 30, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: titleStyle,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            style: subtitleStyle,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

