// lib/screens/learn_set3_screen.dart
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../widgets/game_controller_bar.dart'; // ✅ 컨트롤러
import 'learn_set2_screen.dart'; // ✅ 이전 화면
import 'game_set2_screen.dart'; // ✅ 다음 단계 화면

class LearnSet3Screen extends StatefulWidget {
  const LearnSet3Screen({
    super.key,
    this.videoPath = 'assets/videos/scene/set3_scene.mp4',
  });

  /// 재생할 세 번째 학습 영상 경로 (배경 포함 1920x1080 권장)
  final String videoPath;

  @override
  State<LearnSet3Screen> createState() => _LearnSet3ScreenState();
}

class _LearnSet3ScreenState extends State<LearnSet3Screen> {
  // ── 기준 캔버스(1920×1080) & 컨트롤러 위치 ─────────────────────────────
  static const double baseW = 1920;
  static const double baseH = 1080;
  static const double controllerTopPx = 35;
  static const double controllerRightPx = 40;
  static const double _controllerBaseW = 460;
  static const double _controllerBaseH = 135;

  late final VideoPlayerController _c;
  bool _inited = false;
  String? _error;
  bool _ended = false;
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

      // 첫 프레임 보장(플레이→즉시 일시정지)
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
        _c.pause(); // 마지막 프레임 유지
        setState(() => _paused = true);
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
        pageBuilder: (c, a, b) => const GameSet2Screen(),
        transitionsBuilder: (c, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _goPrev() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (c, a, b) => const LearnSet2Screen(),
        transitionsBuilder: (c, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _goHomeToSplash() async {
    if (!mounted) return;
    // MaterialApp에서 '/' 라우트가 스플래시/메인이어야 함
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  // ── 컨트롤러: 재생/일시정지 ───────────────────────────────────────────
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

  // 키보드: Enter/Space=다음, Esc=홈, P=일시정지
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

  // 부모 제스처가 컨트롤러 영역 탭을 먹지 않도록 영역 체크
  bool _isInControllerArea(Offset globalPos, Size screenSize) {
    final scale = _calcScale(screenSize);
    final canvasW = baseW * scale;
    final canvasH = baseH * scale;
    final leftPad = (screenSize.width - canvasW) / 2;
    final topPad = (screenSize.height - canvasH) / 2;

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

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTapDown: (d) {
        // 컨트롤러 영역 탭이면 무시, 아니면 다음으로
        if (!_isInControllerArea(d.globalPosition, screenSize)) {
          _goNext();
        }
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
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
                // 로딩/에러 뷰
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
                                '세 번째 학습 영상을 불러올 수 없어요.\n탭/Enter로 계속 진행합니다.',
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

              // 컨트롤러(1920×1080 기준 좌표에 맞춰 배치)
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
                          onHome: _goHomeToSplash, // 🏠 홈=스플래시('/')
                          onPrev: _goPrev, // ⬅️ 이전=LearnSet2Screen
                          onNext: _goNext, // ➡️ 다음=GameSet2Screen
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
