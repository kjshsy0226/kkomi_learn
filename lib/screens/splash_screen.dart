// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:kkomi_learn/screens/intro_loop_screen.dart';
import 'package:kkomi_learn/core/bgm_tracks.dart'; // ✅ stopGame/stopStory/ensureIntro 등
import 'learn_set1_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _sanitizeBgm();
  }

  Future<void> _sanitizeBgm() async {
    // ⚠️ 스플래시에 들어오면 컨텐츠 BGM 겹침 방지: 먼저 정지
    await GlobalBgm.instance.stopGame();
    await GlobalBgm.instance.stopStory();

    // 인트로 BGM이 이미 재생 중이면 10%로 맞춰두고,
    // 아니면 IntroLoopScreen이 재생을 맡도록 여기선 굳이 start 안 함.
    if (GlobalBgm.instance.isIntro) {
      await GlobalBgm.instance.setVolume(0.1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntroLoopScreen(
      introVideoAsset: 'assets/videos/splash/splash.mp4',
      loopVideoAsset: 'assets/videos/splash/splash_loop.mp4',
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
            pageBuilder: (c, a, b) => const LearnSet1Screen(),
            transitionsBuilder: (c, a, b, child) =>
                FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      },
    );
  }
}
