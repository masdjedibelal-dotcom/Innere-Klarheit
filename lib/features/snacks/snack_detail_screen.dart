import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../state/snacks_state.dart';
import '../../widgets/common/tag_chip.dart';

class SnackDetailScreen extends ConsumerWidget {
  const SnackDetailScreen({super.key, required this.snackId});

  final String snackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snacksAsync = ref.watch(snacksProvider);
    final savedAsync = ref.watch(savedSnackIdsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Snack')),
      body: snacksAsync.when(
        data: (snacks) {
          final snack = snacks.firstWhere(
            (s) => s.id == snackId,
            orElse: () => snacks.first,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              _HeroPlaceholder(),
              const SizedBox(height: 16),
              Text(snack.title,
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '${snack.readTimeMinutes} Min',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                  ),
                  const SizedBox(width: 12),
                  ...snack.tags
                      .map((t) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: TagChip(label: t),
                          ))
                      .toList(),
                ],
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
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('Snack konnte nicht geladen werden.'),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: savedAsync.when(
            data: (ids) {
              final isSaved = ids.contains(snackId);
              return FilledButton.icon(
                onPressed: () => _toggleSave(context, ref, isSaved),
                icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
                label: Text(isSaved ? 'Gespeichert' : 'Speichern'),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => FilledButton.icon(
              onPressed: () => _toggleSave(context, ref, false),
              icon: const Icon(Icons.bookmark_border),
              label: const Text('Speichern'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleSave(
      BuildContext context, WidgetRef ref, bool isSaved) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    final repo = ref.read(userSnacksRepoProvider);
    final result = isSaved
        ? await repo.unsaveSnack(snackId)
        : await repo.saveSnack(snackId);
    if (result.isSuccess) {
      ref.invalidate(savedSnackIdsProvider);
    }
  }
}

class _HeroPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.transparent),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.chrome_reader_mode_outlined,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        size: 40,
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

