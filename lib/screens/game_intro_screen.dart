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
      bgmAsset: 'audio/bgm/intro_theme.mp3',

      // ▶ 메인(인트로) 동안 10% 재생
      bgmStartOnLoop: false, // 인트로부터 재생
      bgmIntroVolume: 0.1, // 인트로 볼륨 10%
      // ▶ 루프로 넘어갈 때 10% → 30% 페이드인
      bgmTargetVolume: 0.3,
      bgmFadeInMs: 1500, // 1.5초 정도 자연스럽게

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
