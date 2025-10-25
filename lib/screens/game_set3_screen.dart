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

  // ── 세트 구성(고정 순서) ──────────────────────────────────────────────
  final List<LearnFruit> _fruits = const [
    LearnFruit.paprika,
    LearnFruit.watermelon,
    LearnFruit.tomato,
    LearnFruit.pumpkin,
    LearnFruit.radish,
    LearnFruit.kiwi,
    LearnFruit.grape,
    LearnFruit.pineapple,
    LearnFruit.strawberry,
    LearnFruit.eggplant,
  ];

  String _keyOf(LearnFruit f) => kLearnFruitMeta[f]!.key;
  String _pngOf(LearnFruit f) => 'assets/images/fruits/game/${_keyOf(f)}.png';
  String _eatOf(LearnFruit f) =>
      'assets/videos/reactions/game/set3/eat_${_keyOf(f)}.mp4';
  final String _standing =
      'assets/videos/reactions/game/set3/standing_loop.mp4';

  // ── 슬롯 좌표(고정 배치; 필요시 실제 좌표로 교체) ─────────────────────
  static const List<Offset> kSet3Slots = <Offset>[
    Offset(720.0, 160.0),
    Offset(930.0, 210.0),
    Offset(1065.0, 360.0),
    Offset(1110.0, 560.0),
    Offset(1045.0, 760.0),
    Offset(880.0, 900.0),
    Offset(660.0, 920.0),
    Offset(480.0, 800.0),
    Offset(420.0, 600.0),
    Offset(470.0, 380.0),
  ];

  // ── 상태 ─────────────────────────────────────────────────────────────
  late final List<bool> _eaten; // 각 슬롯 소거 여부
  final List<int> _history = []; // 먹은 슬롯 인덱스 스택
  int? _playingIndex; // 현재 먹기 영상 슬롯
  bool _paused = false;

  // 비디오 플레이어 (스탠딩 루프 + 먹기 1회성)
  late final VideoPlayerController _standingCtrl;
  VideoPlayerController? _eatCtrl;

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
  }

  @override
  void dispose() {
    _eatCtrl?.removeListener(_onEatTick);
    _eatCtrl?.dispose();
    _standingCtrl.dispose();
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
        setState(() => _paused = true);
      } else {
        _eatCtrl!.play();
        if (!_standingCtrl.value.isPlaying) _standingCtrl.play();
        setState(() => _paused = false);
      }
    } else {
      if (_standingCtrl.value.isInitialized) {
        if (_standingCtrl.value.isPlaying) {
          _standingCtrl.pause();
          setState(() => _paused = true);
        } else {
          _standingCtrl.play();
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

                // 3) 과일(고정 슬롯) — 먹기 중에는 입력 잠시 막기
                AbsorbPointer(
                  absorbing: _playingIndex != null,
                  child: Stack(children: _buildFixedFruits(scale)),
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

  List<Widget> _buildFixedFruits(double scale) {
    const double itemSize = 160;

    final widgets = <Widget>[];
    for (int i = 0; i < _fruits.length; i++) {
      if (_eaten[i]) continue;

      final slot = kSet3Slots[i];
      widgets.add(
        Positioned(
          left: (slot.dx - itemSize / 2) * scale,
          top: (slot.dy - itemSize / 2) * scale,
          width: itemSize * scale,
          height: itemSize * scale,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _playEatByIndex(i),
            child: Image.asset(
              _pngOf(_fruits[i]),
              fit: BoxFit.contain,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stack) =>
                      const SizedBox.shrink(),
            ),
          ),
        ),
      );
    }
    return widgets;
  }
}
