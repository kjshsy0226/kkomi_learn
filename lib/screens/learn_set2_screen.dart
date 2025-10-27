// lib/screens/learn_set2_screen.dart
import 'dart:io' show Platform;
// import 'dart:async'; // 더 이상 unawaited 안 씀: 필요 없으면 주석/삭제
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../core/global_sfx.dart'; // ✅ 전역 SFX
import '../widgets/game_controller_bar.dart';
import 'game_set1_screen.dart';
import 'learn_set3_screen.dart';

class LearnSet2Screen extends StatefulWidget {
  const LearnSet2Screen({
    super.key,
    this.videoPath = 'assets/videos/scene/set2_scene.mp4',
  });

  final String videoPath;

  @override
  State<LearnSet2Screen> createState() => _LearnSet2ScreenState();
}

class _LearnSet2ScreenState extends State<LearnSet2Screen>
    with SingleTickerProviderStateMixin {
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

  late final AnimationController _cueCtrl;
  late final Animation<double> _cueOpacity;

  @override
  void initState() {
    super.initState();

    _cueCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _cueOpacity = CurvedAnimation(parent: _cueCtrl, curve: Curves.easeInOut);

    _c = VideoPlayerController.asset(widget.videoPath)
      ..setLooping(false)
      ..addListener(_onTick);

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _c.initialize();
      if (!mounted) return;

      await _c.play();
      await _c.pause();

      setState(() {
        _inited = true;
        _paused = false;
      });

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
        _startCueBlink();
        setState(() => _paused = true);
      }
    }
  }

  void _startCueBlink() {
    _cueCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      _cueCtrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.removeListener(_onTick);
    _c.dispose();
    _cueCtrl.dispose();
    super.dispose();
  }

  // ── 네비게이션 ────────────────────────────────────────────────────────
  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (c, a, b) => const LearnSet3Screen(),
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
        pageBuilder: (c, a, b) => const GameSet1Screen(
          initialIndex: 4, // radish
          startInPlay: true,
        ),
        transitionsBuilder: (c, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _goHomeToSplash() async {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  // ── 컨트롤러: 재생/일시정지 ───────────────────────────────────────────
  Future<void> _togglePause() async {
    if (!_inited || !_c.value.isInitialized) return;
    if (_c.value.isPlaying) {
      await _c.pause();
      setState(() => _paused = true);
    } else {
      if (_ended) {
        _ended = false;
        _cueCtrl.stop();
      }
      await _c.play();
      setState(() => _paused = false);
    }
  }

  // 키보드: Enter / Space 진행, Esc 홈, P 일시정지
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.numpadEnter ||
          k == LogicalKeyboardKey.space) {
        if (_ended) {
          GlobalSfx.instance.play('tap'); // ✅ 아웃라인 상태면 탭 사운드
        }
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

    final scale = _calcScale(screenSize);
    final canvasW = baseW * scale;
    final canvasH = baseH * scale;
    final leftPad = (screenSize.width - canvasW) / 2;
    final topPad = (screenSize.height - canvasH) / 2;

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTapDown: (d) {
        // 컨트롤러 영역 클릭은 무시
        if (_isInControllerArea(d.globalPosition, screenSize)) return;

        // ✅ 영상 끝(아웃라인)일 때만 탭 사운드 재생
        if (_ended) {
          GlobalSfx.instance.play('tap');
        }

        _goNext(); // 즉시 진행 (사운드는 전역이므로 끊기지 않음)
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1) 본편 영상
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
                                '두 번째 학습 영상을 불러올 수 없어요.\n탭/Enter로 계속 진행합니다.',
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

              // 2) 영상 끝났을 때 터치 유도 오버레이(꼬미 아웃라인)
              if (_ended)
                FadeTransition(
                  opacity: _cueOpacity,
                  child: Image.asset(
                    'assets/images/kkomi_outline.png', // 1920x1080
                    fit: BoxFit.cover,
                  ),
                ),

              // 3) 우하단 힌트 텍스트
              const Positioned(
                right: 16,
                bottom: 24,
                child: Text(
                  '탭 또는 Enter로 계속',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),

              // 4) Windows 코덱 힌트
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

              // 5) 컨트롤러
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
}
