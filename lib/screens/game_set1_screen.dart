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

  LearnFruit get _fruit => fruits[_fruitIndex];

  @override
  void initState() {
    super.initState();
    // ✅ 게임 BGM 보장 (중복 호출 안전)
    GlobalBgm.instance.ensureGame();
  }

  @override
  void dispose() {
    // ✅ 이 화면을 완전히 떠날 때 안전 차단(홈/다른 플로우에선 별도로 stopGame 호출)
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
      // 같은 화면 내에서 다음 과일로만 이동했다면 플래그 해제
      // (다른 화면으로 pushReplacement한 경우는 굳이 해제 안 해도 무방)
      if (mounted && _stage == _Stage.play) {
        _navigatingNext = false;
      }
    });
  }

  // ⬅️ 이전
  Future<void> _goPrev() async {
    if (_stage == _Stage.select) {
      // 선택 화면에서 이전 → LearnSet4 (게임 BGM 정리)
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

    // 플레이 화면에서 이전
    if (_fruitIndex > 0) {
      setState(() {
        _fruitIndex--;
        _isSlice = false;
        _isLike = false;
      });
    } else {
      setState(() {
        _stage = _Stage.select;
        _isSlice = false;
        _isLike = false;
      });
    }
  }

  // 🏠 홈
  Future<void> _goHomeToSplash() async {
    // ✅ 홈(스플래시)로 나갈 땐 게임 BGM 반드시 정리
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
      setState(() {
        _fruitIndex++;
        _isSlice = false;
        _isLike = false;
      });
    } else {
      // 마지막 과일 완료 ➜ LearnSet5로 이동 (게임 BGM 정리)
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
                    fruit: _fruit,
                    isSlice: _isSlice,
                    isLikeVideo: _isLike,
                    onCanvasTap: _onPlayTap, // ✅ 화면 탭으로 제어
                  ),
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
                      onNext: _goNext, // ✅ 마지막에서 LearnSet5로
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
