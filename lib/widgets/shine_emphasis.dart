import 'dart:math';
import 'package:flutter/material.dart';
import 'package:kkomi_learn/widgets/sequence_sprites.dart';

class ShineEmphasisController {
  VoidCallback? _replay;
  void replay() => _replay?.call();
}

/// 1920×1080 이미지 위에 샤인 시퀀스 + 팝 FX를 얹는 강조 위젯
class ShineEmphasis extends StatefulWidget {
  const ShineEmphasis({
    super.key,
    required this.imagePath,
    required this.controller,
    // Shine sequence
    this.framesBasePath = 'assets/images/effects/shine_seq/shine_',
    this.frameDigits = 3,
    this.frameCount = 4,
    this.fps = 12,
    this.shineLoops = 3,
    // FX
    this.fxDuration = const Duration(milliseconds: 900),
    this.autoplay = true,
  });

  final String imagePath;
  final ShineEmphasisController controller;

  final String framesBasePath;
  final int frameDigits;
  final int frameCount;
  final double fps;
  final int shineLoops;

  final Duration fxDuration;
  final bool autoplay;

  @override
  State<ShineEmphasis> createState() => _ShineEmphasisState();
}

class _ShineEmphasisState extends State<ShineEmphasis>
    with TickerProviderStateMixin {
  late final AnimationController _fxCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  late final SequenceController _seqCtrl;
  late List<String> _frames;
  int _looped = 0;

  @override
  void initState() {
    super.initState();

    widget.controller._replay = _replay;

    _buildFrames();
    _seqCtrl = SequenceController()
      ..onLoopRestart = () {
        _looped++;
        if (_looped >= max(1, widget.shineLoops)) _seqCtrl.stop();
      };

    _fxCtrl = AnimationController(vsync: this, duration: widget.fxDuration);
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.96,
          end: 1.04,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.04,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
    ]).animate(_fxCtrl);
    _fade = CurvedAnimation(parent: _fxCtrl, curve: Curves.easeInOut);

    if (widget.autoplay) _replay();
  }

  void _buildFrames() {
    _frames = List.generate(widget.frameCount, (i) {
      final n = i.toString().padLeft(widget.frameDigits, '0');
      return '${widget.framesBasePath}$n.png';
    });
  }

  void _replay() {
    _looped = 0;
    _seqCtrl.stop();
    _fxCtrl.forward(from: 0);
    _seqCtrl.start();
  }

  @override
  void didUpdateWidget(covariant ShineEmphasis oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _replay();
    }
    if (oldWidget.framesBasePath != widget.framesBasePath ||
        oldWidget.frameDigits != widget.frameDigits ||
        oldWidget.frameCount != widget.frameCount) {
      _buildFrames();
      _replay();
    }
    if (oldWidget.controller != widget.controller) {
      widget.controller._replay = _replay;
    }
  }

  @override
  void dispose() {
    _fxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ❗️절대 Positioned를 여기서 리턴하지 않습니다.
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1) 샤인
        if (_frames.isNotEmpty)
          SequenceSprite(
            controller: _seqCtrl,
            assetPaths: _frames,
            fps: widget.fps,
            loop: true,
            autoplay: false,
            holdLastFrameWhenFinished: false,
            precache: true,
            fit: BoxFit.cover,
          ),

        // 2) 이미지 + 팝FX
        AnimatedBuilder(
          animation: _fxCtrl,
          builder: (context, child) => Opacity(
            opacity: _fade.value,
            child: Transform.scale(scale: _scale.value, child: child),
          ),
          child: Image.asset(
            widget.imagePath,
            fit: BoxFit.fill, // 1920×1080 기준
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
