// lib/widgets/game_controller_bar.dart
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../core/global_sfx.dart'; // ✅ 전역 SFX 싱글톤

class GameControllerBar extends StatefulWidget {
  const GameControllerBar({
    super.key,
    this.onHome,
    this.onPrev,
    this.onNext,
    this.onPauseToggle,
    this.onExit, // 윈도우 종료 전에 로그/세이브 등 추가 액션
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

  // Exit 더블클릭 잠금
  bool _exitLock = false;

  void _tapThen(VoidCallback? action) {
    GlobalSfx.instance.play('tap'); // ✅ 전역에서 재생 → 화면 전환/로직과 무관하게 계속 남
    action?.call();
  }

  Future<void> _tapThenExit({
    Duration? delay, // null이면 플랫폼별 기본값 사용
  }) async {
    if (_exitLock) return;
    _exitLock = true;

    // 1) 로그/세이브 등 선처리
    widget.onExit?.call();

    // 2) 전역 탭 사운드 재생
    GlobalSfx.instance.play('tap');

    // 3) 플랫폼별 최소 대기 (소리 끊김 방지)
    //    macOS는 살짝 더 길게 주는 게 안정적
    final d =
        delay ??
        (Theme.of(context).platform == TargetPlatform.macOS
            ? const Duration(milliseconds: 220)
            : const Duration(milliseconds: 180));
    await Future.delayed(d);

    // 4) 종료 시도: close() → 실패/무시 시 destroy()로 보강
    try {
      await windowManager.close(); // 일반적인 '창 닫기'
      // 일부 환경에서 close가 no-op일 수 있으므로 살짝 더 보장
      await Future.delayed(const Duration(milliseconds: 60));
      final isVisible = await windowManager.isVisible();
      if (isVisible == true) {
        await windowManager.destroy(); // 프로세스 종료에 가까운 동작
      }
    } catch (_) {
      try {
        await windowManager.destroy();
      } catch (_) {}
    } finally {
      _exitLock = false;
    }
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
                    onTap: () => _tapThen(widget.onHome),
                  ),
                  const SizedBox(width: _gap),
                  _buildButton(
                    normal: 'assets/images/ui/controller/btn_prev.png',
                    pressed: 'assets/images/ui/controller/btn_prev_pressed.png',
                    pressedFlag: _pressedPrev,
                    setPressed: (v) => setState(() => _pressedPrev = v),
                    onTap: () => _tapThen(widget.onPrev),
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
                    onTap: () => _tapThen(widget.onPauseToggle),
                  ),
                  const SizedBox(width: _gap),
                  _buildButton(
                    normal: 'assets/images/ui/controller/btn_next.png',
                    pressed: 'assets/images/ui/controller/btn_next_pressed.png',
                    pressedFlag: _pressedNext,
                    setPressed: (v) => setState(() => _pressedNext = v),
                    onTap: () => _tapThen(widget.onNext),
                  ),
                  const SizedBox(width: _gap),
                  _buildButton(
                    normal: 'assets/images/ui/controller/btn_exit.png',
                    pressed: 'assets/images/ui/controller/btn_exit_pressed.png',
                    pressedFlag: _pressedExit,
                    setPressed: (v) => setState(() => _pressedExit = v),
                    onTap: _tapThenExit, // ✅ 소리 듣고 잠깐 뒤 종료
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
