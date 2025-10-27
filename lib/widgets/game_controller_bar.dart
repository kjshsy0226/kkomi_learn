import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class GameControllerBar extends StatefulWidget {
  const GameControllerBar({
    super.key,
    this.onHome,
    this.onPrev,
    this.onNext,
    this.onPauseToggle,
    this.onExit,
    this.isPaused = false,
  });

  final VoidCallback? onHome;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onPauseToggle;
  final VoidCallback? onExit;
  final bool isPaused;

  @override
  State<GameControllerBar> createState() => _GameControllerBarState();
}

class _GameControllerBarState extends State<GameControllerBar> {
  // 바/버튼 크기 (bar.png: 580×135)
  static const double _barW = 580;
  static const double _barH = 135;

  static const double _btnW = 99;
  static const double _btnH = 106;

  // 5개 맞춤: 5*99 + 4*12 + 2*10 = 563 <= 580
  static const double _hPad = 10;
  static const double _gap = 12;

  // 프레스 상태
  bool _pressedHome = false;
  bool _pressedPrev = false;
  bool _pressedPause = false;
  bool _pressedNext = false;
  bool _pressedExit = false;

  // 클릭 SFX (저지연 최적화)
  late final AudioPlayer _tapPlayer;

  @override
  void initState() {
    super.initState();
    _tapPlayer = AudioPlayer();
    _tapPlayer.setPlayerMode(PlayerMode.lowLatency);
    _tapPlayer.setReleaseMode(ReleaseMode.stop);
    _tapPlayer.setVolume(0.9);

    // (선택) 미리 로드
    _tapPlayer.setSource(AssetSource('audio/sfx/btn_tap.mp3'));
  }

  @override
  void dispose() {
    _tapPlayer.dispose();
    super.dispose();
  }

  Future<void> _playTap() async {
    await _tapPlayer.seek(Duration.zero); // 맨 앞으로
    await _tapPlayer.resume(); // 현재 소스 재생
  }

  void _resetPressed() {
    _pressedHome = _pressedPrev = _pressedPause = _pressedNext = _pressedExit =
        false;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _barW,
      height: _barH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/ui/controller/bar.png', fit: BoxFit.fill),
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _hPad),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildButton(
                    normal: 'assets/images/ui/controller/btn_home.png',
                    pressed: 'assets/images/ui/controller/btn_home_pressed.png',
                    pressedFlag: _pressedHome,
                    setPressed: (v) => setState(() => _pressedHome = v),
                    onTap: () {
                      _playTap();
                      widget.onHome?.call();
                    },
                  ),
                  const SizedBox(width: _gap),
                  _buildButton(
                    normal: 'assets/images/ui/controller/btn_prev.png',
                    pressed: 'assets/images/ui/controller/btn_prev_pressed.png',
                    pressedFlag: _pressedPrev,
                    setPressed: (v) => setState(() => _pressedPrev = v),
                    onTap: () {
                      _playTap();
                      widget.onPrev?.call();
                    },
                  ),
                  const SizedBox(width: _gap),
                  _buildButton(
                    normal: widget.isPaused
                        ? 'assets/images/ui/controller/btn_play.png'
                        : 'assets/images/ui/controller/btn_pause.png',
                    pressed: widget.isPaused
                        ? 'assets/images/ui/controller/btn_play_pressed.png'
                        : 'assets/images/ui/controller/btn_pause_pressed.png',
                    pressedFlag: _pressedPause,
                    setPressed: (v) => setState(() => _pressedPause = v),
                    onTap: () {
                      _playTap();
                      widget.onPauseToggle?.call();
                    },
                  ),
                  const SizedBox(width: _gap),
                  _buildButton(
                    normal: 'assets/images/ui/controller/btn_next.png',
                    pressed: 'assets/images/ui/controller/btn_next_pressed.png',
                    pressedFlag: _pressedNext,
                    setPressed: (v) => setState(() => _pressedNext = v),
                    onTap: () {
                      _playTap();
                      widget.onNext?.call();
                    },
                  ),
                  const SizedBox(width: _gap),
                  _buildButton(
                    normal: 'assets/images/ui/controller/btn_exit.png',
                    pressed: 'assets/images/ui/controller/btn_exit_pressed.png',
                    pressedFlag: _pressedExit,
                    setPressed: (v) => setState(() => _pressedExit = v),
                    onTap: () {
                      _playTap();
                      widget.onExit?.call();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String normal,
    required String pressed,
    required bool pressedFlag,
    required ValueChanged<bool> setPressed,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTapDown: (_) => setPressed(true),
      onTapUp: (_) {
        setPressed(false);
        onTap();
      },
      onTapCancel: () => setState(_resetPressed),
      child: Image.asset(
        pressedFlag ? pressed : normal,
        width: _btnW,
        height: _btnH,
        fit: BoxFit.contain,
      ),
    );
  }
}
