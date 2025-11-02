// lib/screens/intro_loop_screen.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';

class IntroLoopScreen extends StatefulWidget {
  const IntroLoopScreen({
    super.key,
    required this.introVideoAsset,
    required this.loopVideoAsset,
    this.bgmAsset, // null이면 BGM 사용 안 함
    required this.onNext, // 탭/엔터로 다음으로
    this.errorText = '영상을 불러올 수 없어요.\n탭/Enter로 계속 진행합니다.',
    this.loopOnStart = false, // true면 인트로 생략하고 loop부터 재생
    // ▼ BGM 동작 제어
    this.bgmStartOnLoop = true, // true: 인트로 동안 BGM off → loop에서 페이드 인
    this.bgmIntroVolume = 0.2, // 인트로 깔음(0~1). bgmStartOnLoop=true면 무시
    this.bgmTargetVolume = 1.0, // 루프 목표 볼륨
    this.bgmFadeInMs = 1200, // 루프 진입 페이드 인 시간(ms)
  });

  final String introVideoAsset;
  final String loopVideoAsset;
  final String? bgmAsset;
  final VoidCallback onNext;
  final String errorText;
  final bool loopOnStart;

  // BGM 파라미터
  final bool bgmStartOnLoop;
  final double bgmIntroVolume;
  final double bgmTargetVolume;
  final int bgmFadeInMs;

  @override
  State<IntroLoopScreen> createState() => _IntroLoopScreenState();
}

class _IntroLoopScreenState extends State<IntroLoopScreen> {
  late final VideoPlayerController _introC;
  late final VideoPlayerController _loopC;
  final AudioPlayer _bgm = AudioPlayer();

  bool _ready = false;
  bool _showIntro = true;
  String? _error;

  Timer? _fadeTimer; // 볼륨 페이드용
  double _bgmVol = 0.0; // 현재 BGM 볼륨(로컬 상태로만 관리)

  @override
  void initState() {
    super.initState();

    _introC =
        VideoPlayerController.asset(
            widget.introVideoAsset,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          )
          ..setLooping(false)
          ..addListener(_onIntroTick);

    _loopC = VideoPlayerController.asset(
      widget.loopVideoAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..setLooping(true);

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Future.wait([_introC.initialize(), _loopC.initialize()]);

      // 워밍업
      await _introC.play();
      await _introC.pause();
      await _loopC.play();
      await _loopC.pause();

      if (widget.bgmAsset != null) {
        await _bgm.setReleaseMode(ReleaseMode.loop);

        if (widget.bgmStartOnLoop) {
          // 인트로에선 재생 안 함 (멘트 방해 X)
          await _bgm.stop();
          _bgmVol = 0.0; // 상태 초기화
        } else {
          // 인트로부터 아주 작게 재생
          final v = _clamp01(widget.bgmIntroVolume);
          await _setBgmVolume(v);
          await _bgm.play(AssetSource(widget.bgmAsset!));
        }
      }

      setState(() => _ready = true);

      if (widget.loopOnStart) {
        _showIntro = false;
        await _loopC.seekTo(Duration.zero);
        await _loopC.play();
        await _maybeStartOrFadeBgmOnLoopEntry();
      } else {
        await _introC.seekTo(Duration.zero);
        await _introC.play();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  void _onIntroTick() {
    if (_error != null) return;
    final v = _introC.value;
    if (!v.isInitialized) return;

    if (v.hasError) {
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
      setState(() => _showIntro = false);

      // 루프 진입 시점에 BGM 시작/페이드
      await _maybeStartOrFadeBgmOnLoopEntry();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _maybeStartOrFadeBgmOnLoopEntry() async {
    if (widget.bgmAsset == null) return;

    final target = _clamp01(widget.bgmTargetVolume);
    final fadeMs = widget.bgmFadeInMs.clamp(0, 10000);

    if (widget.bgmStartOnLoop) {
      // 인트로엔 미재생 → 루프부터 0에서 시작해 페이드 인
      await _setBgmVolume(0.0);
      await _bgm.play(AssetSource(widget.bgmAsset!));
      if (fadeMs > 0) {
        _fadeVolume(from: 0.0, to: target, durationMs: fadeMs);
      } else {
        await _setBgmVolume(target);
      }
    } else {
      // 인트로 동안 낮게 재생 중 → 루프에서 목표까지 페이드
      final currentVol = _bgmVol; // 로컬 상태 사용
      if (fadeMs > 0) {
        _fadeVolume(from: currentVol, to: target, durationMs: fadeMs);
      } else {
        await _setBgmVolume(target);
      }
    }
  }

  void _fadeVolume({
    required double from,
    required double to,
    required int durationMs,
  }) {
    _fadeTimer?.cancel();

    final steps = (durationMs / 16).clamp(1, 1000).round(); // ~60fps
    final stepDt = Duration(milliseconds: (durationMs / steps).round());
    int tick = 0;

    _fadeTimer = Timer.periodic(stepDt, (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      tick++;
      final ratio = (tick / steps).clamp(0.0, 1.0);
      final v = from + (to - from) * ratio;
      await _setBgmVolume(v);
      if (tick >= steps) t.cancel();
    });
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _introC.removeListener(_onIntroTick);
    _introC.dispose();
    _loopC.dispose();
    _bgm.stop();
    _bgm.dispose();
    super.dispose();
  }

  Future<void> _stopAllAndNext() async {
    try {
      _fadeTimer?.cancel();
      await _introC.pause();
      await _loopC.pause();
      await _bgm.stop();
    } catch (_) {}
    if (!mounted) return;
    widget.onNext();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.numpadEnter ||
          k == LogicalKeyboardKey.space) {
        _stopAllAndNext();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final ready =
        _ready &&
        _introC.value.isInitialized &&
        _loopC.value.isInitialized &&
        _error == null;

    return GestureDetector(
      onTap: _stopAllAndNext,
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (ready) ...[
                // 바닥: loop
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
                // 위: intro (끝나면 즉시 숨김)
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
                // 프리로딩/에러
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
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.white70,
                                size: 36,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.errorText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
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
                    '힌트: Windows 배포 시 MP4(H.264 + AAC) 권장.\n다른 코덱/컨테이너는 재생이 안 될 수 있어요.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 유틸 ──────────────────────────────────────────────────────────────
  double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  Future<void> _setBgmVolume(double v) async {
    _bgmVol = _clamp01(v);
    try {
      await _bgm.setVolume(_bgmVol);
    } catch (_) {}
  }
}
