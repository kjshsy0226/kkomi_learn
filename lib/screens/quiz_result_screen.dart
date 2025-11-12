// lib/screens/quiz_result_screen.dart
import 'package:flutter/material.dart';
import 'package:kkomi_learn/screens/intro_loop_screen.dart';
import 'splash_screen.dart';

class QuizResultScreen extends StatelessWidget {
  const QuizResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ 화면 전역 흰 바탕
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ✅ 최하단 흰색 한 겹 깔기(로딩/전환 중 검정 방지)
          const ColoredBox(color: Colors.white),

          // ▶ 인트로→루프 자동 전환 + BGM 페이드
          IntroLoopScreen(
            introVideoAsset: 'assets/videos/result/result.mp4',
            loopVideoAsset:  'assets/videos/result/result_loop.mp4',
            bgmAsset:        'audio/bgm/intro_theme.mp3',

            // ▶ 메인(인트로) 동안 10% 재생
            bgmStartOnLoop:  false,   // 인트로부터 재생
            bgmIntroVolume:  0.1,     // 10%
            // ▶ 루프로 넘어갈 때 10% → 30% 페이드인
            bgmTargetVolume: 0.3,
            bgmFadeInMs:     1500,

            onNext: () {
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (c, a, b) => const SplashScreen(),
                  transitionsBuilder: (c, a, b, child) =>
                      FadeTransition(opacity: a, child: child),
                  transitionDuration: const Duration(milliseconds: 300),
                  // ✅ 전환 중에도 흰 배경 유지
                  opaque: true,
                  barrierColor: Colors.white,
                ),
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
