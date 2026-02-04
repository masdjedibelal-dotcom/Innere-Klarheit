import 'package:flutter/material.dart';

Future<T?> showBottomCardSheet<T>({
  required BuildContext context,
  required Widget child,
  double maxHeightFactor = 0.5,
}) {
  final controller = AnimationController(
    vsync: Navigator.of(context),
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 200),
  );

  final clamped = maxHeightFactor.clamp(0.3, 1.0);
  final maxHeight = MediaQuery.of(context).size.height * clamped;

  return showModalBottomSheet<T>(
    context: context,
    isDismissible: true,
    enableDrag: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    transitionAnimationController: controller,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => SizedBox(
      height: maxHeight,
      child: BottomCardSheet(child: child),
    ),
  );
}

class BottomCardSheet extends StatelessWidget {
  const BottomCardSheet({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Colors.transparent),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

