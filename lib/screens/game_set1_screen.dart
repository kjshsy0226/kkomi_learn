// lib/screens/game_set1_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';

import '../core/bgm_tracks.dart'; // ✅ 전역 BGM 숏컷 (ensureGame/stopGame, pause/resume)
import '../models/learn_fruit.dart';
import '../widgets/game_controller_bar.dart';
import '../widgets/fruit_selector_board.dart';
import '../widgets/fruit_play_stage.dart';
import 'learn_set4_screen.dart'; // Prev (선택 화면에서 이전)
import 'learn_set5_screen.dart'; // Next (게임1 끝나면 여기로)

class GameSet1Screen extends StatefulWidget {
  const GameSet1Screen({super.key});

  @override
  State<GameSet1Screen> createState() => _GameSet1ScreenState();
}

enum _Stage { select, play }

class _GameSet1ScreenState extends State<GameSet1Screen> {
  static const double baseW = 1920;
  static const double baseH = 1080;

  static const double controllerTopPx = 35;
  static const double controllerRightPx = 40;

  // 노란 세트(예시 5개)
  final fruits = const [
    LearnFruit.apple,
    LearnFruit.carrot,
    LearnFruit.cucumber,
    LearnFruit.grape,
    LearnFruit.radish,
  ];

  int _fruitIndex = 0;
  _Stage _stage = _Stage.select;

  bool _isSlice = false;
  bool _isLike = false;

  bool _bgmPaused = false;
  bool _navigatingNext = false; // ✅ 화면 탭 중복-다음 이동 방지

  // ✅ FruitPlayStage 내부 자원 제어를 위한 키
  final GlobalKey<FruitPlayStageState> _playKey = GlobalKey<FruitPlayStageState>();

  LearnFruit get _fruit => fruits[_fruitIndex];

  @override
  void initState() {
    super.initState();
    GlobalBgm.instance.ensureGame();
  }

  @override
  void dispose() {
    GlobalBgm.instance.stopGame();
    super.dispose();
  }

  void _selectFruit(int index) {
    setState(() {
      _fruitIndex = index;
      _stage = _Stage.play;
      _isSlice = false;
      _isLike = false;
    });
  }

  /// 화면 아무 데나 탭하면 호출됨(FruitPlayStage → onCanvasTap)
  /// 1) 아직 시작 전이면: 슬라이스+좋아요 영상 재생 시작
  /// 2) 이미 진행/완료 상태면: 다음 과일로 이동 (마지막이면 다음 화면)
  void _onPlayTap() {
    if (_stage != _Stage.play) return;

    // 첫 탭: like 세트 재생 시작
    if (!_isSlice || !_isLike) {
      setState(() {
        _isSlice = true;
        _isLike = true;
      });
      return;
    }

    // 이후 탭: 다음으로
    if (_navigatingNext) return;
    _navigatingNext = true;
    _goNext().whenComplete(() {
      if (mounted && _stage == _Stage.play) {
        _navigatingNext = false;
      }
    });
  }

  // ⬅️ 이전
  Future<void> _goPrev() async {
    if (_stage == _Stage.select) {
      GlobalBgm.instance.stopGame();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (c, a, b) => const LearnSet4Screen(),
          transitionsBuilder: (c, a, b, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
      return;
    }

    if (_fruitIndex > 0) {
      await _switchFruitCore(_fruitIndex - 1);
    } else {
      // 플레이 → 선택
      await _playKey.currentState?.haltAndRelease();
      setState(() {
        _stage = _Stage.select;
        _isSlice = false;
        _isLike = false;
      });
    }
  }

  // 🏠 홈
  Future<void> _goHomeToSplash() async {
    GlobalBgm.instance.stopGame();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  // ➡️ 다음
  Future<void> _goNext() async {
    if (_stage == _Stage.select) {
      setState(() {
        _stage = _Stage.play;
        _isSlice = false;
        _isLike = false;
      });
      return;
    }

    if (_fruitIndex < fruits.length - 1) {
      await _switchFruitCore(_fruitIndex + 1);
    } else {
      await _playKey.currentState?.haltAndRelease();
      GlobalBgm.instance.stopGame();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (c, a, b) => const LearnSet5Screen(),
          transitionsBuilder: (c, a, b, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  /// ✅ 근본 전환 로직:
  /// 1) 현재 과일 재생 즉시 정지/0초/Dispose (haltAndRelease)
  /// 2) 인덱스 교체 → 빌드 → 첫 프레임부터 새 영상만 노출
  Future<void> _switchFruitCore(int nextIndex) async {
    await _playKey.currentState?.haltAndRelease(); // 현재 세트 정지/해제
    if (!mounted) return;
    setState(() {
      _fruitIndex = nextIndex;
      _isSlice = false;
      _isLike = false;
    });
    await WidgetsBinding.instance.endOfFrame; // 선택: 한 프레임 동기화
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final scale = min(sz.width / baseW, sz.height / baseH);
    final canvasW = baseW * scale;
    final canvasH = baseH * scale;
    final leftPad = (sz.width - canvasW) / 2;
    final topPad = (sz.height - canvasH) / 2;

    // 1920×1080 기준 좌표 샘플
    const topLeftPx = <Offset>[
      Offset(502.50, 239.55), // apple
      Offset(1062.75, 272.75), // carrot
      Offset(324.25, 656.25), // cucumber
      Offset(811.25, 656.85), // grape
      Offset(1301.70, 637.40), // radish
    ];

    const itemSizesPx = <Size>[
      Size(392, 206.65),
      Size(243.1, 183.65),
      Size(276.45, 184.35),
      Size(268.6, 153.1),
      Size(265.2, 212.7),
    ];

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            left: leftPad,
            top: topPad,
            width: canvasW,
            height: canvasH,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: Colors.white)),
                
                if (_stage == _Stage.select)
                  FruitSelectorBoard(
                    fruits: fruits,
                    topLeftPositionsBase: topLeftPx,
                    itemSizesBase: itemSizesPx,
                    onFruitPicked: _selectFruit,
                    backgroundPath: 'assets/images/selector/background.png',
                  )
                else
                  FruitPlayStage(
                    key: _playKey,
                    fruit: _fruit,
                    isSlice: _isSlice,
                    isLikeVideo: _isLike,
                    onCanvasTap: _onPlayTap,
                  ),

                // 컨트롤러 바
                Positioned(
                  top: controllerTopPx * scale,
                  right: controllerRightPx * scale,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topRight,
                    child: GameControllerBar(
                      isPaused: _bgmPaused,
                      onHome: _goHomeToSplash,
                      onPrev: _goPrev,
                      onNext: _goNext,
                      onPauseToggle: () async {
                        if (_bgmPaused) {
                          await GlobalBgm.instance.resume();
                        } else {
                          await GlobalBgm.instance.pause();
                        }
                        if (mounted) setState(() => _bgmPaused = !_bgmPaused);
                      },
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
}
