import 'package:flutter/material.dart';

Future<void> showEditorialBottomSheet({
  required BuildContext context,
  required Widget child,
}) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => SafeArea(
      top: false,
      child: Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        top: 12,
      ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
      child: child,
        ),
      ),
    ),
  );
}
