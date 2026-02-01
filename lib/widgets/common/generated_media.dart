import 'package:flutter/material.dart';

class GeneratedMedia extends StatelessWidget {
  const GeneratedMedia({
    super.key,
    required this.seed,
    this.height = 120,
    this.borderRadius = 16,
    this.icon = Icons.auto_awesome,
  });

  final String seed;
  final double height;
  final double borderRadius;
  final IconData icon;

  static const List<Color> _palette = [
    Color(0xFFF2B544),
    Color(0xFFE8DFF5),
    Color(0xFFDDEEEA),
    Color(0xFFF4D9DF),
    Color(0xFFE7E1D8),
    Color(0xFFD9E7F5),
  ];

  Color _colorForSeed() {
    final idx = seed.hashCode.abs() % _palette.length;
    return _palette[idx];
  }

  @override
  Widget build(BuildContext context) {
    final base = _colorForSeed();
    final light = Color.lerp(base, Colors.white, 0.2) ?? base;
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          colors: [light, base],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 32,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      ),
    );
  }
}

