import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/app_copy.dart';
import '../../data/models/knowledge_snack.dart';
import '../../state/user_state.dart';
import '../bottom_sheet/bottom_card_sheet.dart';
import 'generated_media.dart';
import 'primary_button.dart';
import 'tag_chip.dart';

Future<void> showKnowledgeSnackSheet({
  required BuildContext context,
  required KnowledgeSnack snack,
}) {
  return showBottomCardSheet(
    context: context,
    child: KnowledgeSnackSheet(snack: snack),
  );
}

class KnowledgeSnackSheet extends ConsumerWidget {
  const KnowledgeSnackSheet({super.key, required this.snack});

  final KnowledgeSnack snack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctaCopy = copy('knowledge.reader.end');
    final isSaved = ref.watch(userStateProvider).savedKnowledgeSnackIds.contains(snack.id);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GeneratedMedia(
            seed: snack.id,
            height: 180,
            borderRadius: 20,
            icon: Icons.chrome_reader_mode_outlined,
          ),
          const SizedBox(height: 16),
          Text(snack.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            snack.preview,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.8),
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (snack.tags.isNotEmpty) ...snack.tags.take(3).map((t) => TagChip(label: t)),
              Text(
                '${snack.readTimeMinutes} Min',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._paragraphs(snack.content).map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(p, style: Theme.of(context).textTheme.bodyLarge),
            ),
          ),
          if (ctaCopy.title.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(ctaCopy.title, style: Theme.of(context).textTheme.titleMedium),
            if (ctaCopy.body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                ctaCopy.body,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.75),
                    ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: isSaved ? 'Gespeichert' : 'Speichern',
              onPressed: () => ref
                  .read(userStateProvider.notifier)
                  .toggleSnackSaved(snack.id),
            ),
          ),
        ],
      ),
    );
  }
}

List<String> _paragraphs(String text) {
  return text
      .split('\n\n')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
}

