import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.child});
  final Widget child;

  int _indexFromLocation(String location) {
    if (location.startsWith('/wissen')) return 1;
    if (location.startsWith('/innen')) return 2;
    if (location.startsWith('/identitaet')) return 3;
    if (location.startsWith('/system')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _indexFromLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/wissen');
              break;
            case 2:
              context.go('/innen');
              break;
            case 3:
              context.go('/identitaet');
              break;
            case 4:
              context.go('/system');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Wissen'),
          BottomNavigationBarItem(icon: Icon(Icons.insights), label: 'Innen'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Identität'),
          BottomNavigationBarItem(icon: Icon(Icons.view_agenda), label: 'Tag'),
        ],
      ),
    );
  }
}
