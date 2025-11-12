import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../core/bgm_tracks.dart';
import '../widgets/game_controller_bar.dart';
import '../utils/routes.dart';
import 'learn_set1_screen.dart';
import 'learn_set3_screen.dart';

class LearnSet2Screen extends StatefulWidget {
  const LearnSet2Screen({
    super.key,
    this.introPath = 'assets/videos/scene/set2_scene.mp4',
    this.loopPath = 'assets/videos/scene/set2_scene_loop.mp4',
  });

  final String introPath;
  final String loopPath;

  @override
  State<LearnSet2Screen> createState() => _LearnSet2ScreenState();
}

class _LearnSet2ScreenState extends State<LearnSet2Screen> {
  static const double baseW = 1920,
      baseH = 1080,
      controllerTopPx = 35,
      controllerRightPx = 40;
  static const double _controllerBaseW = 580, _controllerBaseH = 135;

  late final VideoPlayerController _introC, _loopC;
  bool _ready = false, _showIntro = true, _paused = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    GlobalBgm.instance.ensureStory();

    _introC = VideoPlayerController.asset(widget.introPath)
      ..setLooping(false)
      ..addListener(_onIntroTick);
    _loopC = VideoPlayerController.asset(widget.loopPath)..setLooping(true);

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Future.wait([_introC.initialize(), _loopC.initialize()]);
      if (!mounted) return;

      await _introC.play(); await _introC.pause();
      await _loopC.play();  await _loopC.pause();

      setState(() => _ready = true);

      await _introC.seekTo(Duration.zero);
      await _introC.play();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _onIntroTick() {
    final v = _introC.value;
    if (v.hasError && _error == null) {
      setState(() => _error = v.errorDescription ?? 'Video error');
      return;
    }
    if (v.isInitialized && !v.isPlaying && v.position >= v.duration) {
      _startLoopAndHideIntro();
    }
  }

  Future<void> _startLoopAndHideIntro() async {
    try {
      await _loopC.seekTo(Duration.zero);
      await _loopC.play();
      try { await _introC.pause(); } catch (_) {}
      if (!mounted) return;
      setState(() { _showIntro = false; _paused = false; });
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

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  void _goPrev() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      fadeRouteWhite(const LearnSet1Screen()), // ✅ 흰 배경 보장 라우트
    );
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      fadeRouteWhite(const LearnSet3Screen()), // ✅ 흰 배경 보장 라우트
    );
  }

  KeyEventResult _onKeyEvent(FocusNode n, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.space) {
      _goNext(); return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      _goHome(); return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyP) {
      _togglePause(); return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _togglePause() async {
    final active = _showIntro ? _introC : _loopC;
    final bgm = GlobalBgm.instance;

    if (!active.value.isInitialized || _error != null) {
      if (bgm.isPlaying) {
        await bgm.pause(); setState(() => _paused = true);
      } else {
        await bgm.resume(); setState(() => _paused = false);
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

  bool _isInControllerArea(Offset gp, Size sz) {
    final s = min(sz.width / baseW, sz.height / baseH);
    final cW = baseW * s, cH = baseH * s;
    final l = (sz.width - cW) / 2, t = (sz.height - cH) / 2;
    final w = _controllerBaseW * s, h = _controllerBaseH * s;
    final x = l + (cW - controllerRightPx * s) - w, y = t + controllerTopPx * s;
    return Rect.fromLTWH(x, y, w, h).contains(gp);
  }

  @override
  Widget build(BuildContext context) {
    final ready = _ready && _error == null;
    final size = MediaQuery.of(context).size;
    final s = min(size.width / baseW, size.height / baseH);
    final cW = baseW * s, cH = baseH * s;
    final l = (size.width - cW) / 2, t = (size.height - cH) / 2;

    return Focus(
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTapDown: (d) {
          if (!_isInControllerArea(d.globalPosition, size)) _goNext();
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.white), // ✅ 바닥 흰색
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
              ] else ...[
                const ColoredBox(color: Colors.white),
                const Center(
                  child: SizedBox(
                    width: 36, height: 36,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ),
              ],
              if (_error != null && Platform.isWindows)
                Positioned(
                  left: 16, bottom: 24, right: 16,
                  child: Text(
                    '힌트: Windows 배포 시 MP4(H.264 + AAC) 권장.\n다른 코덱/컨테이너는 재생이 안 될 수 있어요.',
                    style: TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                ),
              Positioned(
                left: l, top: t, width: cW, height: cH,
                child: Stack(
                  children: [
                    Positioned(
                      top: controllerTopPx * s,
                      right: controllerRightPx * s,
                      child: Transform.scale(
                        scale: s,
                        alignment: Alignment.topRight,
                        child: GameControllerBar(
                          isPaused: _paused,
                          onHome: _goHome,
                          onPrev: _goPrev,
                          onNext: _goNext,
                          onPauseToggle: _togglePause,
                          onExit: () => GlobalBgm.instance.stopStory(),
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
}
