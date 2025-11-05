// lib/screens/game_outro_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/global_bgm.dart';
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

  /// 1회 재생할 본영상
  final String introVideoAsset;

  /// 반복 재생할 루프영상
  final String loopVideoAsset;

  /// 선택: 아웃트로에서 틀 BGM(루프). null이면 재생 안 함
  final String? bgmAsset;

  /// 인트로(본영상) 구간 BGM 볼륨
  final double bgmIntroVolume;

  /// 루프 구간에서의 목표 BGM 볼륨
  final double bgmTargetVolume;

  /// 화면 탭 시 다음으로 이동할 콜백(없으면 결과화면으로)
  final VoidCallback? onNext;

  /// 같은 논리 키를 쓰면 앞 화면 BGM을 끊지 않고 자연스럽게 이어짐
  final bool useIntroKeyForSeamless;

  @override
  State<GameOutroScreen> createState() => _GameOutroScreenState();
}

class _GameOutroScreenState extends State<GameOutroScreen> {
  late final VideoPlayerController _introCtrl;
  late final VideoPlayerController _loopCtrl;

  bool _introReady = false;
  bool _loopReady = false;
  bool _showLoop = false;
  bool _navigating = false;
  bool _switched = false; // 본영상 → 루프 전환 1회 보장

  @override
  void initState() {
    super.initState();

    // ── BGM: 같은 키로 보장(겹침 없이 이어지도록) ─────────────────────
    if (widget.bgmAsset != null) {
      GlobalBgm.instance.ensure(
        asset: widget.bgmAsset!,
        key: widget.useIntroKeyForSeamless ? 'intro_theme' : 'outro_theme',
        loop: true,
        volume: widget.bgmIntroVolume, // 인트로 구간은 낮게
        restart: false, // 이미 같은 키 재생 중이면 이어서
      );
    }

    // ── 본영상 컨트롤러 ────────────────────────────────────────────────
    _introCtrl = VideoPlayerController.asset(widget.introVideoAsset)
      ..setLooping(false)
      ..initialize().then((_) async {
        if (!mounted) return;
        setState(() => _introReady = true);
        await _introCtrl.play();
      });

    // 본영상 종료 감지 → 루프로 전환
    _introCtrl.addListener(_checkIntroEndedAndSwitch);

    // ── 루프영상 컨트롤러(미리 준비) ───────────────────────────────────
    _loopCtrl = VideoPlayerController.asset(widget.loopVideoAsset)
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _loopReady = true);
        // 재생은 전환 시점에 시작
      });
  }

  void _checkIntroEndedAndSwitch() {
    final v = _introCtrl.value;
    if (!v.isInitialized || _switched) return;

    // 종료 판정 (duration 대비 position이 같거나 넘어가면)
    if (!v.isPlaying &&
        v.position >= (v.duration - const Duration(milliseconds: 50))) {
      _switchToLoop();
    }
  }

  Future<void> _switchToLoop() async {
    if (_switched) return;
    _switched = true;

    // 본영상 정지
    if (_introCtrl.value.isInitialized) {
      await _introCtrl.pause();
      await _introCtrl.seekTo(Duration.zero);
    }

    // 루프영상 시작
    if (_loopReady) {
      await _loopCtrl.play();
      if (!mounted) return;
      setState(() => _showLoop = true);
    }

    // 루프 진입 시 BGM 볼륨 상향(동일 키로 이어서)
    if (widget.bgmAsset != null) {
      GlobalBgm.instance.ensure(
        asset: widget.bgmAsset!,
        key: widget.useIntroKeyForSeamless ? 'intro_theme' : 'outro_theme',
        loop: true,
        volume: widget.bgmTargetVolume, // 루프 구간 목표 볼륨
        restart: false,
      );
    }
  }

  @override
  void dispose() {
    _introCtrl.removeListener(_checkIntroEndedAndSwitch);
    _introCtrl.dispose();
    _loopCtrl.dispose();
    // BGM은 유지(다음 화면 정책에 맡김). 실제 전환 시점(_handleTap)에서는 stop() 호출.
    super.dispose();
  }

  // ✅ 결과 화면으로 넘어가기 직전에 BGM을 완전히 정지해 겹침 방지
  Future<void> _handleTap() async {
    if (_navigating) return; // 중복 탭 방지
    _navigating = true;

    // 탭으로도 본영상 → 루프 전환 직후라면 굳이 기다릴 필요 없음
    // 바로 이동할 때 BGM 겹침 방지를 위해 stop()
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

  @override
  Widget build(BuildContext context) {
    final showLoop = _showLoop && _loopReady;
    final showIntro = !showLoop && _introReady;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
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
        ],
      ),
    );
  }
}
