import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';
import '../widgets/my_darah_brand.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        const Positioned(
          top: -90,
          right: -85,
          child: _Glow(size: 240, color: Color(0xFFFFC8CF)),
        ),
        const Positioned(
          top: 210,
          left: -100,
          child: _Glow(size: 210, color: Color(0xFFFFDFD4)),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      const MyDarahMark(size: 38),
                      const SizedBox(width: 9),
                      Text(
                        'MyDarah',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                Container(
                  width: 142,
                  height: 142,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .82),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: .16),
                        blurRadius: 38,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const MyDarahMark(size: 112),
                ),
                const SizedBox(height: 28),
                Text(
                  'Give blood.\nGive hope.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontSize: 42,
                    height: 1.02,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Discover donation events, respond to urgent blood requests '
                  'and turn every verified donation into meaningful recognition.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: AppTheme.muted,
                  ),
                ),
                const SizedBox(height: 24),
                const Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Feature(
                      icon: Icons.location_on_outlined,
                      label: 'Nearby centres',
                    ),
                    _Feature(
                      icon: Icons.event_available_outlined,
                      label: 'Donation events',
                    ),
                    _Feature(
                      icon: Icons.workspace_premium_outlined,
                      label: 'Donor benefits',
                    ),
                  ],
                ),
                const Spacer(flex: 3),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text(
                      'Get Started',
                      style: TextStyle(fontSize: 17),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your blood donation companion',
                  style: TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .55),
      shape: BoxShape.circle,
    ),
  );
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .82),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: AppTheme.primary.withValues(alpha: .14)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
