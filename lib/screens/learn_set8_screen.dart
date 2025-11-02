// (BGM 건드리지 않음: ensure/stop X, ▶❚❚ = 영상+BGM 동시 제어, 아웃라인 없음)
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../core/bgm_tracks.dart'; // GlobalBgm
import '../core/global_sfx.dart';
import '../widgets/game_controller_bar.dart';
import 'learn_set7_screen.dart';
import 'learn_set9_screen.dart';

class LearnSet8Screen extends StatefulWidget {
  const LearnSet8Screen({
    super.key,
    this.introPath = 'assets/videos/scene/set8_scene.mp4',
    this.loopPath = 'assets/videos/scene/set8_scene_loop.mp4',
  });

  final String introPath;
  final String loopPath;

  @override
  State<LearnSet8Screen> createState() => _LearnSet8ScreenState();
}

class _LearnSet8ScreenState extends State<LearnSet8Screen> {
  static const double baseW = 1920, baseH = 1080;
  static const double controllerTopPx = 35, controllerRightPx = 40;
  static const double _controllerBaseW = 460, _controllerBaseH = 135;

  late final VideoPlayerController _introC;
  late final VideoPlayerController _loopC;
  bool _ready = false, _showIntro = true, _paused = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _introC =
        VideoPlayerController.asset(
            widget.introPath,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          )
          ..setLooping(false)
          ..addListener(_onIntroTick);

    _loopC = VideoPlayerController.asset(
      widget.loopPath,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..setLooping(true);

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Future.wait([_introC.initialize(), _loopC.initialize()]);
      if (!mounted) return;

      await _introC.play();
      await _introC.pause();
      await _loopC.play();
      await _loopC.pause();

      setState(() => _ready = true);

      await _introC.seekTo(Duration.zero);
      await _introC.play();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _onIntroTick() {
    final v = _introC.value;
    if (!v.isInitialized) return;
    if (v.hasError && _error == null) {
      setState(() => _error = v.errorDescription ?? 'Video error');
      return;
    }
    if (!v.isPlaying && v.position >= v.duration) {
      _startLoop();
    }
  }

  Future<void> _startLoop() async {
    try {
      await _loopC.seekTo(Duration.zero);
      await _loopC.play();
      try {
        await _introC.pause();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _showIntro = false;
        _paused = false;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _introC.removeListener(_onIntroTick);
    _introC.dispose();
    _loopC.dispose();
    super.dispose();
  }

  Future<void> _goPrev() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (c, a, b) => const LearnSet7Screen(),
        transitionsBuilder: (c, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _goNext() async {
    GlobalSfx.instance.play('tap');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (c, a, b) => const LearnSet9Screen(),
        transitionsBuilder: (c, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _goHomeToSplash() async {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  // ▶❚❚: 영상 + BGM 동시 제어
  Future<void> _togglePause() async {
    final active = _showIntro ? _introC : _loopC;
    final bgm = GlobalBgm.instance;

    if (!active.value.isInitialized || _error != null) {
      if (bgm.isPlaying) {
        await bgm.pause();
        setState(() => _paused = true);
      } else {
        await bgm.resume();
        setState(() => _paused = false);
      }
      return;
    }

    if (active.value.isPlaying) {
      await Future.wait([active.pause(), bgm.pause()]);
      setState(() => _paused = true);
    } else {
      await Future.wait([active.play(), bgm.resume()]);
      setState(() => _paused = false);
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.numpadEnter ||
          k == LogicalKeyboardKey.space) {
        _goNext();
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.escape) {
        _goHomeToSplash();
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.keyP) {
        _togglePause();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  bool _isInControllerArea(Offset g, Size s) {
    final scale = _calcScale(s);
    final canvasW = baseW * scale, canvasH = baseH * scale;
    final leftPad = (s.width - canvasW) / 2, topPad = (s.height - canvasH) / 2;
    final w = _controllerBaseW * scale, h = _controllerBaseH * scale;
    final x = leftPad + (canvasW - controllerRightPx * scale) - w;
    final y = topPad + controllerTopPx * scale;
    return Rect.fromLTWH(x, y, w, h).contains(g);
  }

  double _calcScale(Size s) => min(s.width / baseW, s.height / baseH);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scale = _calcScale(size);
    final canvasW = baseW * scale, canvasH = baseH * scale;
    final leftPad = (size.width - canvasW) / 2,
        topPad = (size.height - canvasH) / 2;

    final ready = _ready && _error == null;

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTapDown: (d) {
        if (!_isInControllerArea(d.globalPosition, size)) _goNext();
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (ready) ...[
                Positioned.fill(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _loopC.value.size.width,
                      height: _loopC.value.size.height,
                      child: VideoPlayer(_loopC),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Visibility(
                    visible: _showIntro,
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: true,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _introC.value.size.width,
                        height: _introC.value.size.height,
                        child: VideoPlayer(_introC),
                      ),
                    ),
                  ),
                ),
              ] else
                _loadingOrError(),

              const Positioned(
                right: 16,
                bottom: 24,
                child: Text(
                  '탭 또는 Enter로 계속',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),

              if (_error != null && Platform.isWindows)
                const Positioned(
                  left: 16,
                  bottom: 24,
                  right: 16,
                  child: Text(
                    '힌트: Windows 배포 시 MP4(H.264 + AAC) 권장.\n다른 코덱/컨테이너는 재생이 안 될 수 있어요.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),

              Positioned(
                left: leftPad,
                top: topPad,
                width: canvasW,
                height: canvasH,
                child: Stack(
                  children: [
                    Positioned(
                      top: controllerTopPx * scale,
                      right: controllerRightPx * scale,
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.topRight,
                        child: GameControllerBar(
                          isPaused: _paused,
                          onHome: _goHomeToSplash,
                          onPrev: _goPrev,
                          onNext: _goNext,
                          onPauseToggle: _togglePause,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadingOrError() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black, Color(0xFF101016)],
      ),
    ),
    child: Center(
      child: _error == null
          ? const CircularProgressIndicator()
          : const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.white70, size: 36),
                SizedBox(height: 12),
                Text(
                  '학습 영상을 불러올 수 없어요.\n탭/Enter로 계속 진행합니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
    ),
  );
}
