import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../content/app_copy.dart';
import '../../widgets/common/secondary_button.dart';
import '../../widgets/common/primary_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hero = copy('onboarding.hero');
    final system = copy('onboarding.system');
    final start = copy('onboarding.start');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clarity'),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _index = i),
              children: [
                _Page(copy: hero, index: 0),
                _Page(copy: system, index: 1),
                _Page(copy: start, index: 2),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Row(
              children: [
                SecondaryButton(
                  label: 'Überspringen',
                  onPressed: () => context.go('/home'),
                ),
                const Spacer(),
                PrimaryButton(
                  label: _index == 2 ? 'Los geht’s' : 'Weiter',
                  onPressed: () {
                    if (_index == 2) {
                      context.go('/home');
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.copy, required this.index});
  final AppCopyItem copy;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  _accentForIndex(index).withOpacity(0.28),
                  _accentForIndex(index).withOpacity(0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              _iconForIndex(index),
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(copy.title, style: Theme.of(context).textTheme.headlineLarge),
          if (copy.subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              copy.subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.85),
                  ),
            ),
          ],
          if (copy.body.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              copy.body,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.75),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

IconData _iconForIndex(int index) {
  switch (index) {
    case 0:
      return Icons.auto_awesome_outlined;
    case 1:
      return Icons.grid_view_rounded;
    case 2:
      return Icons.rocket_launch_outlined;
    default:
      return Icons.auto_awesome_outlined;
  }
}

Color _accentForIndex(int index) {
  const palette = [
    Color(0xFFF2B544),
    Color(0xFFE8DFF5),
    Color(0xFFDDEEEA),
  ];
  return palette[index % palette.length];
}
