// lib/screens/quiz_result_screen.dart
import 'package:flutter/material.dart';
import 'package:kkomi_learn/screens/intro_loop_screen.dart';
import 'splash_screen.dart';

class QuizResultScreen extends StatelessWidget {
  const QuizResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return IntroLoopScreen(
      introVideoAsset: 'assets/videos/result/result.mp4',
      loopVideoAsset: 'assets/videos/result/result_loop.mp4',
      bgmAsset: 'audio/bgm/intro_theme.mp3',
      hintText: '탭 또는 Enter로 처음으로',
      errorText: '결과 영상을 불러올 수 없어요.\n탭/Enter로 처음으로 돌아갑니다.',
      onNext: () {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (c, a, b) => const SplashScreen(),
            transitionsBuilder: (c, a, b, child) =>
                FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
          (_) => false,
        );
      },
    );
  }
}
