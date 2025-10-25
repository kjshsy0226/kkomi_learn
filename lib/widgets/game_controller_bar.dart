import 'package:flutter/material.dart';

class GameControllerBar extends StatefulWidget {
  final VoidCallback? onHome;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onPauseToggle;
  final bool isPaused;

  const GameControllerBar({
    super.key,
    this.onHome,
    this.onPrev,
    this.onNext,
    this.onPauseToggle,
    this.isPaused = false,
  });

  @override
  State<GameControllerBar> createState() => _GameControllerBarState();
}

class _GameControllerBarState extends State<GameControllerBar> {
  // 바 고정 크기(디자인 기준)
  static const double _barW = 460;
  static const double _barH = 135;

  // 버튼 실제 렌더 크기 (요청: 99×106)
  static const double _btnW = 99;
  static const double _btnH = 106;

  // 4개 버튼이 바 안에 정확히 들어가도록 패딩/간격 조정
  // 396(버튼폭 합) + 62(여유: 좌우패딩 10*2 + 간격 14*3) = 458 <= 460
  static const double _hPad = 10; // 좌우 패딩
  static const double _gap = 14; // 버튼 사이 간격

  bool _pressedHome = false;
  bool _pressedPrev = false;
  bool _pressedPause = false;
  bool _pressedNext = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _barW,
      height: _barH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 바
          Image.asset('assets/images/ui/controller/bar.png', fit: BoxFit.fill),

          // 버튼들
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
                    onTapDown: () => setState(() => _pressedHome = true),
                    onTapUp: () {
                      setState(() => _pressedHome = false);
                      widget.onHome?.call();
                    },
                  ),
                  const SizedBox(width: _gap),
                  _buildButton(
                    normal: 'assets/images/ui/controller/btn_prev.png',
                    pressed: 'assets/images/ui/controller/btn_prev_pressed.png',
                    pressedFlag: _pressedPrev,
                    onTapDown: () => setState(() => _pressedPrev = true),
                    onTapUp: () {
                      setState(() => _pressedPrev = false);
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
                    onTapDown: () => setState(() => _pressedPause = true),
                    onTapUp: () {
                      setState(() => _pressedPause = false);
                      widget.onPauseToggle?.call();
                    },
                  ),
                  const SizedBox(width: _gap),
                  _buildButton(
                    normal: 'assets/images/ui/controller/btn_next.png',
                    pressed: 'assets/images/ui/controller/btn_next_pressed.png',
                    pressedFlag: _pressedNext,
                    onTapDown: () => setState(() => _pressedNext = true),
                    onTapUp: () {
                      setState(() => _pressedNext = false);
                      widget.onNext?.call();
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
    required VoidCallback onTapDown,
    required VoidCallback onTapUp,
  }) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: () => setState(() {
        _pressedHome = _pressedPrev = _pressedPause = _pressedNext = false;
      }),
      child: Image.asset(
        pressedFlag ? pressed : normal,
        width: _btnW,
        height: _btnH,
        fit: BoxFit.contain, // 비율 유지 (원형 이미지 왜곡 방지)
      ),
    );
  }
}
