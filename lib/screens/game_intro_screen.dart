// lib/screens/game_intro_screen.dart
import 'package:flutter/material.dart';
import '../core/global_bgm.dart';
import '../widgets/game_controller_bar.dart';
import 'package:kkomi_learn/screens/intro_loop_screen.dart';
import 'game_set2_screen.dart';
import 'learn_set10_screen.dart'; // ✅ 추가: 이전 버튼 목적지

class GameIntroScreen extends StatefulWidget {
  const GameIntroScreen({super.key});

  @override
  State<GameIntroScreen> createState() => _GameIntroScreenState();
}

class _GameIntroScreenState extends State<GameIntroScreen> {
  // 1920×1080 기준 컨트롤러 배치
  static const double baseW = 1920, baseH = 1080;
  static const double controllerTopPx = 35, controllerRightPx = 40;

  bool _bgmPaused = false;
  bool _navigating = false;

  Future<void> _goHome() async {
    await GlobalBgm.instance.stop();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _goPrev() async {
    if (_navigating) return;
    _navigating = true;

    // ✅ LearnSet10로 이동 전에 인트로 BGM 정리
    await GlobalBgm.instance.stop();

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (c, a, b) => const LearnSet10Screen(),
        transitionsBuilder: (c, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _goNext() async {
    if (_navigating) return;
    _navigating = true;

    // 다음(GameSet2)에서 게임 BGM을 시작할 수 있으니 여기서 intro BGM 정리
    await GlobalBgm.instance.stop();

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (c, a, b) => const GameSet2Screen(),
        transitionsBuilder: (c, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _togglePause() async {
    if (_bgmPaused) {
      await GlobalBgm.instance.resume();
    } else {
      await GlobalBgm.instance.pause();
    }
    if (mounted) setState(() => _bgmPaused = !_bgmPaused);
  }

  @override
  Widget build(BuildContext context) {
    // 스케일 계산 (다른 화면과 동일)
    final sz = MediaQuery.of(context).size;
    final scale = (sz.width / baseW).clamp(0.0, sz.height / baseH);
    final canvasW = baseW * scale;
    final canvasH = baseH * scale;
    final leftPad = (sz.width - canvasW) / 2;
    final topPad = (sz.height - canvasH) / 2;

    return Stack(
      children: [
        // ✅ 최하단에 흰색 깔아서 비디오 로딩/전환 순간 검정 플래시 방지
        const Positioned.fill(child: ColoredBox(color: Colors.white)),

        // 1) 비디오 레이어
        Positioned.fill(
          child: IntroLoopScreen(
            introVideoAsset: 'assets/videos/game_intro/intro.mp4',
            loopVideoAsset: 'assets/videos/game_intro/intro_loop.mp4',
            bgmAsset: 'audio/bgm/intro_theme.mp3',
            bgmStartOnLoop: false, // 인트로부터 재생
            bgmIntroVolume: 0.1, // 인트로 볼륨 10%
            bgmTargetVolume: 0.3, // 루프에서 30%로 페이드인
            bgmFadeInMs: 1500,
            onNext: _goNext,
          ),
        ),

        // 2) 컨트롤러(배경 없음, 투명)
        Positioned(
          left: leftPad,
          top: topPad,
          width: canvasW,
          height: canvasH,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: controllerTopPx * scale,
                  right: controllerRightPx * scale,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topRight,
                    child: GameControllerBar(
                      isPaused: _bgmPaused,
                      onHome: _goHome,
                      onPrev: _goPrev, // ✅ LearnSet10로
                      onNext: _goNext,
                      onPauseToggle: _togglePause,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
