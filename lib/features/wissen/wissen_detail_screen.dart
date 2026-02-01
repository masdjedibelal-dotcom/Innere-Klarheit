import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/app_copy.dart';
import '../../state/user_state.dart';
import '../../widgets/common/secondary_button.dart';
import '../../widgets/common/primary_button.dart';

class WissenDetailScreen extends ConsumerWidget {
  const WissenDetailScreen({super.key, required this.snackId});
  final String snackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final knowledgeAsync = ref.watch(knowledgeProvider);
    final ctaCopy = copy('knowledge.reader.end');

    return Scaffold(
      appBar: AppBar(title: const Text('Lesen')),
      body: knowledgeAsync.when(
        data: (items) {
          final snack = items.firstWhere((e) => e.id == snackId);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.transparent),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.chrome_reader_mode_outlined,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 20),
              Text(snack.title,
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 10),
              Text(
                snack.preview,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.85),
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                '${snack.readTimeMinutes} Min',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
              ),
              const SizedBox(height: 20),
              ..._paragraphs(snack.content).map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: SelectableText(
                    p,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              if (ctaCopy.title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ctaCopy.title,
                          style: Theme.of(context).textTheme.titleLarge),
                      if (ctaCopy.body.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          ctaCopy.body,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.75),
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('Inhalt konnte nicht geladen werden.'),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: const Border(top: BorderSide(color: Colors.transparent)),
          ),
          child: Row(
            children: [
              SecondaryButton(
                label: ctaCopy.ctaPrimary.isNotEmpty ? ctaCopy.ctaPrimary : 'Speichern',
                onPressed: () => ref
                    .read(userStateProvider.notifier)
                    .toggleSnackSaved(snackId),
              ),
              const SizedBox(width: 12),
              if (ctaCopy.ctaSecondary.isNotEmpty)
                SecondaryButton(
                  label: ctaCopy.ctaSecondary,
                  onPressed: () {},
                )
              else
                SecondaryButton(
                  label: 'Ins System übernehmen',
                  onPressed: () {},
                ),
              const Spacer(),
              PrimaryButton(
                label: 'Weiter',
                onPressed: () {},
              ),
            ],
          ),
        ),
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
