// lib/screens/game_outro_screen.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/global_bgm.dart';
import 'quiz_result_screen.dart';

class GameOutroScreen extends StatefulWidget {
  const GameOutroScreen({
    super.key,
    this.loopVideoAsset = 'assets/videos/game_outro/outro_loop.mp4',
    this.bgmAsset = 'audio/bgm/intro_theme.mp3', // ✅ 기본 BGM
    this.bgmVolume = 0.3,
    this.onNext,
    this.useIntroKeyForSeamless = true, // ✅ 같은 키로 이어서 재생(겹침 방지)
  });

  /// 반복 재생할 영상(하나만 필요)
  final String loopVideoAsset;

  /// 선택: 아웃트로에서 틀 BGM(루프). null이면 재생 안 함
  final String? bgmAsset;

  /// 선택: BGM 볼륨(0.0~1.0)
  final double bgmVolume;

  /// 선택: 화면 탭 시 다음으로 이동할 콜백
  final VoidCallback? onNext;

  /// 같은 논리 키를 쓰면 앞 화면 BGM을 끊지 않고 자연스럽게 이어짐
  final bool useIntroKeyForSeamless;

  @override
  State<GameOutroScreen> createState() => _GameOutroScreenState();
}

class _GameOutroScreenState extends State<GameOutroScreen> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();

    // 1) 루프 영상 설정
    _controller = VideoPlayerController.asset(widget.loopVideoAsset)
      ..setLooping(true)
      ..initialize().then((_) async {
        if (!mounted) return;
        setState(() => _ready = true);
        await _controller.play();
      });

    // 2) 전역 BGM: 루프 재생 보장(겹침 없이 이어지도록)
    if (widget.bgmAsset != null) {
      GlobalBgm.instance.ensure(
        asset: widget.bgmAsset!,
        key: widget.useIntroKeyForSeamless ? 'intro_theme' : 'outro_theme',
        loop: true,
        volume: widget.bgmVolume,
        restart: false, // 이미 같은 키 재생 중이면 이어서
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    // BGM은 유지(다음 화면 정책에 맡김). 필요하면 여기서 stop() 호출.
    super.dispose();
  }

  void _handleTap() {
    if (widget.onNext != null) {
      widget.onNext!.call();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_ready)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}
