// lib/screens/game_outro_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/global_bgm.dart';
import '../widgets/game_controller_bar.dart';
import 'game_intro_screen.dart';
import 'quiz_result_screen.dart';

class GameOutroScreen extends StatefulWidget {
  const GameOutroScreen({
    super.key,
    this.introVideoAsset = 'assets/videos/game_outro/outro.mp4', // ✅ 본영상(1회)
    this.loopVideoAsset = 'assets/videos/game_outro/outro_loop.mp4', // ✅ 루프영상
    this.bgmAsset = 'audio/bgm/intro_theme.mp3', // ✅ 기본 BGM
    this.bgmIntroVolume = 0.1, // 인트로 구간 볼륨
    this.bgmTargetVolume = 0.3, // 루프 구간 목표 볼륨
    this.onNext,
    this.useIntroKeyForSeamless = true, // ✅ 같은 키로 이어서(겹침 방지)
  });

  final String introVideoAsset;
  final String loopVideoAsset;
  final String? bgmAsset;
  final double bgmIntroVolume;
  final double bgmTargetVolume;
  final VoidCallback? onNext;
  final bool useIntroKeyForSeamless;

  @override
  State<GameOutroScreen> createState() => _GameOutroScreenState();
}

class _GameOutroScreenState extends State<GameOutroScreen> {
  static const double baseW = 1920, baseH = 1080;
  static const double controllerTopPx = 35, controllerRightPx = 40;

  late final VideoPlayerController _introCtrl;
  late final VideoPlayerController _loopCtrl;

  bool _introReady = false;
  bool _loopReady = false;
  bool _showLoop = false;
  bool _navigating = false;
  bool _switched = false;
  bool _bgmPaused = false;

  @override
  void initState() {
    super.initState();

    if (widget.bgmAsset != null) {
      GlobalBgm.instance.ensure(
        asset: widget.bgmAsset!,
        key: widget.useIntroKeyForSeamless ? 'intro_theme' : 'outro_theme',
        loop: true,
        volume: widget.bgmIntroVolume,
        restart: false,
      );
    }

    _introCtrl = VideoPlayerController.asset(widget.introVideoAsset)
      ..setLooping(false)
      ..initialize().then((_) async {
        if (!mounted) return;
        setState(() => _introReady = true);
        await _introCtrl.play();
      });

    _introCtrl.addListener(_checkIntroEndedAndSwitch);

    _loopCtrl = VideoPlayerController.asset(widget.loopVideoAsset)
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _loopReady = true);
      });
  }

  void _checkIntroEndedAndSwitch() {
    final v = _introCtrl.value;
    if (!v.isInitialized || _switched) return;
    if (!v.isPlaying &&
        v.position >= (v.duration - const Duration(milliseconds: 50))) {
      _switchToLoop();
    }
  }

  Future<void> _switchToLoop() async {
    if (_switched) return;
    _switched = true;

    if (_introCtrl.value.isInitialized) {
      await _introCtrl.pause();
      await _introCtrl.seekTo(Duration.zero);
    }

    if (_loopReady) {
      await _loopCtrl.play();
      if (!mounted) return;
      setState(() => _showLoop = true);
    }

    if (widget.bgmAsset != null) {
      GlobalBgm.instance.ensure(
        asset: widget.bgmAsset!,
        key: widget.useIntroKeyForSeamless ? 'intro_theme' : 'outro_theme',
        loop: true,
        volume: widget.bgmTargetVolume,
        restart: false,
      );
    }
  }

  @override
  void dispose() {
    _introCtrl.removeListener(_checkIntroEndedAndSwitch);
    _introCtrl.dispose();
    _loopCtrl.dispose();
    super.dispose();
  }

  Future<void> _goNext() async {
    if (_navigating) return;
    _navigating = true;

    if (widget.bgmAsset != null) {
      await GlobalBgm.instance.stop();
    }

    if (widget.onNext != null) {
      widget.onNext!.call();
      return;
    }
    if (!mounted) return;

    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (c, a, b) => const QuizResultScreen(),
        transitionsBuilder: (c, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _handleTap() => _goNext();

  Future<void> _goPrev() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (c, a, b) => const GameIntroScreen(),
        transitionsBuilder: (c, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _goHome() async {
    await GlobalBgm.instance.stop();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
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
    final showLoop = _showLoop && _loopReady;
    final showIntro = !showLoop && _introReady;

    final sz = MediaQuery.of(context).size;
    final scale = (sz.width / baseW).clamp(0.0, sz.height / baseH);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ✅ 최하단 흰색 바닥: 비디오 준비/전환 중 검정 플래시 방지
          const Positioned.fill(child: ColoredBox(color: Colors.white)),

          if (showIntro)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _introCtrl.value.size.width,
                height: _introCtrl.value.size.height,
                child: VideoPlayer(_introCtrl),
              ),
            ),
          if (showLoop)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _loopCtrl.value.size.width,
                height: _loopCtrl.value.size.height,
                child: VideoPlayer(_loopCtrl),
              ),
            ),

          Positioned(
            top: controllerTopPx * scale,
            right: controllerRightPx * scale,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topRight,
              child: GameControllerBar(
                isPaused: _bgmPaused,
                onHome: _goHome,
                onPrev: _goPrev,
                onNext: _goNext,
                onPauseToggle: _togglePause,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
