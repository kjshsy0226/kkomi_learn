import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kkomi_learn/screens/learn_set1_screen.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final VideoPlayerController _c;
  bool _initTried = false;
  bool _initOk = false;
  bool _ended = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Windows 배포 시: splash.mp4는 H.264 + AAC 권장 (Media Foundation 호환)
    _c = VideoPlayerController.asset('assets/videos/splash.mp4')
      ..setLooping(false)
      ..addListener(_onVideoTick);

    _initialize();
  }

  Future<void> _initialize() async {
    if (_initTried) return;
    _initTried = true;
    try {
      await _c.initialize();
      if (!mounted) return;

      // 첫 프레임 고정 패턴: 짧게 play → pause
      await _c.play();
      await _c.pause();

      setState(() {
        _initOk = true;
      });

      // 자동 재생 원하면 아래 주석 해제
      await _c.play();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _initOk = false;
      });
    }
  }

  void _onVideoTick() {
    final v = _c.value;
    if (v.hasError && _error == null) {
      setState(() => _error = v.errorDescription ?? 'Video error');
    }
    if (v.isInitialized && !v.isPlaying && v.position >= v.duration) {
      if (!_ended) {
        _ended = true;
        _c.pause();
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onVideoTick);
    _c.dispose();
    super.dispose();
  }

  void _goNext() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, a, b) => const LearnSet1Screen(),
        transitionsBuilder: (context, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // ✅ 새로운 키 이벤트 API 사용 (3.18+)
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.space) {
        _goNext();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final canShowVideo = _initOk && _c.value.isInitialized && _error == null;

    return GestureDetector(
      onTap: _goNext, // 탭/클릭으로 진행
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKeyEvent, // ✅ deprecated된 onKey 대신 onKeyEvent
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (canShowVideo)
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
                                '동영상을 불러올 수 없어요.\n탭하여 계속 진행하세요.',
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
              const Positioned(
                right: 16,
                bottom: 24,
                child: Text(
                  '탭 또는 Enter로 시작',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              if (_error != null && (Platform.isWindows))
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
            ],
          ),
        ),
      ),
    );
  }
}
