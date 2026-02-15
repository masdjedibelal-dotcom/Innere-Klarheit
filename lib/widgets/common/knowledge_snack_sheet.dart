import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/knowledge_snack.dart';
import '../../state/user_state.dart';
import '../bottom_sheet/bottom_card_sheet.dart';
import 'tag_chip.dart';

Future<void> showKnowledgeSnackSheet({
  required BuildContext context,
  required KnowledgeSnack snack,
}) {
  return showBottomCardSheet(
    context: context,
    maxHeightFactor: 0.95,
    child: KnowledgeSnackSheet(snack: snack),
  );
}

Future<void> showKnowledgeSnackActionSheet({
  required BuildContext context,
  required KnowledgeSnack snack,
}) {
  return showBottomCardSheet(
    context: context,
    child: _SnackActionSheet(
      snack: snack,
      rootContext: context,
    ),
  );
}

class KnowledgeSnackSheet extends ConsumerWidget {
  const KnowledgeSnackSheet({super.key, required this.snack});

  final KnowledgeSnack snack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.surfaceVariant,
                  Theme.of(context).colorScheme.surface.withOpacity(0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(snack.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (snack.tags.isNotEmpty)
                ...snack.tags.take(3).map((t) => TagChip(label: t)),
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
          const SizedBox(height: 20),
          ..._paragraphs(snack.content).map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _hasMicroAction(p)
                  ? _microActionBox(context, p)
                  : Text(
                      p,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                          ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => showKnowledgeSnackActionSheet(
                context: context,
                snack: snack,
              ),
              child: const Text('In Tagesplan übernehmen'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => ref
                  .read(userStateProvider.notifier)
                  .toggleSnackSaved(snack.id),
              child: const Text('Speichern'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SnackActionSheet extends StatelessWidget {
  const _SnackActionSheet({
    required this.snack,
    required this.rootContext,
  });

  final KnowledgeSnack snack;
  final BuildContext rootContext;

  void _handleAction(BuildContext context, _SnackAction action) {
    Navigator.of(context).pop();
    final encodedTitle = Uri.encodeComponent(snack.title);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (action) {
        case _SnackAction.todo:
          rootContext.push('/system?add=todo&title=$encodedTitle');
          break;
        case _SnackAction.appointment:
          rootContext.push('/system?add=appointment&title=$encodedTitle');
          break;
        case _SnackAction.habit:
          rootContext.push('/system?add=habit&title=$encodedTitle');
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Übernehmen als …',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Wähle, wie du diesen Snack in deinen Tag überführen willst.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.7),
              ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => _handleAction(context, _SnackAction.todo),
            child: const Text('To-Do'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _handleAction(context, _SnackAction.appointment),
            child: const Text('Termin'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _handleAction(context, _SnackAction.habit),
            child: const Text('Habit'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

enum _SnackAction { todo, appointment, habit }

List<String> _paragraphs(String text) {
  return text
      .split('\n\n')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
}

Widget _microActionBox(BuildContext context, String text) {
  final baseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
        height: 1.6,
      );
  final emphasisStyle = baseStyle?.copyWith(fontWeight: FontWeight.w700);
  return Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
    ),
    child: RichText(
      text: _styledSpan(text, baseStyle, emphasisStyle),
    ),
  );
}

TextSpan _styledSpan(
  String text,
  TextStyle? baseStyle,
  TextStyle? emphasisStyle,
) {
  final spans = <TextSpan>[];
  var i = 0;
  while (i < text.length) {
    final start = text.indexOf('**', i);
    if (start == -1) {
      spans.add(TextSpan(text: text.substring(i), style: baseStyle));
      break;
    }
    if (start > i) {
      spans.add(TextSpan(text: text.substring(i, start), style: baseStyle));
    }
    final end = text.indexOf('**', start + 2);
    if (end == -1) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
      break;
    }
    final boldText = text.substring(start + 2, end);
    spans.add(TextSpan(text: boldText, style: emphasisStyle));
    i = end + 2;
  }
  return TextSpan(children: spans, style: baseStyle);
}

bool _hasMicroAction(String text) {
  return text.contains('**');
}

