import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'splash_screen.dart';

class QuizResultScreen extends StatefulWidget {
  const QuizResultScreen({super.key});

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  late final VideoPlayerController _c;
  bool _inited = false;
  bool _navigating = false;
  String? _error;

  late final VoidCallback _onTick;

  @override
  void initState() {
    super.initState();

    _c = VideoPlayerController.asset('assets/videos/result.mp4')
      ..setLooping(false);

    _onTick = () {
      if (!_c.value.isInitialized) return;
      final v = _c.value;

      if (v.hasError && _error == null) {
        _error = v.errorDescription ?? 'Video error';
        _c.pause();
      }

      // 끝나면 마지막 프레임에서 정지 유지 (자동 이동 없음)
      if (!v.isPlaying && v.isInitialized && v.position >= v.duration) {
        _c.pause();
      }

      if (mounted) setState(() {});
    };

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _c.initialize();
      if (!mounted) return;

      _c.addListener(_onTick);

      // 첫 프레임 보장: 짧게 play → 즉시 pause
      await _c.play();
      await _c.pause();

      setState(() {
        _inited = true;
      });

      // 결과 화면은 자동 재생
      await _c.play();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _inited = false;
      });
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onTick);
    _c.dispose();
    super.dispose();
  }

  void _backToSplash() {
    if (_navigating || !mounted) return;
    _navigating = true;

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (c, a, b) => const SplashScreen(),
        transitionsBuilder: (c, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
      (_) => false,
    );
  }

  // Flutter 3.18+ 키 이벤트 API
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.numpadEnter ||
          k == LogicalKeyboardKey.space) {
        _backToSplash();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final ready = _inited && _c.value.isInitialized && _error == null;

    return GestureDetector(
      onTap: _backToSplash, // 탭하면 처음으로
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
                                '결과 영상을 불러올 수 없어요.\n탭 또는 Enter로 처음으로 돌아갑니다.',
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
            ],
          ),
        ),
      ),
    );
  }
}
