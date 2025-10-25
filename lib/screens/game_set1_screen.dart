// lib/screens/game_set1_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:kkomi_learn/widgets/fruit_play_stage.dart';

import '../models/learn_fruit.dart';
import '../widgets/game_controller_bar.dart';
import '../widgets/fruit_selector_board.dart';
import 'learn_set1_screen.dart'; // 이전(학습 영상)
import 'learn_set2_screen.dart';

class GameSet1Screen extends StatefulWidget {
  const GameSet1Screen({
    super.key,
    this.initialIndex = 0,
    this.startInPlay = false, // true면 FruitPlayStage로 바로 진입
  });

  final int initialIndex;
  final bool startInPlay;

  @override
  State<GameSet1Screen> createState() => _GameSet1ScreenState();
}

enum _Stage { select, play }

class _GameSet1ScreenState extends State<GameSet1Screen> {
  static const double baseW = 1920;
  static const double baseH = 1080;

  static const double controllerTopPx = 35;
  static const double controllerRightPx = 40;

  final fruits = const [
    LearnFruit.apple,
    LearnFruit.carrot,
    LearnFruit.cucumber,
    LearnFruit.grape,
    LearnFruit.radish,
  ];

  late int _fruitIndex;
  late _Stage _stage; // startInPlay로 초기 스테이지 결정

  bool _isSlice = false;
  bool _isLike = false;

  final AudioPlayer _bgm = AudioPlayer();
  bool _bgmPaused = false;

  LearnFruit get _fruit => fruits[_fruitIndex];

  @override
  void initState() {
    super.initState();
    _fruitIndex = widget.initialIndex.clamp(0, fruits.length - 1);
    _stage = widget.startInPlay ? _Stage.play : _Stage.select;
    _isSlice = false;
    _isLike = false;
    _startBgm();
  }

  @override
  void dispose() {
    _bgm.stop();
    _bgm.dispose();
    super.dispose();
  }

  Future<void> _startBgm() async {
    await _bgm.setReleaseMode(ReleaseMode.loop);
    await _bgm.play(AssetSource('audio/bgm/main_theme.wav'));
  }

  void _selectFruit(int index) {
    setState(() {
      _fruitIndex = index;
      _stage = _Stage.play;
      _isSlice = false;
      _isLike = false;
    });
  }

  void _onPlayTap() {
    if (!_isSlice || !_isLike) {
      setState(() {
        _isSlice = true;
        _isLike = true;
      });
    }
  }

  // ⬅️ 이전: 스테이지/인덱스에 따라 분기
  Future<void> _goPrev() async {
    if (_stage == _Stage.select) {
      // 선택 화면에서 이전 → LearnSet1Screen
      await _bgm.stop();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (c, a, b) => LearnSet1Screen(initialIndex: _fruitIndex),
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
      // 첫 번째 과일이면 선택 화면으로
      setState(() {
        _stage = _Stage.select;
        _isSlice = false;
        _isLike = false;
      });
    }
  }

  // 🏠 홈: 스플래시(메인, '/')로
  Future<void> _goHomeToSplash() async {
    await _bgm.stop();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _goNext() {
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
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (c, a, b) => const LearnSet2Screen(),
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

    // 1920×1080 기준 좌표
    const topLeftPx = <Offset>[
      Offset(502.50, 239.55), // apple
      Offset(1062.75, 272.75), // carrot
      Offset(324.25, 656.25), // cucumber
      Offset(811.25, 656.85), // grape
      Offset(1301.70, 637.40), // radish
    ];

    // 각 아이템 원본 크기
    const itemSizesPx = <Size>[
      Size(392, 206.65), // apple
      Size(243.1, 183.65), // carrot
      Size(276.45, 184.35), // cucumber
      Size(268.6, 153.1), // grape
      Size(265.2, 212.7), // radish
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
                    onCanvasTap: _onPlayTap,
                  ),
                Positioned(
                  top: controllerTopPx * scale,
                  right: controllerRightPx * scale,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topRight,
                    child: GameControllerBar(
                      isPaused: _bgmPaused,
                      onHome: _goHomeToSplash, // 홈=스플래시('/')
                      onPrev: _goPrev, // 이전=분기 동작
                      onNext: _goNext,
                      onPauseToggle: () async {
                        if (_bgmPaused) {
                          await _bgm.resume();
                        } else {
                          await _bgm.pause();
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
