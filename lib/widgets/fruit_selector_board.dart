// lib/widgets/fruit_selector_board.dart
import 'dart:async'; // unawaited
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/learn_fruit.dart';

class FruitSelectorBoard extends StatefulWidget {
  const FruitSelectorBoard({
    super.key,
    required this.fruits,
    required this.onFruitPicked,
    required this.topLeftPositionsBase, // 1920×1080 기준 Top-Left(px)
    this.itemSizesBase, // 1920×1080 기준 항목별 크기(px)
    this.backgroundPath = 'assets/images/selector/background.png',
    this.highlightLogicalSize = const Size(222, 141),
    this.initialIndex = 0,
  });

  final List<LearnFruit> fruits;
  final void Function(int index) onFruitPicked;

  final List<Offset> topLeftPositionsBase;
  final List<Size>? itemSizesBase;

  final String backgroundPath;
  final Size highlightLogicalSize;

  final int initialIndex;

  @override
  State<FruitSelectorBoard> createState() => _FruitSelectorBoardState();
}

class _FruitSelectorBoardState extends State<FruitSelectorBoard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  static const _pulseDur = Duration(milliseconds: 1200);

  // 중복 탭 방지용
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: _pulseDur)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// 가장 안정적인 방식:
  /// - 매 탭마다 임시 AudioPlayer 생성 → 즉시 play()
  /// - 150ms 정도 짧게 기다렸다가 화면 전환(체감상 "소리 후 이동")
  /// - 500ms 뒤 플레이어 정리(dispose)
  Future<void> _tapSoundThenPick(int index) async {
    if (_busy) return;
    _busy = true;

    final p = AudioPlayer()
      ..setPlayerMode(PlayerMode.lowLatency)
      ..setReleaseMode(ReleaseMode.stop)
      ..setVolume(0.9);

    // 사운드 재생(대기하지 않음)
    unawaited(p.play(AssetSource('audio/sfx/btn_tap.mp3')));

    // 짧은 딜레이 후 실제 선택 콜백 실행
    await Future.delayed(const Duration(milliseconds: 150));
    widget.onFruitPicked(index);

    // 플레이어 정리 (느슨하게)
    unawaited(
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          await p.dispose();
        } catch (_) {}
      }),
    );

    // 더블탭 방지를 위해 살짝 뒤에 락 해제
    await Future.delayed(const Duration(milliseconds: 60));
    _busy = false;
  }

  String _hlPath(LearnFruit f) =>
      'assets/images/selector/highlight_${kLearnFruitMeta[f]!.key}.png';

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    const baseW = 1920.0;
    const baseH = 1080.0;
    final scale = min(sz.width / baseW, sz.height / baseH);
    final canvasW = baseW * scale;
    final canvasH = baseH * scale;
    final leftPad = (sz.width - canvasW) / 2;
    final topPad = (sz.height - canvasH) / 2;

    Rect rectFromTopLeftPx({
      required Offset baseTopLeftPx,
      required Size baseSizePx,
    }) {
      final left = leftPad + baseTopLeftPx.dx * scale;
      final top = topPad + baseTopLeftPx.dy * scale;
      final w = baseSizePx.width * scale;
      final h = baseSizePx.height * scale;
      return Rect.fromLTWH(left, top, w, h);
    }

    assert(
      widget.topLeftPositionsBase.length == widget.fruits.length,
      'topLeftPositionsBase 길이는 fruits 길이와 동일해야 합니다.',
    );
    if (widget.itemSizesBase != null) {
      assert(
        widget.itemSizesBase!.length == widget.fruits.length,
        'itemSizesBase 길이는 fruits 길이와 동일해야 합니다.',
      );
    }

    return Stack(
      children: [
        Positioned(
          left: leftPad,
          top: topPad,
          width: canvasW,
          height: canvasH,
          child: Image.asset(
            widget.backgroundPath,
            fit: BoxFit.fill,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          ),
        ),
        ...List.generate(widget.fruits.length, (i) {
          final fruit = widget.fruits[i];
          final itemSize =
              (widget.itemSizesBase != null && i < widget.itemSizesBase!.length)
              ? widget.itemSizesBase![i]
              : widget.highlightLogicalSize;

          final rect = rectFromTopLeftPx(
            baseTopLeftPx: widget.topLeftPositionsBase[i],
            baseSizePx: itemSize,
          );

          return AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = (_pulse.value + i * 0.18) % 1.0;
              final alpha = 0.35 + 0.65 * (0.5 - 0.5 * cos(2 * pi * t));
              return Positioned.fromRect(
                rect: rect,
                child: Opacity(
                  opacity: alpha,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _tapSoundThenPick(i), // ✅ 소리 → 짧은 대기 → 선택
                    child: Image.asset(_hlPath(fruit), fit: BoxFit.fill),
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }
}
