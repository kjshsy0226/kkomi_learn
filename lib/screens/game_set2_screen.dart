// lib/screens/game_set2_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/bgm_tracks.dart'; // ✅ 전역 BGM 숏컷
import '../core/global_sfx.dart'; // ✅ 전역 SFX
import '../models/learn_fruit.dart';
import '../widgets/game_controller_bar.dart';
import 'game_set3_screen.dart';
import 'game_intro_screen.dart'; // ✅ Intro로 이동

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
  final List<int> _history = []; // 되돌리기용(게임2 내부)
  int? _playingIndex;
  bool _paused = false;

  late final VideoPlayerController _standingCtrl;
  VideoPlayerController? _eatCtrl;

  late final AnimationController _enterCtrl;
  late final AnimationController _bobCtrl;

  bool _finishing = false;
  bool _navigating = false;

  DateTime _lastNextTap = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _nextDebounceMs = 250;

  @override
  void initState() {
    super.initState();
    GlobalBgm.instance.ensureGame();

    assert(kSet2Slots.length == _fruits.length);
    _eaten = List<bool>.filled(_fruits.length, false);

    _standingCtrl = VideoPlayerController.asset(_standing)
      ..setLooping(true)
      ..initialize().then((_) async {
        if (!mounted) return;
        await _standingCtrl.setVolume(0.3);
        await _standingCtrl.play();
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
    // ❗ 세트3로 이어질 수 있으므로 여기선 stopGame() 안 함
    super.dispose();
  }

  bool get _allCleared => _eaten.every((e) => e);

  Future<void> _suspendMedia({bool pauseBgm = true}) async {
    try {
      _eatCtrl?.removeListener(_onEatTick);
      await _eatCtrl?.setVolume(0.0);
      await _eatCtrl?.pause();
    } catch (_) {}
    try {
      await _standingCtrl.setVolume(0.0);
      await _standingCtrl.pause();
    } catch (_) {}
    if (_bobCtrl.isAnimating) _bobCtrl.stop(canceled: false);
    if (pauseBgm) {
      await GlobalBgm.instance.pause();
    }
  }

  Future<void> _switchToStanding({bool play = true}) async {
    try {
      _eatCtrl?.removeListener(_onEatTick);
      await _eatCtrl?.setVolume(0.0);
      await _eatCtrl?.pause();
      await _eatCtrl?.dispose();
      _eatCtrl = null;
      _playingIndex = null;

      await _standingCtrl.seekTo(Duration.zero);
      await _standingCtrl.setLooping(true);
      await _standingCtrl.setVolume(play ? 0.3 : 0.0);
      if (play && !_standingCtrl.value.isPlaying) {
        await _standingCtrl.play();
      }
    } catch (_) {}
  }

  void _togglePause() async {
    if (_playingIndex != null &&
        _eatCtrl != null &&
        _eatCtrl!.value.isInitialized) {
      if (_eatCtrl!.value.isPlaying) {
        _eatCtrl!.pause();
        _standingCtrl.pause();
        _bobCtrl.stop(canceled: false);
        await GlobalBgm.instance.pause();
        setState(() => _paused = true);
      } else {
        _eatCtrl!.play();
        if (!_standingCtrl.value.isPlaying) _standingCtrl.play();
        if (!_bobCtrl.isAnimating) _bobCtrl.repeat();
        await GlobalBgm.instance.resume();
        setState(() => _paused = false);
      }
    } else {
      if (_standingCtrl.value.isInitialized) {
        if (_standingCtrl.value.isPlaying) {
          _standingCtrl.pause();
          _bobCtrl.stop(canceled: false);
          await GlobalBgm.instance.pause();
          setState(() => _paused = true);
        } else {
          _standingCtrl.play();
          if (!_bobCtrl.isAnimating) _bobCtrl.repeat();
          await GlobalBgm.instance.resume();
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
    if (_navigating || _finishing) return;
    if (_playingIndex != null) return;
    if (_eaten[idx]) return;

    setState(() {
      _playingIndex = idx;
      _eaten[idx] = true;
      _history.add(idx);
    });

    _eatCtrl?.removeListener(_onEatTick);
    await _eatCtrl?.dispose();

    _eatCtrl = VideoPlayerController.asset(_eatOf(_fruits[idx]))
      ..setLooping(false);

    await _eatCtrl!.initialize();
    if (!mounted) return;

    await _eatCtrl!.setVolume(0.3);
    _eatCtrl!.addListener(_onEatTick);
    await _eatCtrl!.play();
    setState(() => _paused = false);
  }

  Future<void> _finishEat() async {
    if (_finishing) return;
    _finishing = true;

    try {
      setState(() {
        _eatCtrl?.removeListener(_onEatTick);
        _eatCtrl?.dispose();
        _eatCtrl = null;
        _playingIndex = null;
      });
    } finally {
      _finishing = false;
    }

    _maybeNavigateIfCleared();
  }

  // 스킵 없앰(사용 안 함). 투명막으로 막기만 함.

  void _playRandomRemaining() {
    if (_playingIndex != null) return;
    final remainingIdx = [
      for (int i = 0; i < _eaten.length; i++)
        if (!_eaten[i]) i,
    ];
    if (remainingIdx.isEmpty) return;
    final idx = remainingIdx[Random().nextInt(remainingIdx.length)];
    _playEatByIndex(idx);
  }

  Future<void> _navigateToSet3Once() async {
    if (_navigating || !mounted) return;
    _navigating = true;
    try {
      await _switchToStanding(play: false);
      await _suspendMedia(pauseBgm: false); // 🔈 세트3로 갈 땐 BGM 유지
      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (c, a, b) => const GameSet3Screen(),
          transitionsBuilder: (c, a, b, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } finally {
      _navigating = false;
    }
  }

  void _maybeNavigateIfCleared() {
    if (_allCleared) {
      _navigateToSet3Once();
    }
  }

  Future<void> _goHome() async {
    if (_navigating) return;
    await _switchToStanding(play: false);
    await _suspendMedia(pauseBgm: true);
    GlobalBgm.instance.stopGame(); // 홈 이동 시 종료
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _goPrev() async {
    if (_navigating) return;

    // 요구: 게임2의 이전 버튼은 무조건 Intro로
    if (_playingIndex != null) {
      setState(() {
        _eatCtrl?.removeListener(_onEatTick);
        _eatCtrl?.dispose();
        _eatCtrl = null;
        _playingIndex = null;
      });
    }

    await _switchToStanding(play: false);
    await _suspendMedia(pauseBgm: true);
    GlobalBgm.instance.stopGame(); // 게임 흐름 종료
    if (!mounted) return;

    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (c, a, b) => const GameIntroScreen(),
        transitionsBuilder: (c, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _goNext() async {
    final now = DateTime.now();
    if (now.difference(_lastNextTap).inMilliseconds < _nextDebounceMs) return;
    _lastNextTap = now;

    if (_navigating) return;

    if (_allCleared) {
      _maybeNavigateIfCleared();
      return;
    }

    if (_playingIndex != null) {
      await _finishEat();
      if (!mounted) return;
      if (!_allCleared) {
        _playRandomRemaining();
      } else {
        _maybeNavigateIfCleared();
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

                // 먹는 중엔 전면 투명막으로 모든 입력 차단 (스킵 X)
                if (_playingIndex != null)
                  const Positioned.fill(
                    child: ModalBarrier(
                      color: Colors.transparent,
                      dismissible: false,
                    ),
                  ),

                AbsorbPointer(
                  absorbing: _playingIndex != null,
                  child: Stack(
                    children: _buildFixedFruits(scale, leftPad, topPad),
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
                      onPrev: _goPrev, // ✅ Intro로 이동
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

      final enterAnim = staggerAnimFor(i);
      final opacityAnim = CurvedAnimation(
        parent: _enterCtrl,
        curve: Interval((i * 0.06).clamp(0.0, 1.0), 1.0, curve: Curves.easeIn),
      );

      final ampPx = 6.0 * scale;
      final phase = i * pi * 0.8;

      widgets.add(
        KeyedSubtree(
          key: ValueKey('${_keyOf(fruit)}-$i'),
          child: AnimatedBuilder(
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
                key: ValueKey('pos-${_keyOf(fruit)}-$i'),
                left: left,
                top: top,
                width: baseSize.width * scale,
                height: baseSize.height * scale,
                child: Opacity(
                  opacity: opacityAnim.value,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      GlobalSfx.instance.play('tap');
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
        ),
      );
    }

    return widgets;
  }
}
