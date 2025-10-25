import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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

  String _keyOf(LearnFruit f) => kLearnFruitMeta[f]!.key;
  String _pngOf(LearnFruit f) => 'assets/images/fruits/game/${_keyOf(f)}.png';
  String _eatOf(LearnFruit f) =>
      'assets/videos/reactions/game/set2/eat_${_keyOf(f)}.mp4';
  final String _standing =
      'assets/videos/reactions/game/set2/standing_loop.mp4';

  // ── 슬롯 좌표(고정 배치) ──────────────────────────────────────────────
  static const List<Offset> kSet2Slots = <Offset>[
    Offset(680.0, 180.0),
    Offset(892.4, 225.9),
    Offset(1037.8, 371.3),
    Offset(1083.7, 583.7),
    Offset(1019.6, 786.9),
    Offset(860.0, 930.0),
    Offset(640.0, 900.0),
    Offset(460.4, 786.9),
    Offset(396.3, 583.7),
    Offset(442.2, 371.3),
  ];

  // ── 상태 ─────────────────────────────────────────────────────────────
  late final List<bool> _eaten; // 각 슬롯이 사라졌는가
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
  }

  @override
  void dispose() {
    _eatCtrl?.removeListener(_onEatTick);
    _eatCtrl?.dispose();
    _standingCtrl.dispose();
    super.dispose();
  }

  // ── 유틸: 전부 먹었는지 ────────────────────────────────────────────────
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
      _finishEat(); // await 불필요 (listener)
    }
  }

  Future<void> _playEatByIndex(int idx) async {
    if (_playingIndex != null) return; // 이미 재생 중 막기
    if (_eaten[idx]) return; // 이미 먹은 슬롯

    setState(() {
      _playingIndex = idx; // 과일 입력 잠금(AbsorbPointer 작동) + 오버레이 표시
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

  // ── 완료 처리(스킵/자연 종료 공통) ────────────────────────────────────
  Future<void> _finishEat() async {
    // 모든 상태 변경을 setState 블록 안에서 처리 → 오버레이 즉시 해제 보장
    setState(() {
      _eatCtrl?.removeListener(_onEatTick);
      _eatCtrl?.dispose();
      _eatCtrl = null;

      final idx = _playingIndex;
      _playingIndex = null; // ← 오버레이 해제 트리거

      if (idx != null && !_eaten[idx]) {
        _eaten[idx] = true;
        _history.add(idx);
      }
    });

    if (_allCleared) {
      // GameSet3로 'push'하고, 돌아올 때 popOne 신호 받으면 마지막 과일 롤백
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

  // ── 스킵: 재생 중이면 즉시 완료 처리 ──────────────────────────────────
  Future<void> _skipOrFinishCurrentEat() async {
    if (_playingIndex == null || _eatCtrl == null) return;
    await _finishEat();
  }

  // ── 랜덤으로 다음 과일 먹기 시작 ─────────────────────────────────────
  void _playRandomRemaining() {
    final remainingIdx = <int>[];
    for (int i = 0; i < _eaten.length; i++) {
      if (!_eaten[i]) remainingIdx.add(i);
    }
    if (remainingIdx.isEmpty) return;
    final idx = remainingIdx[Random().nextInt(remainingIdx.length)];
    _playEatByIndex(idx);
  }

  // ── 컨트롤러: 홈/이전/다음 ────────────────────────────────────────────
  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _goPrev() {
    // 먹기 재생 중이면 취소(되돌리기 우선) — 취소는 ‘먹음’ 처리 없이 복귀
    if (_playingIndex != null) {
      setState(() {
        _eatCtrl?.removeListener(_onEatTick);
        _eatCtrl?.dispose();
        _eatCtrl = null;
        _playingIndex = null; // 오버레이 즉시 제거
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

    // 마지막에 먹은 슬롯 되돌리기
    final lastIdx = _history.removeLast();
    setState(() {
      _eaten[lastIdx] = false;
    });
  }

  Future<void> _goNext() async {
    if (_allCleared) {
      // 모두 먹음 상태에서 다음 → GameSet3로 동일 로직 (finishEat()와 동일)
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
      // ✅ 재생 중이면: 스킵 + 다음 과일 즉시 먹기 시작
      await _finishEat();
      if (mounted && !_allCleared && _playingIndex == null) {
        _playRandomRemaining();
      }
      return;
    }

    // ✅ 스탠바이면: 바로 랜덤 먹기 시작
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

                // 3) 과일(고정 슬롯) — 먹기 중에는 입력 잠시 막기(버그 방지)
                AbsorbPointer(
                  absorbing: _playingIndex != null, // 재생 중 과일 입력 잠금
                  child: Stack(children: _buildFixedFruits(scale)),
                ),

                // 4) 재생 중 스킵용 투명 오버레이 버튼(컨트롤러 아래/과일 위)
                if (_playingIndex != null)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _skipOrFinishCurrentEat, // 탭으로 즉시 스킵 → 스탠바이
                      child: const SizedBox.expand(), // 완전 투명
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
                      onHome: _goHome,
                      onPrev: _goPrev,
                      onNext: _goNext, // 재생 중: 스킵+다음 먹기 / 스탠바이: 랜덤 먹기
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

      final slot = kSet2Slots[i];
      widgets.add(
        Positioned(
          left: (slot.dx - itemSize / 2) * scale,
          top: (slot.dy - itemSize / 2) * scale,
          width: itemSize * scale,
          height: itemSize * scale,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque, // 터치 영역 보장
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
