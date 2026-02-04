import 'package:flutter/material.dart';

class EditorialFilterChip extends StatelessWidget {
  const EditorialFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      backgroundColor: scheme.surfaceVariant,
      selectedColor: scheme.primary.withOpacity(0.16),
      labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
            color:
                selected ? scheme.primary : scheme.onSurface.withOpacity(0.7),
          ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              selected ? scheme.primary.withOpacity(0.35) : Colors.transparent,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}


