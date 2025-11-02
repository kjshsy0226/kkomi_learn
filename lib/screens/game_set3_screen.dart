// lib/screens/game_set3_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/bgm_tracks.dart'; // ✅ 전역 BGM 숏컷
import '../core/global_sfx.dart'; // ✅ 전역 효과음 매니저
import '../models/learn_fruit.dart';
import '../widgets/game_controller_bar.dart';
import 'game_set2_screen.dart';
import 'quiz_result_screen.dart';

class GameSet3Screen extends StatefulWidget {
  const GameSet3Screen({super.key});

  @override
  State<GameSet3Screen> createState() => _GameSet3ScreenState();
}

class _GameSet3ScreenState extends State<GameSet3Screen>
    with TickerProviderStateMixin {
  static const double baseW = 1920;
  static const double baseH = 1080;
  static const double controllerTopPx = 35;
  static const double controllerRightPx = 40;

  static const Offset kEnterStartTopLeft = Offset(640, 540);

  final List<LearnFruit> _fruits = const [
    LearnFruit.eggplant,
    LearnFruit.paprika,
    LearnFruit.watermelon,
    LearnFruit.tomato,
    LearnFruit.pumpkin,
    LearnFruit.kiwi,
    LearnFruit.grape,
    LearnFruit.pineapple,
    LearnFruit.strawberry,
    LearnFruit.radish,
  ];

  String _keyOf(LearnFruit f) => kLearnFruitMeta[f]!.key;
  String _pngOf(LearnFruit f) => 'assets/images/fruits/game/${_keyOf(f)}.png';
  String _eatOf(LearnFruit f) =>
      'assets/videos/reactions/game/set3/eat_${_keyOf(f)}.mp4';
  final String _standing =
      'assets/videos/reactions/game/set3/standing_loop.mp4';

  static const List<Offset> kSet3Slots = <Offset>[
    Offset(41.80, 372.75),
    Offset(291.50, 103.10),
    Offset(559.35, 81.25),
    Offset(973.95, 118.00),
    Offset(1017.40, 389.50),
    Offset(983.45, 799.60),
    Offset(680.45, 824.65),
    Offset(222.75, 717.50),
    Offset(371.90, 477.85),
    Offset(669.05, 457.75),
  ];

  static const Map<LearnFruit, Size> kSet3FruitSizeBase = {
    LearnFruit.eggplant: Size(105, 297),
    LearnFruit.grape: Size(161, 218),
    LearnFruit.kiwi: Size(142, 134),
    LearnFruit.paprika: Size(170, 190),
    LearnFruit.pineapple: Size(208, 279),
    LearnFruit.pumpkin: Size(269, 256),
    LearnFruit.radish: Size(246, 293),
    LearnFruit.strawberry: Size(124, 105),
    LearnFruit.tomato: Size(173, 144),
    LearnFruit.watermelon: Size(280, 309),
  };

  late final List<bool> _eaten;
  final List<int> _history = [];
  int? _playingIndex;
  bool _paused = false;

  late final VideoPlayerController _standingCtrl;
  VideoPlayerController? _eatCtrl;
  late final AnimationController _enterCtrl;
  late final AnimationController _bobCtrl;

  bool _finishing = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();

    // ✅ 게임 BGM 보장 (중복 호출 안전)
    GlobalBgm.instance.ensureGame();

    assert(kSet3Slots.length == _fruits.length);
    _eaten = List<bool>.filled(_fruits.length, false);

    _standingCtrl = VideoPlayerController.asset(_standing)
      ..setLooping(true)
      ..initialize().then((_) async {
        if (!mounted) return;
        await _standingCtrl.setVolume(1.0);
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
    GlobalBgm.instance.stopGame();
    super.dispose();
  }

  bool get _allCleared => _eaten.every((e) => e);

  Future<void> _suspendMedia() async {
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
    // ✅ BGM도 함께 일시정지
    await GlobalBgm.instance.pause();
  }

  Future<void> _switchToStanding({bool play = true}) async {
    try {
      _eatCtrl?.removeListener(_onEatTick);
      await _eatCtrl?.pause();
      await _eatCtrl?.dispose();
      _eatCtrl = null;
      _playingIndex = null;

      await _standingCtrl.seekTo(Duration.zero);
      await _standingCtrl.setLooping(true);
      await _standingCtrl.setVolume(play ? 1.0 : 0.0);
      if (play && !_standingCtrl.value.isPlaying) {
        await _standingCtrl.play();
      }
    } catch (_) {}
  }

  Future<void> _resumeMediaIfNeeded() async {
    if (!mounted) return;
    try {
      await _standingCtrl.seekTo(Duration.zero);
      await _standingCtrl.setVolume(1.0);
      if (!_paused && !_standingCtrl.value.isPlaying) {
        await _standingCtrl.play();
      }
      if (!_bobCtrl.isAnimating) _bobCtrl.repeat();
      // ✅ BGM도 함께 재개
      if (!_paused) await GlobalBgm.instance.resume();
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

    await _eatCtrl!.setVolume(1.0);
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

    if (_allCleared) {
      await _navigateToResultOnce();
    }
  }

  Future<void> _skipOrFinishCurrentEat() async {
    if (_navigating) return;
    if (_playingIndex == null || _eatCtrl == null) return;
    await _finishEat();
  }

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

  Future<void> _navigateToResultOnce() async {
    if (_navigating || !mounted) return;
    _navigating = true;

    final nav = Navigator.of(context);

    try {
      await _switchToStanding(play: false);
      await _suspendMedia();
      if (!mounted) return;

      await nav.pushReplacement(
        PageRouteBuilder(
          pageBuilder: (c, a, b) => const QuizResultScreen(),
          transitionsBuilder: (c, a, b, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );

      if (!mounted) return;
      await _resumeMediaIfNeeded();
    } finally {
      _navigating = false;
    }
  }

  Future<void> _goPrev() async {
    if (_navigating) return;

    if (_playingIndex != null) {
      setState(() {
        _eatCtrl?.removeListener(_onEatTick);
        _eatCtrl?.dispose();
        _eatCtrl = null;
        _playingIndex = null;
      });
    }

    if (_history.isNotEmpty) {
      final lastIdx = _history.removeLast();
      setState(() => _eaten[lastIdx] = false);
      return;
    }

    final nav = Navigator.of(context);

    await _switchToStanding(play: false);
    await _suspendMedia();
    if (!mounted) return;

    // ✅ 세트2로 돌아가도 게임 흐름이면 BGM을 유지하고 싶으면 stopGame() 생략
    // (학습/홈으로 빠질 때만 정리)
    if (nav.canPop()) {
      nav.pop({'popOne': true});
    } else {
      await nav.pushReplacement(
        PageRouteBuilder(
          pageBuilder: (c, a, b) => const GameSet2Screen(),
          transitionsBuilder: (c, a, b, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  Future<void> _goNext() async {
    if (_navigating) return;

    if (_allCleared) {
      await _navigateToResultOnce();
      return;
    }

    if (_playingIndex != null) {
      await _finishEat();
      if (!mounted) return;
      if (!_allCleared) {
        _playRandomRemaining();
      } else {
        await _navigateToResultOnce();
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
      backgroundColor: const Color(0xFF8EE19A),
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
                        GlobalSfx.instance.play('tap');
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
                      onHome: () async {
                        if (_navigating) return;

                        final nav = Navigator.of(context);

                        await _switchToStanding(play: false);
                        await _suspendMedia();
                        // ✅ 홈으로 나갈 땐 BGM 정리
                        GlobalBgm.instance.stopGame();
                        if (!mounted) return;

                        nav.pushNamedAndRemoveUntil('/', (r) => false);
                      },
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
      final targetBase = kSet3Slots[i];
      final baseSize = kSet3FruitSizeBase[fruit] ?? const Size(160, 160);
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
                width: itemW,
                height: itemH,
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

// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:video_player/video_player.dart';

// import '../core/global_sfx.dart'; // ✅ 전역 효과음 매니저
// import '../models/learn_fruit.dart';
// import '../widgets/game_controller_bar.dart';
// import 'game_set2_screen.dart';
// import 'quiz_result_screen.dart';

// class GameSet3Screen extends StatefulWidget {
//   const GameSet3Screen({super.key});

//   @override
//   State<GameSet3Screen> createState() => _GameSet3ScreenState();
// }

// class _GameSet3ScreenState extends State<GameSet3Screen>
//     with TickerProviderStateMixin {
//   // ── 기준 캔버스 ────────────────────────────────────────────────────────────
//   static const double baseW = 1920;
//   static const double baseH = 1080;
//   static const double controllerTopPx = 35;
//   static const double controllerRightPx = 40;

//   // 입장 애니메이션 시작 좌표(1920×1080 기준)
//   static const Offset kEnterStartTopLeft = Offset(640, 540);

//   // ── 세트 구성(고정 순서) ──────────────────────────────────────────────
//   final List<LearnFruit> _fruits = const [
//     LearnFruit.eggplant,
//     LearnFruit.paprika,
//     LearnFruit.watermelon,
//     LearnFruit.tomato,
//     LearnFruit.pumpkin,
//     LearnFruit.kiwi,
//     LearnFruit.grape,
//     LearnFruit.pineapple,
//     LearnFruit.strawberry,
//     LearnFruit.radish,
//   ];

//   String _keyOf(LearnFruit f) => kLearnFruitMeta[f]!.key;
//   String _pngOf(LearnFruit f) => 'assets/images/fruits/game/${_keyOf(f)}.png';
//   String _eatOf(LearnFruit f) =>
//       'assets/videos/reactions/game/set3/eat_${_keyOf(f)}.mp4';
//   final String _standing =
//       'assets/videos/reactions/game/set3/standing_loop.mp4';

//   static const List<Offset> kSet3Slots = <Offset>[
//     Offset(41.80, 372.75),
//     Offset(291.50, 103.10),
//     Offset(559.35, 81.25),
//     Offset(973.95, 118.00),
//     Offset(1017.40, 389.50),
//     Offset(983.45, 799.60),
//     Offset(680.45, 824.65),
//     Offset(222.75, 717.50),
//     Offset(371.90, 477.85),
//     Offset(669.05, 457.75),
//   ];

//   static const Map<LearnFruit, Size> kSet3FruitSizeBase = {
//     LearnFruit.eggplant: Size(105, 297),
//     LearnFruit.grape: Size(161, 218),
//     LearnFruit.kiwi: Size(142, 134),
//     LearnFruit.paprika: Size(170, 190),
//     LearnFruit.pineapple: Size(208, 279),
//     LearnFruit.pumpkin: Size(269, 256),
//     LearnFruit.radish: Size(246, 293),
//     LearnFruit.strawberry: Size(124, 105),
//     LearnFruit.tomato: Size(173, 144),
//     LearnFruit.watermelon: Size(280, 309),
//   };

//   // ── 상태 ────────────────────────────────────────────────────────────────
//   late final List<bool> _eaten;
//   final List<int> _history = [];
//   int? _playingIndex;
//   bool _paused = false;

//   late final VideoPlayerController _standingCtrl;
//   VideoPlayerController? _eatCtrl;
//   late final AnimationController _enterCtrl;
//   late final AnimationController _bobCtrl;

//   bool _finishing = false; // ✅ 먹기 종료 중복 가드
//   bool _navigating = false; // ✅ 화면 전환 중복 가드

//   @override
//   void initState() {
//     super.initState();

//     assert(kSet3Slots.length == _fruits.length);
//     _eaten = List<bool>.filled(_fruits.length, false);

//     _standingCtrl = VideoPlayerController.asset(_standing)
//       ..setLooping(true)
//       ..initialize().then((_) async {
//         if (!mounted) return;
//         await _standingCtrl.setVolume(1.0);
//         await _standingCtrl.play();
//         setState(() {});
//       });

//     _enterCtrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 900),
//     )..forward();

//     _bobCtrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 2200),
//     )..repeat();
//   }

//   @override
//   void dispose() {
//     _eatCtrl?.removeListener(_onEatTick);
//     _eatCtrl?.dispose();
//     _standingCtrl.dispose();
//     _enterCtrl.dispose();
//     _bobCtrl.dispose();
//     super.dispose();
//   }

//   bool get _allCleared => _eaten.every((e) => e);

//   // ── 미디어 제어 ─────────────────────────────────────────────────────────
//   Future<void> _suspendMedia() async {
//     try {
//       _eatCtrl?.removeListener(_onEatTick);
//       await _eatCtrl?.setVolume(0.0);
//       await _eatCtrl?.pause();
//     } catch (_) {}
//     try {
//       await _standingCtrl.setVolume(0.0);
//       await _standingCtrl.pause();
//     } catch (_) {}
//     if (_bobCtrl.isAnimating) _bobCtrl.stop(canceled: false);
//   }

//   // 스탠딩으로 확실히 전환(먹기 레이어 제거, standing 0초로)
//   Future<void> _switchToStanding({bool play = true}) async {
//     try {
//       _eatCtrl?.removeListener(_onEatTick);
//       await _eatCtrl?.setVolume(0.0);
//       await _eatCtrl?.pause();
//       await _eatCtrl?.dispose();
//       _eatCtrl = null;
//       _playingIndex = null;

//       await _standingCtrl.seekTo(Duration.zero);
//       await _standingCtrl.setLooping(true);
//       await _standingCtrl.setVolume(play ? 1.0 : 0.0);
//       if (play && !_standingCtrl.value.isPlaying) {
//         await _standingCtrl.play();
//       }
//     } catch (_) {}
//   }

//   // 복귀 시 standing을 0초로 되감고 재생 보장
//   Future<void> _resumeMediaIfNeeded() async {
//     if (!mounted) return;
//     try {
//       await _standingCtrl.seekTo(Duration.zero);
//       await _standingCtrl.setVolume(1.0);
//       if (!_paused && !_standingCtrl.value.isPlaying) {
//         await _standingCtrl.play();
//       }
//       if (!_bobCtrl.isAnimating) _bobCtrl.repeat();
//     } catch (_) {}
//   }

//   // ── 재생/일시정지 ─────────────────────────────────────────────────────
//   void _togglePause() {
//     if (_playingIndex != null &&
//         _eatCtrl != null &&
//         _eatCtrl!.value.isInitialized) {
//       if (_eatCtrl!.value.isPlaying) {
//         _eatCtrl!.pause();
//         _standingCtrl.pause();
//         _bobCtrl.stop(canceled: false);
//         setState(() => _paused = true);
//       } else {
//         _eatCtrl!.play();
//         if (!_standingCtrl.value.isPlaying) _standingCtrl.play();
//         if (!_bobCtrl.isAnimating) _bobCtrl.repeat();
//         setState(() => _paused = false);
//       }
//     } else {
//       if (_standingCtrl.value.isInitialized) {
//         if (_standingCtrl.value.isPlaying) {
//           _standingCtrl.pause();
//           _bobCtrl.stop(canceled: false);
//           setState(() => _paused = true);
//         } else {
//           _standingCtrl.play();
//           if (!_bobCtrl.isAnimating) _bobCtrl.repeat();
//           setState(() => _paused = false);
//         }
//       }
//     }
//   }

//   // ── 먹기 영상 상태 콜백 ────────────────────────────────────────────────
//   void _onEatTick() {
//     final v = _eatCtrl!.value;
//     if (v.hasError) return;
//     if (v.isInitialized && !v.isPlaying && v.position >= v.duration) {
//       _finishEat(); // 정리만, 전환은 중앙에서
//     }
//   }

//   // ── 먹기 시작 ─────────────────────────────────────────────────────────
//   Future<void> _playEatByIndex(int idx) async {
//     if (_navigating || _finishing) return; // 전환/정리 중이면 무시
//     if (_playingIndex != null) return;
//     if (_eaten[idx]) return;

//     setState(() {
//       _playingIndex = idx;
//       _eaten[idx] = true; // 즉시 먹음 처리
//       _history.add(idx);
//     });

//     _eatCtrl?.removeListener(_onEatTick);
//     await _eatCtrl?.dispose();

//     _eatCtrl = VideoPlayerController.asset(_eatOf(_fruits[idx]))
//       ..setLooping(false);

//     await _eatCtrl!.initialize();
//     if (!mounted) return;

//     await _eatCtrl!.setVolume(1.0);
//     _eatCtrl!.addListener(_onEatTick);
//     await _eatCtrl!.play();
//     setState(() => _paused = false);
//   }

//   // ── 먹기 종료(정리만) ─────────────────────────────────────────────────
//   Future<void> _finishEat() async {
//     if (_finishing) return; // 중복 방지
//     _finishing = true;

//     try {
//       setState(() {
//         _eatCtrl?.removeListener(_onEatTick);
//         _eatCtrl?.dispose();
//         _eatCtrl = null;
//         _playingIndex = null; // 선택 시 이미 먹음 처리됨
//       });
//     } finally {
//       _finishing = false;
//     }

//     if (_allCleared) {
//       await _navigateToResultOnce();
//     }
//   }

//   Future<void> _skipOrFinishCurrentEat() async {
//     if (_navigating) return;
//     if (_playingIndex == null || _eatCtrl == null) return;
//     await _finishEat();
//   }

//   void _playRandomRemaining() {
//     if (_playingIndex != null) return; // 이미 재생 중이면 무시
//     final remainingIdx = [
//       for (int i = 0; i < _eaten.length; i++)
//         if (!_eaten[i]) i,
//     ];
//     if (remainingIdx.isEmpty) return;
//     final idx = remainingIdx[Random().nextInt(remainingIdx.length)];
//     _playEatByIndex(idx);
//   }

//   // ── 전환(결과 화면) ───────────────────────────────────────────────────
//   Future<void> _navigateToResultOnce() async {
//     if (_navigating || !mounted) return;
//     _navigating = true;

//     // ✅ await 전에 NavigatorState 캐싱
//     final nav = Navigator.of(context);

//     try {
//       await _switchToStanding(play: false);
//       await _suspendMedia();
//       if (!mounted) return; // 안전 가드

//       await nav.pushReplacement(
//         PageRouteBuilder(
//           pageBuilder: (c, a, b) => const QuizResultScreen(),
//           transitionsBuilder: (c, a, b, child) =>
//               FadeTransition(opacity: a, child: child),
//           transitionDuration: const Duration(milliseconds: 300),
//         ),
//       );

//       // (돌아올 일은 거의 없지만 대비)
//       if (!mounted) return;
//       await _resumeMediaIfNeeded();
//     } finally {
//       _navigating = false;
//     }
//   }

//   // ── 네비게이션 버튼 ───────────────────────────────────────────────────
//   Future<void> _goPrev() async {
//     if (_navigating) return;

//     if (_playingIndex != null) {
//       setState(() {
//         _eatCtrl?.removeListener(_onEatTick);
//         _eatCtrl?.dispose();
//         _eatCtrl = null;
//         _playingIndex = null;
//       });
//     }

//     if (_history.isNotEmpty) {
//       final lastIdx = _history.removeLast();
//       setState(() => _eaten[lastIdx] = false);
//       return;
//     }

//     // ✅ await 전에 NavigatorState 캐싱
//     final nav = Navigator.of(context);

//     await _switchToStanding(play: false);
//     await _suspendMedia();
//     if (!mounted) return;

//     if (nav.canPop()) {
//       nav.pop({'popOne': true});
//     } else {
//       await nav.pushReplacement(
//         PageRouteBuilder(
//           pageBuilder: (c, a, b) => const GameSet2Screen(),
//           transitionsBuilder: (c, a, b, child) =>
//               FadeTransition(opacity: a, child: child),
//           transitionDuration: const Duration(milliseconds: 300),
//         ),
//       );
//     }
//   }

//   Future<void> _goNext() async {
//     if (_navigating) return;

//     if (_allCleared) {
//       await _navigateToResultOnce();
//       return;
//     }

//     if (_playingIndex != null) {
//       await _finishEat();
//       if (!mounted) return;
//       if (!_allCleared) {
//         _playRandomRemaining();
//       } else {
//         await _navigateToResultOnce();
//       }
//       return;
//     }

//     _playRandomRemaining();
//   }

//   // ── 유틸 ───────────────────────────────────────────────────────────────
//   double _calcScale(Size screen) =>
//       min(screen.width / baseW, screen.height / baseH);

//   // ── UI ─────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     final screen = MediaQuery.of(context).size;
//     final scale = _calcScale(screen);
//     final canvasW = baseW * scale;
//     final canvasH = baseH * scale;
//     final leftPad = (screen.width - canvasW) / 2;
//     final topPad = (screen.height - canvasH) / 2;

//     return Scaffold(
//       backgroundColor: const Color(0xFF8EE19A),
//       body: Stack(
//         children: [
//           Positioned(
//             left: leftPad,
//             top: topPad,
//             width: canvasW,
//             height: canvasH,
//             child: Stack(
//               children: [
//                 // 배경(standing loop)
//                 if (_standingCtrl.value.isInitialized)
//                   Positioned.fill(
//                     child: IgnorePointer(
//                       ignoring: true,
//                       child: FittedBox(
//                         fit: BoxFit.cover,
//                         child: SizedBox(
//                           width: _standingCtrl.value.size.width,
//                           height: _standingCtrl.value.size.height,
//                           child: VideoPlayer(_standingCtrl),
//                         ),
//                       ),
//                     ),
//                   )
//                 else
//                   const Positioned.fill(
//                     child: Center(child: CircularProgressIndicator()),
//                   ),

//                 // 먹기 영상
//                 if (_playingIndex != null &&
//                     _eatCtrl != null &&
//                     _eatCtrl!.value.isInitialized)
//                   Positioned.fill(
//                     child: IgnorePointer(
//                       ignoring: true,
//                       child: FittedBox(
//                         fit: BoxFit.cover,
//                         child: SizedBox(
//                           width: _eatCtrl!.value.size.width,
//                           height: _eatCtrl!.value.size.height,
//                           child: VideoPlayer(_eatCtrl!),
//                         ),
//                       ),
//                     ),
//                   ),

//                 // 과일(입력 차단은 먹는 중에만)
//                 AbsorbPointer(
//                   absorbing: _playingIndex != null,
//                   child: Stack(
//                     children: _buildFixedFruits(scale, leftPad, topPad),
//                   ),
//                 ),

//                 // 먹기 중 스킵 탭 레이어
//                 if (_playingIndex != null)
//                   Positioned.fill(
//                     child: GestureDetector(
//                       behavior: HitTestBehavior.opaque,
//                       onTap: () async {
//                         GlobalSfx.instance.play('tap');
//                         await Future.delayed(const Duration(milliseconds: 150));
//                         await _skipOrFinishCurrentEat();
//                       },
//                     ),
//                   ),

//                 // 컨트롤러 바
//                 Positioned(
//                   top: controllerTopPx * scale,
//                   right: controllerRightPx * scale,
//                   child: Transform.scale(
//                     scale: scale,
//                     alignment: Alignment.topRight,
//                     child: GameControllerBar(
//                       isPaused: _paused,
//                       onHome: () async {
//                         if (_navigating) return;

//                         // ✅ await 전에 NavigatorState 캐싱
//                         final nav = Navigator.of(context);

//                         await _switchToStanding(play: false);
//                         await _suspendMedia();
//                         if (!mounted) return;

//                         nav.pushNamedAndRemoveUntil('/', (r) => false);
//                       },
//                       onPrev: _goPrev,
//                       onNext: _goNext,
//                       onPauseToggle: _togglePause,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   List<Widget> _buildFixedFruits(double scale, double leftPad, double topPad) {
//     double lerpD(double a, double b, double t) => a + (b - a) * t;

//     Animation<double> staggerAnimFor(
//       int i, {
//       double span = 0.55,
//       double gap = 0.06,
//     }) {
//       final start = (i * gap).clamp(0.0, 1.0);
//       final end = (start + span).clamp(0.0, 1.0);
//       return CurvedAnimation(
//         parent: _enterCtrl,
//         curve: Interval(start, end, curve: Curves.easeOutCubic),
//       );
//     }

//     final widgets = <Widget>[];
//     for (int i = 0; i < _fruits.length; i++) {
//       if (_eaten[i]) continue;

//       final fruit = _fruits[i];
//       final targetBase = kSet3Slots[i];
//       final baseSize = kSet3FruitSizeBase[fruit] ?? const Size(160, 160);
//       final itemW = baseSize.width * scale;
//       final itemH = baseSize.height * scale;

//       final enterAnim = staggerAnimFor(i);
//       final opacityAnim = CurvedAnimation(
//         parent: _enterCtrl,
//         curve: Interval((i * 0.06).clamp(0.0, 1.0), 1.0, curve: Curves.easeIn),
//       );

//       final ampPx = 6.0 * scale;
//       final phase = i * pi * 0.8;

//       widgets.add(
//         KeyedSubtree(
//           key: ValueKey('${_keyOf(fruit)}-$i'), // ✅ 고유 키 부여
//           child: AnimatedBuilder(
//             animation: Listenable.merge([_enterCtrl, _bobCtrl]),
//             builder: (context, _) {
//               final t = enterAnim.value;
//               final xBase = lerpD(kEnterStartTopLeft.dx, targetBase.dx, t);
//               final yBase = lerpD(kEnterStartTopLeft.dy, targetBase.dy, t);
//               final theta = (_bobCtrl.value * 2 * pi) + phase;
//               final dy = sin(theta) * ampPx;
//               final left = leftPad + xBase * scale;
//               final top = topPad + yBase * scale + dy;

//               return Positioned(
//                 key: ValueKey('pos-${_keyOf(fruit)}-$i'),
//                 left: left,
//                 top: top,
//                 width: itemW,
//                 height: itemH,
//                 child: Opacity(
//                   opacity: opacityAnim.value,
//                   child: GestureDetector(
//                     behavior: HitTestBehavior.opaque,
//                     onTap: () async {
//                       GlobalSfx.instance.play('tap');
//                       await Future.delayed(const Duration(milliseconds: 150));
//                       _playEatByIndex(i);
//                     },
//                     child: Image.asset(
//                       _pngOf(fruit),
//                       fit: BoxFit.fill,
//                       errorBuilder: (context, error, stack) =>
//                           const SizedBox.shrink(),
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),
//       );
//     }
//     return widgets;
//   }
// }
