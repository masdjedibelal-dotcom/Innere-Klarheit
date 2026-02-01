import 'package:flutter/material.dart';

class SelectionListRow extends StatelessWidget {
  const SelectionListRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    this.onTap,
    this.footer,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? footer;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: scheme.surfaceVariant,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withOpacity(0.75),
                        ),
                  ),
                  if (footer != null) ...[
                    const SizedBox(height: 10),
                    footer!,
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing ??
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? scheme.primary : scheme.surfaceVariant,
                  ),
                  child: Icon(
                    selected ? Icons.check : Icons.add,
                    size: 16,
                    color: selected ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

