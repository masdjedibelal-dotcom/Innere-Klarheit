import 'package:flutter/material.dart';

class EditorialListTile extends StatelessWidget {
  const EditorialListTile({
    super.key,
    required this.title,
    required this.preview,
    required this.trailing,
    this.onTap,
    this.tags,
    this.readTime,
  });

  final String title;
  final String preview;
  final Widget trailing;
  final VoidCallback? onTap;
  final List<String>? tags;
  final String? readTime;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              preview,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: scheme.onSurface.withOpacity(0.75),
                  ),
            ),
            if (tags != null || readTime != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (tags != null) ...[
                    ...tags!.take(2).map((t) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _Tag(label: t),
                        )),
                  ],
                  if (readTime != null)
                    Text(
                      readTime!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                          ),
                    ),
                  const Spacer(),
                  trailing,
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.transparent),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withOpacity(0.7),
            ),
      ),
    );
  }
}
