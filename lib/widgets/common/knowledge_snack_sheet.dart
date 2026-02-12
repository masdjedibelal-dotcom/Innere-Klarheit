import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/knowledge_snack.dart';
import '../../state/user_state.dart';
import '../bottom_sheet/bottom_card_sheet.dart';
import 'primary_button.dart';
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
            child: PrimaryButton(
              label: 'Speichern',
              onPressed: () => ref
                  .read(userStateProvider.notifier)
                  .toggleSnackSaved(snack.id),
            ),
          ),
          const SizedBox(height: 8),
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

