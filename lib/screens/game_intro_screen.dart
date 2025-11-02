// lib/screens/game_intro_screen.dart
import 'package:flutter/material.dart';
import 'package:kkomi_learn/screens/intro_loop_screen.dart';
import 'game_set2_screen.dart';

class GameIntroScreen extends StatelessWidget {
  const GameIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return IntroLoopScreen(
      introVideoAsset: 'assets/videos/game_intro/intro.mp4',
      loopVideoAsset: 'assets/videos/game_intro/intro_loop.mp4',
      bgmAsset: 'audio/bgm/intro_theme.mp3', // 공통 BGM
      onNext: () {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (c, a, b) => const GameSet2Screen(),
            transitionsBuilder: (c, a, b, child) =>
                FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      },
    );
  }
}
