import 'dart:math' as math;

import 'package:flutter/material.dart';

class GeneratedMedia extends StatelessWidget {
  const GeneratedMedia({
    super.key,
    required this.seed,
    this.height = 120,
    this.borderRadius = 16,
    this.icon,
    this.title,
    this.tags = const [],
    this.showIcon = true,
  });

  final String seed;
  final double height;
  final double borderRadius;
  final IconData? icon;
  final String? title;
  final List<String> tags;
  final bool showIcon;

  static const List<Color> _palette = [
    Color(0xFFF2B544),
    Color(0xFFE8DFF5),
    Color(0xFFDDEEEA),
    Color(0xFFF4D9DF),
    Color(0xFFE7E1D8),
    Color(0xFFD9E7F5),
  ];
  static const List<Color> _accentPalette = [
    Color(0xFF5B8DEF),
    Color(0xFF65C6B6),
    Color(0xFFF18C8E),
    Color(0xFF7B6FE6),
    Color(0xFFF2B544),
  ];

  Color _colorForSeed() {
    final idx = seed.hashCode.abs() % _palette.length;
    return _palette[idx];
  }

  Color _accentForSeed() {
    final idx = (seed.hashCode.abs() + 3) % _accentPalette.length;
    return _accentPalette[idx];
  }

  double _seeded(int salt) {
    final value = (seed.hashCode ^ (salt * 9973)) & 0x7fffffff;
    return value / 0x7fffffff;
  }

  IconData? _iconForTags() {
    final hay = [
      ...tags,
      if (title != null) title!,
    ].join(' ').toLowerCase();
    if (hay.contains('fokus') || hay.contains('konzentr')) {
      return Icons.center_focus_strong;
    }
    if (hay.contains('ruhe') || hay.contains('stress') || hay.contains('erholung')) {
      return Icons.spa_outlined;
    }
    if (hay.contains('zeit') || hay.contains('plan') || hay.contains('struktur')) {
      return Icons.schedule;
    }
    if (hay.contains('routine') || hay.contains('gewohn')) {
      return Icons.repeat;
    }
    if (hay.contains('motivation') || hay.contains('energie') || hay.contains('antrieb')) {
      return Icons.bolt;
    }
    if (hay.contains('klarheit') || hay.contains('denken') || hay.contains('reflex')) {
      return Icons.psychology;
    }
    if (hay.contains('gesund') || hay.contains('beweg') || hay.contains('sport')) {
      return Icons.favorite_border;
    }
    if (hay.contains('beziehung') || hay.contains('kommun') || hay.contains('team')) {
      return Icons.forum;
    }
    if (hay.contains('finanz') || hay.contains('geld')) {
      return Icons.account_balance_wallet;
    }
    if (hay.contains('lernen') || hay.contains('wissen') || hay.contains('lesen')) {
      return Icons.menu_book;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final base = _colorForSeed();
    final accent = _accentForSeed();
    final light = Color.lerp(base, Colors.white, 0.25) ?? base;
    final resolvedIcon = icon ?? _iconForTags() ?? Icons.auto_awesome;
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : height * 1.6;
            final circle1 = height * (0.6 + _seeded(3) * 0.25);
            final circle2 = height * (0.35 + _seeded(7) * 0.2);
            return Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [light, base],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Positioned(
                  left: -circle1 * 0.25 + width * _seeded(5) * 0.15,
                  top: -circle1 * 0.35 + height * _seeded(6) * 0.2,
                  child: _softCircle(
                    size: circle1,
                    color: accent.withOpacity(0.28),
                  ),
                ),
                Positioned(
                  right: -circle2 * 0.35 + width * _seeded(9) * 0.08,
                  bottom: -circle2 * 0.3 + height * _seeded(10) * 0.12,
                  child: _softCircle(
                    size: circle2,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                Positioned(
                  left: -width * 0.2,
                  top: height * 0.35,
                  child: Transform.rotate(
                    angle: -0.2,
                    child: Container(
                      width: width * 1.4,
                      height: math.max(10, height * 0.18),
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
                if (showIcon)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        resolvedIcon,
                        size: 30,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _softCircle({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

