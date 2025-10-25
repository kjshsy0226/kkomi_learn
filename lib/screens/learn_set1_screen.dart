// lib/screens/learn_set1_screen.dart
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../widgets/game_controller_bar.dart';
import 'game_set1_screen.dart';

class LearnSet1Screen extends StatefulWidget {
  const LearnSet1Screen({
    super.key,
    this.initialIndex = 0, // 필요하면 GameSet1Screen으로 넘겨써도 됨
    this.videoPath = 'assets/videos/scene/set1_scene.mp4',
  });

  final int initialIndex;
  final String videoPath;

  @override
  State<LearnSet1Screen> createState() => _LearnSet1ScreenState();
}

class _LearnSet1ScreenState extends State<LearnSet1Screen> {
  // ── 기준 캔버스 사이즈(1920×1080) ─────────────────────────────────────
  static const double baseW = 1920;
  static const double baseH = 1080;

  // ── 컨트롤러 위치(캔버스 좌표, GameSet1Screen과 동일) ───────────────
  static const double controllerTopPx = 35;
  static const double controllerRightPx = 40;

  // 컨트롤러 실제 고정 크기(디자인 기준)
  static const double _controllerBaseW = 460;
  static const double _controllerBaseH = 135;

  late final VideoPlayerController _c;
  bool _inited = false;
  String? _error;
  bool _ended = false;

  // 컨트롤러 표시 상태
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.asset(widget.videoPath)
      ..setLooping(false)
      ..addListener(_onTick);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _c.initialize();
      if (!mounted) return;

      // 첫 프레임 보장
      await _c.play();
      await _c.pause();

      setState(() {
        _inited = true;
        _paused = false;
      });

      // 자동 재생
      await _c.play();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _inited = false;
      });
    }
  }

  void _onTick() {
    final v = _c.value;
    if (v.hasError && _error == null) {
      setState(() => _error = v.errorDescription ?? 'Video error');
    }
    if (v.isInitialized && !v.isPlaying && v.position >= v.duration) {
      if (!_ended) {
        _ended = true;
        _c.pause();
        setState(() {
          _paused = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onTick);
    _c.dispose();
    super.dispose();
  }

  // ── 네비게이션 ────────────────────────────────────────────────────────
  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (c, a, b) =>
            GameSet1Screen(initialIndex: widget.initialIndex),
        transitionsBuilder: (c, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // ✅ 스택 상태와 무관하게 메인(스플래시)으로 강제 복귀
  void _goSplashOrMain() {
    if (!mounted) return;
    // MaterialApp에서 '/' 라우트가 스플래시/메인이어야 함
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  // Flutter 3.18+ 키 이벤트 API
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
        _goSplashOrMain();
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.keyP) {
        _togglePause();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _togglePause() async {
    if (!_inited || !_c.value.isInitialized) return;
    if (_c.value.isPlaying) {
      await _c.pause();
      setState(() => _paused = true);
    } else {
      await _c.play();
      setState(() {
        _paused = false;
        _ended = false;
      });
    }
  }

  // 부모 제스처가 컨트롤러 영역 탭을 먹지 않도록 영역 체크
  bool _isInControllerArea(Offset globalPos, Size screenSize) {
    final sz = screenSize;
    final scale = _calcScale(sz);
    final canvasW = baseW * scale;
    final canvasH = baseH * scale;
    final leftPad = (sz.width - canvasW) / 2;
    final topPad = (sz.height - canvasH) / 2;

    final ctrlW = _controllerBaseW * scale;
    final ctrlH = _controllerBaseH * scale;

    final ctrlLeft = leftPad + (canvasW - controllerRightPx * scale) - ctrlW;
    final ctrlTop = topPad + controllerTopPx * scale;
    final rect = Rect.fromLTWH(ctrlLeft, ctrlTop, ctrlW, ctrlH);
    return rect.contains(globalPos);
  }

  double _calcScale(Size screenSize) {
    return min(screenSize.width / baseW, screenSize.height / baseH);
  }

  @override
  Widget build(BuildContext context) {
    final ready = _inited && _c.value.isInitialized && _error == null;
    final screenSize = MediaQuery.of(context).size;

    // 스케일/패딩(컨트롤러 위치에 사용)
    final scale = _calcScale(screenSize);
    final canvasW = baseW * scale;
    final canvasH = baseH * scale;
    final leftPad = (screenSize.width - canvasW) / 2;
    final topPad = (screenSize.height - canvasH) / 2;

    return Focus(
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTapDown: (d) {
          // 컨트롤러 영역 탭이면 무시, 아니면 다음으로
          if (!_isInControllerArea(d.globalPosition, screenSize)) {
            _goNext();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ── 비디오 레이어 ───────────────────────────────────────────
              if (ready)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _c.value.size.width,
                    height: _c.value.size.height,
                    child: VideoPlayer(_c),
                  ),
                )
              else
                Container(
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
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.error_outline,
                                color: Colors.white70,
                                size: 36,
                              ),
                              SizedBox(height: 12),
                              Text(
                                '영상을 불러올 수 없어요.\n탭/Enter로 계속 진행합니다.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

              // ── 우하단 힌트 텍스트 ─────────────────────────────────────
              const Positioned(
                right: 16,
                bottom: 24,
                child: Text(
                  '탭 또는 Enter로 계속',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),

              // ── Windows 코덱 힌트 ──────────────────────────────────────
              if (_error != null && Platform.isWindows)
                const Positioned(
                  left: 16,
                  bottom: 24,
                  right: 16,
                  child: Text(
                    '힌트: Windows 배포 시 MP4(H.264 + AAC) 권장.\n'
                    '다른 코덱/컨테이너는 재생이 안 될 수 있어요.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),

              // ── 컨트롤러(1920×1080 기준 좌표에 맞춰 배치) ─────────────
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
                          onHome: _goSplashOrMain, // 홈=메인(스플래시)로
                          onPrev: _goSplashOrMain, // 이전=메인(스플래시)로
                          onNext: _goNext, // 다음=GameSet1Screen
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
}
