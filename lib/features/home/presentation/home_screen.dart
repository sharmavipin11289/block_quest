import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../game/presentation/game_screen.dart';
import '../../game/presentation/game_viewmodel.dart';
import '../../settings/presentation/settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final best = ref.watch(gameProvider.select((g) => g.bestScore));

    void openGame(GameMode mode) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GameScreen(mode: mode)),
      );
    }

    void openSettings() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.gradientTop,
              AppColors.gradientMiddle,
              AppColors.gradientBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wideLayout =
                  constraints.maxWidth > constraints.maxHeight &&
                  constraints.maxWidth >= 700;
              final availableWidth = wideLayout
                  ? (constraints.maxWidth - 64) / 2
                  : constraints.maxWidth - 40;
              final contentWidth = min(420.0, availableWidth);
              final logoHeight = min(
                270.0,
                min(contentWidth * .92, constraints.maxHeight * .78),
              );
              final logo = Image.asset(
                'assets/images/block_quest_wordmark.png',
                width: contentWidth,
                height: logoHeight,
                fit: BoxFit.contain,
                semanticLabel: 'Block Quest - Puzzle Adventure',
              );
              final menu = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BestScoreCard(score: best),
                  const SizedBox(height: 24),
                  _HomeActionButton(
                    label: 'Adventure',
                    icon: Icons.schedule_rounded,
                    colors: AppColors.adventure,
                    onPressed: () => openGame(GameMode.adventure),
                  ),
                  const SizedBox(height: 14),
                  _HomeActionButton(
                    label: 'Classic',
                    icon: Icons.all_inclusive_rounded,
                    colors: AppColors.classic,
                    onPressed: () => openGame(GameMode.classic),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: openSettings,
                    icon: const Icon(Icons.settings_rounded),
                    label: const Text('Settings'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: .9),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              );

              if (wideLayout) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: contentWidth,
                            height: constraints.maxHeight - 24,
                            child: Center(child: logo),
                          ),
                          const SizedBox(width: 24),
                          SizedBox(
                            width: contentWidth,
                            child: SingleChildScrollView(
                              child: Center(child: menu),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: max(0, constraints.maxHeight - 24),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentWidth),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [logo, const SizedBox(height: 8), menu],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BestScoreCard extends StatelessWidget {
  const _BestScoreCard({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F1ED),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .75), width: 2),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF08276E).withValues(alpha: .3),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF477CF2), Color(0xFF1746B3)],
            ),
          ),
          child: const Icon(
            Icons.emoji_events_rounded,
            color: AppColors.accent,
            size: 36,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BEST SCORE',
                style: TextStyle(
                  color: Color(0xFF35599D),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              Text(
                '$score',
                style: const TextStyle(
                  color: Color(0xFF1746A2),
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFFBBC2D2),
          size: 24,
        ),
      ],
    ),
  );
}

class _HomeActionButton extends StatelessWidget {
  const _HomeActionButton({
    required this.label,
    required this.icon,
    required this.colors,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: 72,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ),
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: Colors.white.withValues(alpha: .3), width: 2),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF08276E).withValues(alpha: .38),
          blurRadius: 10,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 32),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: .3,
          shadows: [
            Shadow(
              color: Color(0x66000000),
              offset: Offset(0, 2),
              blurRadius: 3,
            ),
          ],
        ),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
  );
}
