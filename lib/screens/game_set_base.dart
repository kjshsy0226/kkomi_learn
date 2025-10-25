import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/learn_fruit.dart'; // ✅ LearnFruit 사용

typedef FruitImagePathOf = String Function(LearnFruit f);

class GameSetScreen extends StatefulWidget {
  const GameSetScreen({
    super.key,
    required this.title,
    required this.backgroundColor,
    required this.fruitList,
    required this.fruitImagePathOf,
    required this.standingVideoPath,
    required this.eatVideoPathOf,
    required this.onAllCleared,
    this.baseSize = const Size(1920, 1080),
    this.ringCenter = const Offset(640, 540),
    this.ringRadius = 360,
    this.itemSize = const Size(220, 220),
    this.entryDuration = const Duration(milliseconds: 900),
    this.entryStagger = const Duration(milliseconds: 120),
    this.bobAmplitude = 10,
    this.bobPeriod = const Duration(milliseconds: 2800),
  });

  final String title;
  final Color backgroundColor;

  final List<LearnFruit> fruitList; // ✅ 타입 변경
  final FruitImagePathOf fruitImagePathOf; // ✅ 타입 유지

  final String standingVideoPath;
  final String Function(LearnFruit f) eatVideoPathOf; // ✅ 시그니처 변경

  final VoidCallback onAllCleared;

  // layout/animation params ...
  final Size baseSize;
  final Offset ringCenter;
  final double ringRadius;
  final Size itemSize;
  final Duration entryDuration;
  final Duration entryStagger;
  final double bobAmplitude;
  final Duration bobPeriod;

  @override
  State<GameSetScreen> createState() => _GameSetScreenState();
}

class _GameSetScreenState extends State<GameSetScreen>
    with TickerProviderStateMixin {
  late final List<_FruitSlot> _slots;
  late final AnimationController _bobCtrl;

  VideoPlayerController? _video;
  StreamSubscription<void>? _videoEndSub;

  bool _isPlayingEat = false;
  int _clearedCount = 0;

  @override
  void initState() {
    super.initState();

    _slots = List.generate(widget.fruitList.length, (i) {
      final fruit = widget.fruitList[i];
      final angle = _angleForIndex(i);
      final target = _polarToOffset(
        widget.ringCenter,
        widget.ringRadius,
        angle,
      );
      final delay = widget.entryStagger * i;
      final ctrl = AnimationController(
        vsync: this,
        duration: widget.entryDuration,
      );

      final pos = Tween<Offset>(
        begin: widget.ringCenter,
        end: target,
      ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic));
      final opacity = Tween<double>(
        begin: 0,
        end: 1,
      ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic));

      return _FruitSlot(
        fruit: fruit,
        delay: delay,
        controller: ctrl,
        pos: pos,
        opacity: opacity,
        target: target,
      );
    });

    _bobCtrl = AnimationController(vsync: this, duration: widget.bobPeriod)
      ..repeat();
    _kickEntry();
    _playLoop(widget.standingVideoPath);
  }

  @override
  void dispose() {
    for (final s in _slots) {
      s.controller.dispose();
    }
    _bobCtrl.dispose();
    _disposeVideo();
    super.dispose();
  }

  Future<void> _playLoop(String assetPath) async {
    _disposeVideo();
    final c = VideoPlayerController.asset(assetPath);
    _video = c;
    await c.initialize();
    await c.setLooping(true);
    await c.play();
    if (mounted) setState(() {});
  }

  Future<void> _playOnce(String assetPath, VoidCallback onComplete) async {
    _disposeVideo();
    final c = VideoPlayerController.asset(assetPath);
    _video = c;
    await c.initialize();
    await c.setLooping(false);
    await c.play();
    if (mounted) setState(() {});
    _videoEndSub = c.position.asStream().listen((_) {
      if (!c.value.isInitialized) return;
      final dur = c.value.duration;
      final pos = c.value.position;
      if (dur.inMilliseconds > 0 &&
          pos.inMilliseconds >= dur.inMilliseconds - 50) {
        _videoEndSub?.cancel();
        _videoEndSub = null;
        onComplete();
      }
    });
  }

  void _disposeVideo() {
    _videoEndSub?.cancel();
    _videoEndSub = null;
    _video?.dispose();
    _video = null;
  }

  void _kickEntry() async {
    for (final s in _slots) {
      await Future.delayed(s.delay);
      if (!mounted) return;
      s.controller.forward();
    }
  }

  double _angleForIndex(int i) {
    const startDeg = -90.0; // 위에서 시작
    final step = 360.0 / widget.fruitList.length;
    return (startDeg + i * step) * math.pi / 180.0;
  }

  Offset _polarToOffset(Offset c, double r, double a) =>
      Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));

  double _bobYFor(int index) {
    final t = _bobCtrl.value * 2 * math.pi;
    final phase = index * .6;
    return math.sin(t + phase) * widget.bobAmplitude;
  }

  Future<void> _onTapFruit(int index) async {
    if (_isPlayingEat) return;
    final slot = _slots[index];
    if (slot.hidden) return;

    _isPlayingEat = true;
    final eatPath = widget.eatVideoPathOf(slot.fruit);
    await _playOnce(eatPath, () async {
      slot.hidden = true;
      _clearedCount++;
      final finished = _clearedCount >= _slots.length;
      if (!finished) {
        await _playLoop(widget.standingVideoPath);
      }
      setState(() {});
      _isPlayingEat = false;
      if (finished) widget.onAllCleared();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, child) {
        final scaleX = child.maxWidth / widget.baseSize.width;
        final scaleY = child.maxHeight / widget.baseSize.height;
        final s = math.min(scaleX, scaleY);

        return Scaffold(
          backgroundColor: widget.backgroundColor,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (_video != null && _video!.value.isInitialized)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _video!.value.size.width,
                    height: _video!.value.size.height,
                    child: VideoPlayer(_video!),
                  ),
                ),
              AnimatedBuilder(
                animation: _bobCtrl,
                builder: (context, child) => Transform.scale(
                  scale: s,
                  alignment: Alignment.topLeft,
                  child: Stack(
                    children: [
                      for (int i = 0; i < _slots.length; i++)
                        _buildFruitItem(i),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFruitItem(int index) {
    final slot = _slots[index];
    return AnimatedBuilder(
      animation: slot.controller,
      builder: (context, child) {
        if (slot.hidden) return const SizedBox.shrink();
        final p = slot.pos.value;
        final bobY = _bobYFor(index);
        return Positioned(
          left: p.dx - widget.itemSize.width / 2,
          top: p.dy - widget.itemSize.height / 2 + bobY,
          width: widget.itemSize.width,
          height: widget.itemSize.height,
          child: Opacity(
            opacity: slot.opacity.value,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onTapFruit(index),
              child: Image.asset(
                widget.fruitImagePathOf(slot.fruit),
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FruitSlot {
  _FruitSlot({
    required this.fruit,
    required this.delay,
    required this.controller,
    required this.pos,
    required this.opacity,
    required this.target,
  });

  final LearnFruit fruit; // ✅ 타입 변경
  final Duration delay;
  final AnimationController controller;
  final Animation<Offset> pos;
  final Animation<double> opacity;
  final Offset target;

  bool hidden = false;
}
