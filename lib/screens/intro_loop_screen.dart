// lib/widgets/intro_loop_screen.dart
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
    this.hintText = '탭 또는 Enter로 계속',
    this.errorText = '영상을 불러올 수 없어요.\n탭/Enter로 계속 진행합니다.',
    this.loopOnStart = false, // true면 인트로 생략하고 loop부터 재생
  });

  final String introVideoAsset;
  final String loopVideoAsset;
  final String? bgmAsset;
  final VoidCallback onNext;
  final String hintText;
  final String errorText;
  final bool loopOnStart;

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
        await _bgm.setVolume(1.0);
        await _bgm.play(AssetSource(widget.bgmAsset!));
      }

      setState(() => _ready = true);

      if (widget.loopOnStart) {
        _showIntro = false;
        await _loopC.seekTo(Duration.zero);
        await _loopC.play();
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
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _introC.removeListener(_onIntroTick);
    _introC.dispose();
    _loopC.dispose();
    _bgm.stop();
    _bgm.dispose();
    super.dispose();
  }

  Future<void> _stopAllAndNext() async {
    try {
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

              Positioned(
                right: 16,
                bottom: 24,
                child: Text(
                  widget.hintText,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
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
}
