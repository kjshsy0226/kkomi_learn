// lib/screens/learn_set5_screen.dart
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../core/bgm_tracks.dart'; // ✅ 스토리 BGM 숏컷(ensureStory/stopStory)
import '../core/global_sfx.dart';
import '../widgets/game_controller_bar.dart';
import 'game_set1_screen.dart';
import 'learn_set6_screen.dart';

class LearnSet5Screen extends StatefulWidget {
  const LearnSet5Screen({
    super.key,
    this.introPath = 'assets/videos/scene/set5_scene.mp4',
    this.loopPath = 'assets/videos/scene/set5_scene_loop.mp4',
  });

  final String introPath;
  final String loopPath;

  @override
  State<LearnSet5Screen> createState() => _LearnSet5ScreenState();
}

class _LearnSet5ScreenState extends State<LearnSet5Screen>
    with SingleTickerProviderStateMixin {
  // 기준 캔버스/컨트롤러 좌표
  static const double baseW = 1920, baseH = 1080;
  static const double controllerTopPx = 35, controllerRightPx = 40;
  static const double _controllerBaseW = 580, _controllerBaseH = 135;

  // 비디오
  late final VideoPlayerController _introC; // 단발
  late final VideoPlayerController _loopC; // 반복
  bool _ready = false; // 두 영상 initialize 완료
  bool _showIntro = true; // 위 레이어(인트로) 표시 여부
  bool _paused = false;
  String? _error;

  // 아웃라인 깜빡임 (인트로 끝→루프 시작과 동시에 켬)
  late final AnimationController _cueCtrl;
  late final Animation<double> _cueOpacity;
  bool _showCue = false;

  @override
  void initState() {
    super.initState();

    // ✅ 게임에서 돌아온 지점: 스토리 BGM 재개/보장
    // (이미 재생 중이면 그대로, 멈춰있으면 재시작)
    GlobalBgm.instance.ensureStory();

    _cueCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _cueOpacity = CurvedAnimation(parent: _cueCtrl, curve: Curves.easeInOut);

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

      // 텍스처 워밍업
      await _introC.play();
      await _introC.pause();
      await _loopC.play();
      await _loopC.pause();

      setState(() => _ready = true);

      // 인트로부터 재생
      await _introC.seekTo(Duration.zero);
      await _introC.play();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  // 인트로 끝나는 순간 → (1) 루프 0부터 재생, (2) 인트로 즉시 숨김, (3) 아웃라인 깜빡임 시작
  void _onIntroTick() {
    final v = _introC.value;
    if (!v.isInitialized) return;

    if (v.hasError && _error == null) {
      setState(() => _error = v.errorDescription ?? 'Video error');
      return;
    }

    if (!v.isPlaying && v.position >= v.duration) {
      _startLoopAndShowCue();
    }
  }

  Future<void> _startLoopAndShowCue() async {
    try {
      await _loopC.seekTo(Duration.zero);
      await _loopC.play();
      try {
        await _introC.pause();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _showIntro = false; // ✨ 페이드 없이 즉시 hide
        _showCue = true; // ✨ 깜빡임 오버레이 on
        _paused = false;
      });
      // 깜빡임 반복
      _cueCtrl
        ..stop()
        ..forward(from: 0)
        ..repeat(reverse: true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _introC.removeListener(_onIntroTick);
    _introC.dispose();
    _loopC.dispose();
    _cueCtrl.dispose();
    super.dispose();
  }

  // ── 네비게이션 ────────────────────────────────────────────────────────
  Future<void> _goNext() async {
    if (_showCue) {
      GlobalSfx.instance.play('tap'); // 아웃라인 상태에서 탭 사운드
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (c, a, b) => const LearnSet6Screen(),
        transitionsBuilder: (c, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _goPrev() async {
    // ✅ 이전은 게임으로 복귀 → 4씬의 반대 개념: 게임 직전에는 스토리 BGM을 중단
    await GlobalBgm.instance.stopStory();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (c, a, b) => const GameSet1Screen(),
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

  // 재생/일시정지 (🎵 BGM도 함께 제어)
  Future<void> _togglePause() async {
    final active = _showIntro ? _introC : _loopC;
    final bgm = GlobalBgm.instance;

    if (!active.value.isInitialized) {
      // 영상 상태 모르면 BGM만 토글
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

  // 키: Enter/Space 다음, Esc 홈, P 일시정지
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

  // 컨트롤러 영역 탭 무시
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

  double _calcScale(Size screenSize) =>
      min(screenSize.width / baseW, screenSize.height / baseH);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scale = _calcScale(size);
    final canvasW = baseW * scale, canvasH = baseH * scale;
    final leftPad = (size.width - canvasW) / 2;
    final topPad = (size.height - canvasH) / 2;

    final ready = _ready && _error == null;

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTapDown: (d) {
        if (_isInControllerArea(d.globalPosition, size)) return;
        _goNext();
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
                // 바닥: loop (처음엔 pause, 인트로 끝에 ۰부터 play)
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
                // 위: intro (끝나면 즉시 hide)
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

              // 인트로 종료 후(루프 재생과 동시에) 깜빡이는 아웃라인
              if (_showCue)
                FadeTransition(
                  opacity: _cueOpacity,
                  child: Image.asset(
                    'assets/images/kkomi_outline.png', // 1920x1080
                    fit: BoxFit.cover,
                  ),
                ),

              // Windows 코덱 힌트
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

              // 컨트롤러
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
                          onPrev: _goPrev, // ◀ 게임으로 이동 전 BGM stop
                          onNext: _goNext, // ▶ 스토리 계속 (BGM 유지)
                          onPauseToggle: _togglePause, // ❚❚ 영상+BGM 동시 제어
                          // 선택: 종료 시 스토리 BGM 정리
                          onExit: () {
                            GlobalBgm.instance.stopStory();
                          },
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
