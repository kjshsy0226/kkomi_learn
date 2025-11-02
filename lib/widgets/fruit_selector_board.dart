// lib/widgets/fruit_selector_board.dart
import 'dart:async'; // unawaited
import 'dart:math';
import 'package:flutter/material.dart';

import '../models/learn_fruit.dart';
import '../core/global_sfx.dart'; // ✅ 전역 SFX

class FruitSelectorBoard extends StatefulWidget {
  const FruitSelectorBoard({
    super.key,
    required this.fruits,
    required this.onFruitPicked,
    required this.topLeftPositionsBase, // 1920×1080 기준 Top-Left(px)
    this.itemSizesBase, // 1920×1080 기준 항목별 크기(px)
    this.backgroundPath = 'assets/images/selector/background.png',
    this.highlightLogicalSize = const Size(222, 141), // 기본 히트박스 크기(이름만 유지)
    this.initialIndex = 0,
    this.showHitboxes = false, // 🔧 디버그용 가시화
  });

  final List<LearnFruit> fruits;
  final void Function(int index) onFruitPicked;

  final List<Offset> topLeftPositionsBase;
  final List<Size>? itemSizesBase;

  final String backgroundPath;
  final Size highlightLogicalSize;

  final int initialIndex;

  /// 히트박스 시각화 (디버그용)
  final bool showHitboxes;

  @override
  State<FruitSelectorBoard> createState() => _FruitSelectorBoardState();
}

class _FruitSelectorBoardState extends State<FruitSelectorBoard> {
  // 중복 탭 방지용
  bool _busy = false;

  /// 전역 SFX 사용: 소리 재생 → 짧게 대기 → 콜백 실행
  Future<void> _tapSoundThenPick(int index) async {
    if (_busy) return;
    _busy = true;

    GlobalSfx.instance.play('tap');
    await Future.delayed(const Duration(milliseconds: 150));

    widget.onFruitPicked(index);

    await Future.delayed(const Duration(milliseconds: 60));
    _busy = false;
  }

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
        // 배경
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

        // 히트박스(투명). 필요하면 showHitboxes=true로 박스 표시
        ...List.generate(widget.fruits.length, (i) {
          final itemSize =
              (widget.itemSizesBase != null && i < widget.itemSizesBase!.length)
              ? widget.itemSizesBase![i]
              : widget.highlightLogicalSize;

          final rect = rectFromTopLeftPx(
            baseTopLeftPx: widget.topLeftPositionsBase[i],
            baseSizePx: itemSize,
          );

          return Positioned.fromRect(
            rect: rect,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _tapSoundThenPick(i),
              child: widget.showHitboxes
                  ? Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.cyanAccent, width: 2),
                        color: Colors.cyanAccent.withAlpha(20),
                      ),
                      child: Text(
                        '#$i',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : const SizedBox.expand(),
            ),
          );
        }),
      ],
    );
  }
}
