import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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
  // ── 기준 캔버스(1920×1080) & 컨트롤러 위치 ─────────────────────────────
  static const double baseW = 1920;
  static const double baseH = 1080;
  static const double controllerTopPx = 35;
  static const double controllerRightPx = 40;

  // 입장 애니메이션: 시작 top-left 좌표(1920×1080 기준)
  static const Offset kEnterStartTopLeft = Offset(640, 540);

  // ── 세트 구성(고정 순서) ──────────────────────────────────────────────
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

  // ── 슬롯 좌표(고정 배치, "좌상단" 기준) ─────────────────────────────────
  static const List<Offset> kSet3Slots = <Offset>[
    Offset(41.80, 372.75), // 가지
    Offset(291.50, 103.10), // 파프리카
    Offset(559.35, 81.25), // 수박
    Offset(973.95, 118.00), // 토마토
    Offset(1017.40, 389.50), // 호박
    Offset(983.45, 799.60), // 키위
    Offset(680.45, 824.65), // 포도
    Offset(222.75, 717.50), // 파인애플
    Offset(371.90, 477.85), // 딸기
    Offset(669.05, 457.75), // 무
  ];

  // 🔹 개별 과일 사이즈 매핑(1920×1080 기준 px) — w × h
  static const Map<LearnFruit, Size> kSet3FruitSizeBase = {
    LearnFruit.eggplant: Size(105, 297), // 가지
    LearnFruit.grape: Size(161, 218), // 포도
    LearnFruit.kiwi: Size(142, 134), // 키위
    LearnFruit.paprika: Size(170, 190), // 파프리카
    LearnFruit.pineapple: Size(208, 279), // 파인애플
    LearnFruit.pumpkin: Size(269, 256), // 호박
    LearnFruit.radish: Size(246, 293), // 무
    LearnFruit.strawberry: Size(124, 105), // 딸기
    LearnFruit.tomato: Size(173, 144), // 토마토
    LearnFruit.watermelon: Size(280, 309), // 수박
  };

  // ── 상태 ─────────────────────────────────────────────────────────────
  late final List<bool> _eaten; // 각 슬롯 소거 여부
  final List<int> _history = []; // 먹은 슬롯 인덱스 스택
  int? _playingIndex; // 현재 먹기 영상 슬롯
  bool _paused = false;

  // 비디오 플레이어 (스탠딩 루프 + 먹기 1회성)
  late final VideoPlayerController _standingCtrl;
  VideoPlayerController? _eatCtrl;

  // 입장 애니메이션(스태거)
  late final AnimationController _enterCtrl;

  // 위/아래 보빙(둥실둥실)
  late final AnimationController _bobCtrl;

  @override
  void initState() {
    super.initState();
    assert(
      kSet3Slots.length == _fruits.length,
      'kSet3Slots length must match fruits length(=10).',
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

  // ── 재생 제어 ─────────────────────────────────────────────────────────
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

  // 먹기 영상 자연 종료 감지 → 공통 완료 처리
  void _onEatTick() {
    final v = _eatCtrl!.value;
    if (v.hasError) return;
    if (v.isInitialized && !v.isPlaying && v.position >= v.duration) {
      _finishEat();
    }
  }

  Future<void> _playEatByIndex(int idx) async {
    if (_playingIndex != null) return; // 이미 재생 중 막기
    if (_eaten[idx]) return; // 이미 먹은 슬롯

    setState(() {
      _playingIndex = idx; // 과일 입력 잠금 + 오버레이 표시
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

  // 스킵/자연 종료 공통 완료 처리
  void _finishEat() {
    setState(() {
      _eatCtrl?.removeListener(_onEatTick);
      _eatCtrl?.dispose();
      _eatCtrl = null;

      final idx = _playingIndex;
      _playingIndex = null; // 오버레이 해제

      if (idx != null && !_eaten[idx]) {
        _eaten[idx] = true;
        _history.add(idx);
      }
    });

    if (_allCleared) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (c, a, b) => const QuizResultScreen(),
          transitionsBuilder: (c, a, b, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  void _skipOrFinishCurrentEat() {
    if (_playingIndex == null || _eatCtrl == null) return;
    _finishEat();
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

  void _goPrev() {
    // 재생 중이면 취소
    if (_playingIndex != null) {
      setState(() {
        _eatCtrl?.removeListener(_onEatTick);
        _eatCtrl?.dispose();
        _eatCtrl = null;
        _playingIndex = null;
      });
    }

    // 과거가 있으면 되돌리기
    if (_history.isNotEmpty) {
      final lastIdx = _history.removeLast();
      setState(() => _eaten[lastIdx] = false);
      return;
    }

    // 히스토리 없으면 GameSet2로 (pop 하면서 "한 개 되돌리기" 신호 전달)
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop({'popOne': true}); // ✅ 핵심: popOne 신호
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (c, a, b) => const GameSet2Screen(),
          transitionsBuilder: (c, a, b, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  void _goNext() {
    if (_allCleared) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (c, a, b) => const QuizResultScreen(),
          transitionsBuilder: (c, a, b, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
      return;
    }

    if (_playingIndex != null) {
      // 재생 중: 스킵 후 남은 과일 즉시 진행
      _finishEat();
      if (mounted && !_allCleared && _playingIndex == null) {
        _playRandomRemaining();
      }
      return;
    }

    // 스탠바이: 랜덤 시작
    _playRandomRemaining();
  }

  // ── 스케일 계산 ──────────────────────────────────────────────────────
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
          // 캔버스 프레임
          Positioned(
            left: leftPad,
            top: topPad,
            width: canvasW,
            height: canvasH,
            child: Stack(
              children: [
                // 1) 스탠딩 루프 (배경, 터치 패스)
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

                // 2) 먹기 영상(있으면 최상단 오버레이, 터치 패스)
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

                // 3) 과일(좌상단 기준, 개별 사이즈) — 먹기 중 입력 잠금
                AbsorbPointer(
                  absorbing: _playingIndex != null,
                  child: Stack(
                    children: _buildFixedFruits(scale, leftPad, topPad),
                  ),
                ),

                // 4) 재생 중 스킵용 투명 오버레이(컨트롤러 아래/과일 위)
                if (_playingIndex != null)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _skipOrFinishCurrentEat,
                      child: const SizedBox.expand(),
                    ),
                  ),

                // 5) 컨트롤러 (최상단)
                Positioned(
                  top: controllerTopPx * scale,
                  right: controllerRightPx * scale,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topRight,
                    child: GameControllerBar(
                      isPaused: _paused,
                      onHome: () => Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/', (route) => false),
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

  // ── 좌상단 기준 배치 + 입장(0→1) + (위/아래) 보빙 ───────────────────────
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
      final targetBase = kSet3Slots[i];

      // 과일별 사이즈(스케일 반영)
      final Size baseSize = kSet3FruitSizeBase[fruit] ?? const Size(160, 160);
      final double itemW = baseSize.width * scale;
      final double itemH = baseSize.height * scale;

      final enterAnim = staggerAnimFor(i);
      final opacityAnim = CurvedAnimation(
        parent: _enterCtrl,
        curve: Interval((i * 0.06).clamp(0.0, 1.0), 1.0, curve: Curves.easeIn),
      );

      // 보빙 파라미터
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

            final double left = leftPad + xBase * scale;
            final double top = topPad + yBase * scale + dy;

            return Positioned(
              left: left,
              top: top,
              width: itemW,
              height: itemH,
              child: Opacity(
                opacity: opacityAnim.value, // 0 → 1
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _playEatByIndex(i),
                  child: Image.asset(
                    _pngOf(fruit),
                    fit: BoxFit.fill, // PNG 실제 박스에 맞춤 (여백 있으면 contain 추천)
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
