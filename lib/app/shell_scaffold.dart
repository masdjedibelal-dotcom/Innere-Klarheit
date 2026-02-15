import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({
    super.key,
    required this.child,
  });
  final Widget child;

  int _indexFromLocation(String location) {
    if (location.startsWith('/system')) return 1;
    if (location.startsWith('/wissen')) return 2;
    if (location.startsWith('/innen')) return 3;
    if (location.startsWith('/identitaet')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _indexFromLocation(location);
    final route = ModalRoute.of(context);
    final showBottomBar = route?.isCurrent ?? true;

    return Scaffold(
      body: child,
      floatingActionButton: showBottomBar
          ? FloatingActionButton(
              onPressed: () => _openQuickAdd(context),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: showBottomBar
          ? BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: (index) {
                final rootNavigator = Navigator.of(context, rootNavigator: true);
                if (rootNavigator.canPop()) {
                  rootNavigator.pop();
                }
                switch (index) {
                  case 0:
                    context.go('/home');
                    break;
                  case 1:
                    context.go('/system');
                    break;
                  case 2:
                    context.go('/wissen');
                    break;
                  case 3:
                    context.go('/innen');
                    break;
                  case 4:
                    context.go('/identitaet');
                    break;
                }
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.view_agenda), label: 'Tag'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.menu_book), label: 'Wissen'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.insights), label: 'Innen'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.person), label: 'Identität'),
              ],
            )
          : null,
    );
  }
}

void _openQuickAdd(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _QuickAddSheet(rootContext: context),
  );
}

class _QuickAddSheet extends StatelessWidget {
  const _QuickAddSheet({required this.rootContext});

  final BuildContext rootContext;

  void _go(BuildContext context, String route) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      rootContext.push(route);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Schnell hinzufügen', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Wähle, was du jetzt anlegen möchtest.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _go(context, '/system?add=todo'),
                child: const Text('To-Do'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _go(context, '/system?add=appointment'),
                child: const Text('Termin'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _go(context, '/system?add=habit'),
                child: const Text('Habit'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _go(context, '/system?add=block'),
                child: const Text('Block'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
