import 'dart:async'; // unawaited
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';

import '../models/learn_fruit.dart';
import '../widgets/game_controller_bar.dart';
import 'learn_set3_screen.dart';
import 'game_set3_screen.dart';

class GameSet2Screen extends StatefulWidget {
  const GameSet2Screen({super.key});

  @override
  State<GameSet2Screen> createState() => _GameSet2ScreenState();
}

class _GameSet2ScreenState extends State<GameSet2Screen>
    with TickerProviderStateMixin {
  // ── 기준 캔버스(1920×1080) & 컨트롤러 위치 ─────────────────────────────
  static const double baseW = 1920;
  static const double baseH = 1080;
  static const double controllerTopPx = 35;
  static const double controllerRightPx = 40;

  // 입장 애니메이션: 시작 top-left 좌표(1920×1080 기준)
  static const Offset kEnterStartTopLeft = Offset(640, 540);

  // ── 세트 구성(고정 순서) ──────────────────────────────────────────────
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

  // 🔹 과일 PNG 경로/키
  String _keyOf(LearnFruit f) => kLearnFruitMeta[f]!.key;
  String _pngOf(LearnFruit f) => 'assets/images/fruits/game/${_keyOf(f)}.png';
  String _eatOf(LearnFruit f) =>
      'assets/videos/reactions/game/set2/eat_${_keyOf(f)}.mp4';
  final String _standing =
      'assets/videos/reactions/game/set2/standing_loop.mp4';

  // ── 슬롯 좌표(고정 배치, "좌상단" 기준) ─────────────────────────────────
  static const List<Offset> kSet2Slots = <Offset>[
    Offset(236.15, 124.80), // 사과
    Offset(583.45, 109.05), // 배추
    Offset(1021.40, 162.95), // 양파
    Offset(1139.45, 384.15), // 오이
    Offset(967.75, 835.50), // 귤
    Offset(603.95, 702.85), // 시금치
    Offset(298.85, 798.20), // 참외
    Offset(201.25, 560.85), // 당근
    Offset(389.75, 421.55), // 바나나
    Offset(880.90, 451.55), // 복숭아
  ];

  // 🔹 개별 과일 사이즈 매핑(1920×1080 기준 px)
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

  // ── 상태 ─────────────────────────────────────────────────────────────
  late final List<bool> _eaten; // 각 슬롯이 사라졌는가
  final List<int> _history = []; // 먹은 슬롯 인덱스 스택
  int? _playingIndex; // 현재 먹기 영상 슬롯
  bool _paused = false;

  // 비디오 플레이어 (스탠딩 루프 + 먹기 1회성)
  late final VideoPlayerController _standingCtrl;
  VideoPlayerController? _eatCtrl;

  // 입장 애니메이션(공용, Interval로 스태거)
  late final AnimationController _enterCtrl;

  // 🔹 보빙(둥실둥실) 애니메이션: 위/아래만
  late final AnimationController _bobCtrl;

  @override
  void initState() {
    super.initState();
    assert(
      kSet2Slots.length == _fruits.length,
      'kSet2Slots length must match fruits length(=10).',
    );

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

    // 보빙: 2.2초 주기의 위/아래만
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
        _bobCtrl.stop(canceled: false); // 보빙 멈춤
        setState(() => _paused = true);
      } else {
        _eatCtrl!.play();
        if (!_standingCtrl.value.isPlaying) _standingCtrl.play();
        if (!_bobCtrl.isAnimating) _bobCtrl.repeat(); // 보빙 재개
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

    setState(() {
      _playingIndex = idx;
    });

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
    final remainingIdx = <int>[];
    for (int i = 0; i < _eaten.length; i++) {
      if (!_eaten[i]) remainingIdx.add(i);
    }
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
          pageBuilder: (c, a, b) => const LearnSet3Screen(),
          transitionsBuilder: (c, a, b, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
      return;
    }

    final lastIdx = _history.removeLast();
    setState(() {
      _eaten[lastIdx] = false;
    });
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
          // 캔버스 프레임
          Positioned(
            left: leftPad,
            top: topPad,
            width: canvasW,
            height: canvasH,
            child: Stack(
              children: [
                // 1) 스탠딩 루프
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

                // 2) 먹기 영상 오버레이
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

                // 3) 과일(좌상단 기준) — 입장 + 위/아래 보빙
                AbsorbPointer(
                  absorbing: _playingIndex != null,
                  child: Stack(
                    children: _buildFixedFruits(scale, leftPad, topPad),
                  ),
                ),

                // 4) 재생 중 스킵 투명 레이어
                if (_playingIndex != null)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        // 🔊 버튼 효과음 (저지연)
                        final tapPlayer = AudioPlayer()
                          ..setPlayerMode(PlayerMode.lowLatency)
                          ..setReleaseMode(ReleaseMode.stop)
                          ..setVolume(0.9);

                        unawaited(
                          tapPlayer.play(AssetSource('audio/sfx/btn_tap.mp3')),
                        );

                        // 🎬 짧은 대기 후 스킵 처리
                        await Future.delayed(const Duration(milliseconds: 150));
                        await _skipOrFinishCurrentEat();

                        // 💨 플레이어 정리 (느슨하게)
                        Future.delayed(
                          const Duration(milliseconds: 500),
                          () async {
                            try {
                              await tapPlayer.dispose();
                            } catch (_) {}
                          },
                        );
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),

                // 5) 컨트롤러
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

  // ── 좌상단 기준 배치 + 입장 + (위/아래) 보빙 ────────────────────────────
  List<Widget> _buildFixedFruits(double scale, double leftPad, double topPad) {
    double lerpD(double a, double b, double t) => a + (b - a) * t;

    // 입장 스태거
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

      // 🔹 과일별 사이즈(스케일 반영)
      final Size baseSize = kSet2FruitSizeBase[fruit] ?? const Size(160, 160);
      final double itemW = baseSize.width * scale;
      final double itemH = baseSize.height * scale;

      final enterAnim = staggerAnimFor(i);
      final opacityAnim = CurvedAnimation(
        parent: _enterCtrl,
        curve: Interval((i * 0.06).clamp(0.0, 1.0), 1.0, curve: Curves.easeIn),
      );

      // 🔹 보빙 파라미터
      final double ampPx = 6.0 * scale; // 위/아래 진폭
      final double phase = i * pi * 0.8; // 과일별 위상 차

      widgets.add(
        AnimatedBuilder(
          animation: Listenable.merge([_enterCtrl, _bobCtrl]),
          builder: (context, _) {
            final t = enterAnim.value;

            // 입장 보간(좌상단 기준)
            final xBase = lerpD(kEnterStartTopLeft.dx, targetBase.dx, t);
            final yBase = lerpD(kEnterStartTopLeft.dy, targetBase.dy, t);

            // 보빙(위/아래만)
            final double theta = (_bobCtrl.value * 2 * pi) + phase;
            final double dy = sin(theta) * ampPx;

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
                    // ✅ 과일 클릭 시 효과음 + 짧은 대기 후 실행
                    final tapPlayer = AudioPlayer()
                      ..setPlayerMode(PlayerMode.lowLatency)
                      ..setReleaseMode(ReleaseMode.stop)
                      ..setVolume(0.9);
                    unawaited(
                      tapPlayer.play(AssetSource('audio/sfx/btn_tap.mp3')),
                    );

                    await Future.delayed(const Duration(milliseconds: 150));
                    _playEatByIndex(i);

                    Future.delayed(const Duration(milliseconds: 500), () async {
                      try {
                        await tapPlayer.dispose();
                      } catch (_) {}
                    });
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
