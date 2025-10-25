import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/learn_fruit.dart';
import '../widgets/shine_emphasis.dart';

/// 단일 과일 씬:
/// - (배경색 포함) 과일 영상 1개  ← *영상 안에 꼬미 리액션까지 합쳐져 있음*
/// - 그 위에 트레이(식판) PNG
/// - 그 위에 샤인 + 과일 이미지(whole/slice)
class FruitPlayStage extends StatefulWidget {
  const FruitPlayStage({
    super.key,
    required this.fruit,
    required this.isSlice,
    required this.isLikeVideo,
    required this.onCanvasTap,
  });

  final LearnFruit fruit;
  final bool isSlice; // false: whole, true: slice
  final bool isLikeVideo; // false: curious(반복), true: like(1회)
  final VoidCallback onCanvasTap;

  @override
  State<FruitPlayStage> createState() => _FruitPlayStageState();
}

class _FruitPlayStageState extends State<FruitPlayStage> {
  static const double baseW = 1920;
  static const double baseH = 1080;

  final ShineEmphasisController _shine = ShineEmphasisController();

  VideoPlayerController? _video;
  Future<void>? _videoInit;
  VoidCallback? _videoListener;

  @override
  void initState() {
    super.initState();
    _loadVideo();
    _replayShine();
  }

  @override
  void didUpdateWidget(covariant FruitPlayStage old) {
    super.didUpdateWidget(old);
    // 과일 또는 리액션 타입이 바뀌면( curious/like ) 영상만 교체
    if (old.fruit != widget.fruit || old.isLikeVideo != widget.isLikeVideo) {
      _loadVideo();
    }
    // whole/slice 전환이나 과일 변경 시 샤인 다시
    if (old.isSlice != widget.isSlice || old.fruit != widget.fruit) {
      _replayShine();
    }
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  // ===== assets =====
  // 합성된 단일 씬 영상: assets/videos/learn/{key}_{curious|like}.mp4
  String _sceneVideo(LearnFruit f, bool like) {
    final key = kLearnFruitMeta[f]!.key; // apple, carrot...
    return 'assets/videos/reactions/learn/${key}_${like ? "like" : "curious"}.mp4';
  }

  // 트레이/이미지: learn 경로 사용 (네 코드와 동일)
  String _tray(LearnFruit f) =>
      'assets/images/fruits/learn/${kLearnFruitMeta[f]!.key}/tray.png';
  String _whole(LearnFruit f) =>
      'assets/images/fruits/learn/${kLearnFruitMeta[f]!.key}/whole.png';
  String _slice(LearnFruit f) =>
      'assets/images/fruits/learn/${kLearnFruitMeta[f]!.key}/slice.png';

  // ===== video lifecycle =====
  void _disposeVideo() {
    if (_video != null && _videoListener != null) {
      _video!.removeListener(_videoListener!);
      _videoListener = null;
    }
    _video?.pause();
    _video?.dispose();
    _video = null;
    _videoInit = null;
  }

  void _loadVideo() {
    _disposeVideo();

    final path = _sceneVideo(widget.fruit, widget.isLikeVideo);
    final loop = !widget.isLikeVideo; // curious=loop, like=once

    _video = VideoPlayerController.asset(path);
    _videoInit = _video!.initialize().then((_) {
      if (!mounted) return;
      _video!
        ..setLooping(loop)
        ..play();

      // like(1회)일 때는 끝나면 멈춰서 마지막 프레임 유지
      if (!loop) {
        _videoListener = () {
          final v = _video!.value;
          if (v.isInitialized && !v.isPlaying && v.position >= v.duration) {
            _video!.pause();
          }
        };
        _video!.addListener(_videoListener!);
      }

      setState(() {});
    });
  }

  void _replayShine() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _shine.replay();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 레터박스 스케일
    final sz = MediaQuery.of(context).size;
    final scale = (sz.width / baseW).clamp(0.0, sz.height / baseH);
    final canvas = Size(baseW * scale, baseH * scale);
    final left = (sz.width - canvas.width) / 2;
    final top = (sz.height - canvas.height) / 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onCanvasTap,
      child: Stack(
        children: [
          // 1) 단일 영상(배경+리액션 포함)
          if (_video != null && _videoInit != null)
            Positioned.fromRect(
              rect: Rect.fromLTWH(left, top, canvas.width, canvas.height),
              child: FutureBuilder(
                future: _videoInit,
                builder: (context, child) {
                  if (child.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!_video!.value.isInitialized) {
                    return const SizedBox.shrink();
                  }
                  return FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _video!.value.size.width,
                      height: _video!.value.size.height,
                      child: VideoPlayer(_video!),
                    ),
                  );
                },
              ),
            ),

          // 2) 트레이(식판) — 영상 위, 과일 아래
          Positioned.fill(
            child: Image.asset(
              _tray(widget.fruit),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
          ),

          // 3) 샤인 + 과일 이미지 — 최상위 (ShineEmphasis 자체가 Positioned.fill 반환)
          ShineEmphasis(
            controller: _shine,
            imagePath: widget.isSlice
                ? _slice(widget.fruit)
                : _whole(widget.fruit),
            framesBasePath: 'assets/images/effects/shine_seq/shine_',
            frameDigits: 3,
            frameCount: 4,
            fps: 12,
            shineLoops: 3,
            fxDuration: const Duration(milliseconds: 900),
            autoplay: true,
          ),
        ],
      ),
    );
  }
}
