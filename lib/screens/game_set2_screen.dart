import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/global_sfx.dart'; // ✅ 전역 SFX
import '../models/learn_fruit.dart';
import '../widgets/game_controller_bar.dart';
import 'learn_set9_screen.dart';
import 'game_set3_screen.dart';

class GameSet2Screen extends StatefulWidget {
  const GameSet2Screen({super.key});

  @override
  State<GameSet2Screen> createState() => _GameSet2ScreenState();
}

class _GameSet2ScreenState extends State<GameSet2Screen>
    with TickerProviderStateMixin {
  static const double baseW = 1920;
  static const double baseH = 1080;
  static const double controllerTopPx = 35;
  static const double controllerRightPx = 40;

  static const Offset kEnterStartTopLeft = Offset(640, 540);

  final List<LearnFruit> _fruits = const [
    LearnFruit.apple,
    LearnFruit.napaCabbage,
    LearnFruit.onion,
    LearnFruit.cucumber,
    LearnFruit.tangerine,
    LearnFruit.spinach,
    LearnFruit.orientalMelon,
    LearnFruit.carrot,
    LearnFruit.banana,
    LearnFruit.peach,
  ];

  String _keyOf(LearnFruit f) => kLearnFruitMeta[f]!.key;
  String _pngOf(LearnFruit f) => 'assets/images/fruits/game/${_keyOf(f)}.png';
  String _eatOf(LearnFruit f) =>
      'assets/videos/reactions/game/set2/eat_${_keyOf(f)}.mp4';
  final String _standing =
      'assets/videos/reactions/game/set2/standing_loop.mp4';

  static const List<Offset> kSet2Slots = <Offset>[
    Offset(236.15, 124.80),
    Offset(583.45, 109.05),
    Offset(1021.40, 162.95),
    Offset(1139.45, 384.15),
    Offset(967.75, 835.50),
    Offset(603.95, 702.85),
    Offset(298.85, 798.20),
    Offset(201.25, 560.85),
    Offset(389.75, 421.55),
    Offset(880.90, 451.55),
  ];

  static const Map<LearnFruit, Size> kSet2FruitSizeBase = {
    LearnFruit.apple: Size(149, 146),
    LearnFruit.banana: Size(199, 200),
    LearnFruit.carrot: Size(132, 193),
    LearnFruit.cucumber: Size(199, 347),
    LearnFruit.napaCabbage: Size(264, 282),
    LearnFruit.onion: Size(159, 193),
    LearnFruit.orientalMelon: Size(158, 181),
    LearnFruit.peach: Size(161, 170),
    LearnFruit.spinach: Size(197, 245),
    LearnFruit.tangerine: Size(185, 144),
  };

  late final List<bool> _eaten;
  final List<int> _history = [];
  int? _playingIndex;
  bool _paused = false;

  late final VideoPlayerController _standingCtrl;
  VideoPlayerController? _eatCtrl;

  late final AnimationController _enterCtrl;
  late final AnimationController _bobCtrl;

  @override
  void initState() {
    super.initState();

    assert(kSet2Slots.length == _fruits.length);

    _eaten = List<bool>.filled(_fruits.length, false);

    _standingCtrl = VideoPlayerController.asset(_standing)
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        _standingCtrl.play();
        setState(() {});
      });

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _bobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _eatCtrl?.removeListener(_onEatTick);
    _eatCtrl?.dispose();
    _standingCtrl.dispose();
    _enterCtrl.dispose();
    _bobCtrl.dispose();
    super.dispose();
  }

  bool get _allCleared => _eaten.every((e) => e);

  void _togglePause() {
    if (_playingIndex != null &&
        _eatCtrl != null &&
        _eatCtrl!.value.isInitialized) {
      if (_eatCtrl!.value.isPlaying) {
        _eatCtrl!.pause();
        _standingCtrl.pause();
        _bobCtrl.stop(canceled: false);
        setState(() => _paused = true);
      } else {
        _eatCtrl!.play();
        if (!_standingCtrl.value.isPlaying) _standingCtrl.play();
        if (!_bobCtrl.isAnimating) _bobCtrl.repeat();
        setState(() => _paused = false);
      }
    } else {
      if (_standingCtrl.value.isInitialized) {
        if (_standingCtrl.value.isPlaying) {
          _standingCtrl.pause();
          _bobCtrl.stop(canceled: false);
          setState(() => _paused = true);
        } else {
          _standingCtrl.play();
          if (!_bobCtrl.isAnimating) _bobCtrl.repeat();
          setState(() => _paused = false);
        }
      }
    }
  }

  void _onEatTick() {
    final v = _eatCtrl!.value;
    if (v.hasError) return;
    if (v.isInitialized && !v.isPlaying && v.position >= v.duration) {
      _finishEat();
    }
  }

  Future<void> _playEatByIndex(int idx) async {
    if (_playingIndex != null) return;
    if (_eaten[idx]) return;

    setState(() => _playingIndex = idx);

    _eatCtrl?.removeListener(_onEatTick);
    await _eatCtrl?.dispose();

    _eatCtrl = VideoPlayerController.asset(_eatOf(_fruits[idx]))
      ..setLooping(false);

    await _eatCtrl!.initialize();
    if (!mounted) return;

    _eatCtrl!.addListener(_onEatTick);
    await _eatCtrl!.play();
    setState(() => _paused = false);
  }

  Future<void> _finishEat() async {
    setState(() {
      _eatCtrl?.removeListener(_onEatTick);
      _eatCtrl?.dispose();
      _eatCtrl = null;

      final idx = _playingIndex;
      _playingIndex = null;

      if (idx != null && !_eaten[idx]) {
        _eaten[idx] = true;
        _history.add(idx);
      }
    });

    if (_allCleared) {
      final result = await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (c, a, b) => const GameSet3Screen(),
          transitionsBuilder: (c, a, b, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
      if (!mounted) return;
      if (result is Map && result['popOne'] == true) {
        if (_history.isNotEmpty) {
          final lastIdx = _history.removeLast();
          setState(() => _eaten[lastIdx] = false);
        }
      }
    }
  }

  Future<void> _skipOrFinishCurrentEat() async {
    if (_playingIndex == null || _eatCtrl == null) return;
    await _finishEat();
  }

  void _playRandomRemaining() {
    final remainingIdx = [
      for (int i = 0; i < _eaten.length; i++)
        if (!_eaten[i]) i,
    ];
    if (remainingIdx.isEmpty) return;
    final idx = remainingIdx[Random().nextInt(remainingIdx.length)];
    _playEatByIndex(idx);
  }

  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _goPrev() {
    if (_playingIndex != null) {
      setState(() {
        _eatCtrl?.removeListener(_onEatTick);
        _eatCtrl?.dispose();
        _eatCtrl = null;
        _playingIndex = null;
      });
    }

    if (_history.isEmpty) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (c, a, b) => const LearnSet9Screen(),
          transitionsBuilder: (c, a, b, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
      return;
    }

    final lastIdx = _history.removeLast();
    setState(() => _eaten[lastIdx] = false);
  }

  Future<void> _goNext() async {
    if (_allCleared) {
      final result = await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (c, a, b) => const GameSet3Screen(),
          transitionsBuilder: (c, a, b, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
      if (!mounted) return;
      if (result is Map && result['popOne'] == true) {
        if (_history.isNotEmpty) {
          final lastIdx = _history.removeLast();
          setState(() => _eaten[lastIdx] = false);
        }
      }
      return;
    }

    if (_playingIndex != null) {
      await _finishEat();
      if (mounted && !_allCleared && _playingIndex == null) {
        _playRandomRemaining();
      }
      return;
    }
    _playRandomRemaining();
  }

  double _calcScale(Size screen) =>
      min(screen.width / baseW, screen.height / baseH);

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final scale = _calcScale(screen);
    final canvasW = baseW * scale;
    final canvasH = baseH * scale;
    final leftPad = (screen.width - canvasW) / 2;
    final topPad = (screen.height - canvasH) / 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF6E691),
      body: Stack(
        children: [
          Positioned(
            left: leftPad,
            top: topPad,
            width: canvasW,
            height: canvasH,
            child: Stack(
              children: [
                if (_standingCtrl.value.isInitialized)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: true,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _standingCtrl.value.size.width,
                          height: _standingCtrl.value.size.height,
                          child: VideoPlayer(_standingCtrl),
                        ),
                      ),
                    ),
                  )
                else
                  const Positioned.fill(
                    child: Center(child: CircularProgressIndicator()),
                  ),

                if (_playingIndex != null &&
                    _eatCtrl != null &&
                    _eatCtrl!.value.isInitialized)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: true,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _eatCtrl!.value.size.width,
                          height: _eatCtrl!.value.size.height,
                          child: VideoPlayer(_eatCtrl!),
                        ),
                      ),
                    ),
                  ),

                AbsorbPointer(
                  absorbing: _playingIndex != null,
                  child: Stack(
                    children: _buildFixedFruits(scale, leftPad, topPad),
                  ),
                ),

                if (_playingIndex != null)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        GlobalSfx.instance.play('tap'); // ✅ 전역 효과음
                        await Future.delayed(const Duration(milliseconds: 150));
                        await _skipOrFinishCurrentEat();
                      },
                    ),
                  ),

                Positioned(
                  top: controllerTopPx * scale,
                  right: controllerRightPx * scale,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topRight,
                    child: GameControllerBar(
                      isPaused: _paused,
                      onHome: _goHome,
                      onPrev: _goPrev,
                      onNext: _goNext,
                      onPauseToggle: _togglePause,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFixedFruits(double scale, double leftPad, double topPad) {
    double lerpD(double a, double b, double t) => a + (b - a) * t;

    Animation<double> staggerAnimFor(
      int i, {
      double span = 0.55,
      double gap = 0.06,
    }) {
      final start = (i * gap).clamp(0.0, 1.0);
      final end = (start + span).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _enterCtrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    }

    final widgets = <Widget>[];

    for (int i = 0; i < _fruits.length; i++) {
      if (_eaten[i]) continue;

      final fruit = _fruits[i];
      final targetBase = kSet2Slots[i];
      final baseSize = kSet2FruitSizeBase[fruit] ?? const Size(160, 160);
      final itemW = baseSize.width * scale;
      final itemH = baseSize.height * scale;

      final enterAnim = staggerAnimFor(i);
      final opacityAnim = CurvedAnimation(
        parent: _enterCtrl,
        curve: Interval((i * 0.06).clamp(0.0, 1.0), 1.0, curve: Curves.easeIn),
      );

      final ampPx = 6.0 * scale;
      final phase = i * pi * 0.8;

      widgets.add(
        AnimatedBuilder(
          animation: Listenable.merge([_enterCtrl, _bobCtrl]),
          builder: (context, _) {
            final t = enterAnim.value;
            final xBase = lerpD(kEnterStartTopLeft.dx, targetBase.dx, t);
            final yBase = lerpD(kEnterStartTopLeft.dy, targetBase.dy, t);
            final theta = (_bobCtrl.value * 2 * pi) + phase;
            final dy = sin(theta) * ampPx;

            final left = leftPad + xBase * scale;
            final top = topPad + yBase * scale + dy;

            return Positioned(
              left: left,
              top: top,
              width: itemW,
              height: itemH,
              child: Opacity(
                opacity: opacityAnim.value,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    GlobalSfx.instance.play('tap'); // ✅ 전역 효과음
                    await Future.delayed(const Duration(milliseconds: 150));
                    _playEatByIndex(i);
                  },
                  child: Image.asset(
                    _pngOf(fruit),
                    fit: BoxFit.fill,
                    errorBuilder: (context, error, stack) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return widgets;
  }
}
