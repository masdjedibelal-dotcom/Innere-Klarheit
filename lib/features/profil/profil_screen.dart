import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/user_state.dart';

class ProfilScreen extends ConsumerStatefulWidget {
  const ProfilScreen({super.key});

  @override
  ConsumerState<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends ConsumerState<ProfilScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userStateProvider);
    final notifier = ref.read(userStateProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: user.isLoggedIn
          ? _ProfileDashboard(user: user)
          : _LoginPanel(
              onLoginGoogle: () {
                notifier.setLoggedIn(true);
                context.go('/home');
              },
              onLoginApple: () {
                notifier.setLoggedIn(true);
                context.go('/home');
              },
            ),
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.onLoginGoogle,
    required this.onLoginApple,
  });

  final VoidCallback onLoginGoogle;
  final VoidCallback onLoginApple;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Profil',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Melde dich an, um dein Dashboard zu sehen.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onLoginGoogle,
                icon: const Icon(Icons.g_mobiledata),
                label: const Text('Mit Google anmelden'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onLoginApple,
                icon: const Icon(Icons.apple),
                label: const Text('Mit Apple anmelden'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileDashboard extends StatelessWidget {
  const _ProfileDashboard({required this.user});
  final UserState user;

  @override
  Widget build(BuildContext context) {
    final name = user.profileName.isEmpty ? 'Du' : user.profileName;
    final initials = name.trim().isEmpty ? 'C' : name.trim()[0].toUpperCase();
    final loginDates = user.loginDates;
    final days = _recentDays(28);
    final activeCount = loginDates.length;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceVariant,
                child: Text(
                  initials,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hallo, $name',
                      style: Theme.of(context).textTheme.titleLarge),
                  Text('Dein kleines Dashboard',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Text(
            'Login‑Kalender',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'Logins: $activeCount',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.7),
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: days.length,
            itemBuilder: (_, i) {
              final day = days[i];
              final key = _dateKey(day);
              final isActive = loginDates.contains(key);
              return Container(
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE16B5C),
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

List<DateTime> _recentDays(int count) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return List.generate(
    count,
    (i) => today.subtract(Duration(days: count - 1 - i)),
  );
}

String _dateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
