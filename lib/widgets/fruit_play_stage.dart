import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/learn_fruit.dart';
import '../widgets/shine_emphasis.dart';

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
  final bool isLikeVideo; // false: curious, true: like(끝나면 like_loop)
  final VoidCallback onCanvasTap;

  @override
  State<FruitPlayStage> createState() => _FruitPlayStageState();
}

enum _ActiveLayer { curious, like, likeLoop }

class _FruitPlayStageState extends State<FruitPlayStage> {
  final ShineEmphasisController _shine = ShineEmphasisController();

  // videos(현재 세트)
  VideoPlayerController? _curiousC;
  VideoPlayerController? _likeC;
  VideoPlayerController? _likeLoopC;

  // 다음 세트 준비용
  VideoPlayerController? _nextCuriousC;
  VideoPlayerController? _nextLikeC;
  VideoPlayerController? _nextLikeLoopC;

  Future<void>? _initFuture;
  VoidCallback? _likeEndListener;

  _ActiveLayer _active = _ActiveLayer.curious;
  bool _ready = false;

  // images
  ImageProvider _bgImage = const AssetImage('');
  ImageProvider? _trayImage;
  ImageProvider? _wholeImage;
  ImageProvider? _sliceImage;

  // 🔸 initState에서는 precache를 호출하지 않는다!
  @override
  void initState() {
    super.initState();
    _replayShine();
  }

  // 🔸 MediaQuery 의존이 가능한 시점에서 최초 프리캐시 + 세트 준비
  bool _bootstrapped = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bootstrapped) {
      _bootstrapped = true;
      _prepareSetAndImages(
        widget.fruit,
        jumpTo: widget.isLikeVideo ? _ActiveLayer.like : _ActiveLayer.curious,
      );
    }
  }

  @override
  void didUpdateWidget(covariant FruitPlayStage old) {
    super.didUpdateWidget(old);

    // curious ↔ like 전환: 레이어 전환 + 재생 보장
    if (old.isLikeVideo != widget.isLikeVideo && _ready) {
      _switchActive(
        widget.isLikeVideo ? _ActiveLayer.like : _ActiveLayer.curious,
      );
    }

    // 과일 변경: 다음 리소스(이미지+비디오) 선로딩 후 세트 스왑
    if (old.fruit != widget.fruit) {
      _prepareSetAndImages(
        widget.fruit,
        jumpTo: widget.isLikeVideo ? _ActiveLayer.like : _ActiveLayer.curious,
      );
    }

    // 시각(whole/slice) 변경 시 샤인 재생
    if (old.isSlice != widget.isSlice || old.fruit != widget.fruit) {
      _replayShine();
    }
  }

  @override
  void dispose() {
    _removeLikeListener();
    _disposeSet(_curiousC, _likeC, _likeLoopC);
    _disposeSet(_nextCuriousC, _nextLikeC, _nextLikeLoopC);
    super.dispose();
  }

  // ───────── images: precache helpers ─────────
  Future<void> _precacheFruitImages(BuildContext ctx, LearnFruit f) async {
    final bg = AssetImage(learnbackgroundPath(f));
    final tray = AssetImage(learnTrayPath(f));
    final whole = AssetImage(learnNormalPath(f));
    final slice = AssetImage(learnHalfPath(f));

    await Future.wait([
      precacheImage(bg, ctx),
      precacheImage(tray, ctx),
      precacheImage(whole, ctx),
      precacheImage(slice, ctx),
    ]);

    _bgImage = bg;
    _trayImage = tray;
    _wholeImage = whole;
    _sliceImage = slice;
  }

  // ───────── videos: lifecycle ─────────
  void _disposeSet(
    VideoPlayerController? a,
    VideoPlayerController? b,
    VideoPlayerController? c,
  ) {
    a?.dispose();
    b?.dispose();
    c?.dispose();
  }

  void _removeLikeListener() {
    if (_likeC != null && _likeEndListener != null) {
      _likeC!.removeListener(_likeEndListener!);
      _likeEndListener = null;
    }
  }

  Future<void> _prepareSetAndImages(
    LearnFruit f, {
    required _ActiveLayer jumpTo,
  }) async {
    // 1) 이미지 선로딩 (didChangeDependencies 이후라 MediaQuery OK)
    await _precacheFruitImages(context, f);

    // 2) 다음 비디오 컨트롤러 생성
    _disposeSet(_nextCuriousC, _nextLikeC, _nextLikeLoopC);
    _nextCuriousC = VideoPlayerController.asset(learnCuriousVideo(f));
    _nextLikeC = VideoPlayerController.asset(learnLikeVideo(f));
    _nextLikeLoopC = VideoPlayerController.asset(learnLikeLoopVideo(f));

    // 3) 비디오 3종 initialize + 텍스처 워밍업
    _initFuture =
        Future.wait([
          _nextCuriousC!.initialize(),
          _nextLikeC!.initialize(),
          _nextLikeLoopC!.initialize(),
        ]).then((_) async {
          if (!mounted) return;

          _nextCuriousC!
            ..setLooping(true)
            ..play()
            ..pause();
          _nextLikeC!
            ..setLooping(false)
            ..play()
            ..pause();
          _nextLikeLoopC!
            ..setLooping(true)
            ..play()
            ..pause();

          // 4) 기존 세트 보존 상태에서 스왑
          final oldCur = _curiousC;
          final oldLike = _likeC;
          final oldLoop = _likeLoopC;

          _removeLikeListener();

          _curiousC = _nextCuriousC;
          _likeC = _nextLikeC;
          _likeLoopC = _nextLikeLoopC;

          _nextCuriousC = null;
          _nextLikeC = null;
          _nextLikeLoopC = null;

          _ready = true;

          // like 종료 → like_loop 전환
          _likeEndListener = () {
            final v = _likeC?.value;
            if (v == null) return;
            if (v.isInitialized && !v.isPlaying && v.position >= v.duration) {
              _switchActive(_ActiveLayer.likeLoop);
            }
          };
          _likeC!.addListener(_likeEndListener!);

          // 5) 점프 레이어로 전환(재생 포함)
          _switchActive(jumpTo);

          // 6) 기존 세트 정리
          _disposeSet(oldCur, oldLike, oldLoop);

          if (mounted) setState(() {});
        });

    return _initFuture!;
  }

  Future<void> _playOnly(VideoPlayerController? target) async {
    if (target == null) return;
    final all = <VideoPlayerController?>[_curiousC, _likeC, _likeLoopC];
    for (final c in all) {
      if (c == null) continue;
      if (c == target) {
        if (!c.value.isPlaying) await c.play();
      } else {
        if (c.value.isPlaying) await c.pause();
        await c.seekTo(Duration.zero);
      }
    }
  }

  void _switchActive(_ActiveLayer layer) async {
    _active = layer;
    if (!mounted || !_ready) {
      setState(() {});
      return;
    }
    switch (layer) {
      case _ActiveLayer.curious:
        await _playOnly(_curiousC);
        break;
      case _ActiveLayer.like:
        await _playOnly(_likeC);
        break;
      case _ActiveLayer.likeLoop:
        await _playOnly(_likeLoopC);
        break;
    }
    if (mounted) setState(() {});
  }

  void _replayShine() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _shine.replay();
    });
  }

  @override
  Widget build(BuildContext context) {
    const baseW = 1920.0, baseH = 1080.0;
    final sz = MediaQuery.of(context).size;
    final scale = (sz.width / baseW).clamp(0.0, sz.height / baseH);
    final canvas = Size(baseW * scale, baseH * scale);
    final left = (sz.width - canvas.width) / 2;
    final top = (sz.height - canvas.height) / 2;

    Widget videoBox(VideoPlayerController? c) {
      if (c == null || !c.value.isInitialized) return const SizedBox.shrink();
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: c.value.size.width,
          height: c.value.size.height,
          child: VideoPlayer(c),
        ),
      );
    }

    final ready =
        _ready &&
        _curiousC?.value.isInitialized == true &&
        _likeC?.value.isInitialized == true &&
        _likeLoopC?.value.isInitialized == true &&
        _trayImage != null &&
        _wholeImage != null &&
        _sliceImage != null &&
        (_bgImage is AssetImage);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onCanvasTap,
      child: Stack(
        children: [
          // BG
          if (ready)
            Positioned.fill(
              child: Image(image: _bgImage, fit: BoxFit.cover),
            )
          else
            const Positioned.fill(child: ColoredBox(color: Colors.black)),

          if (!ready)
            const Center(child: CircularProgressIndicator())
          else ...[
            // like_loop(하단) → like(중단) → curious(상단)
            Positioned.fromRect(
              rect: Rect.fromLTWH(left, top, canvas.width, canvas.height),
              child: Visibility(
                visible: _active == _ActiveLayer.likeLoop,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: videoBox(_likeLoopC),
              ),
            ),
            Positioned.fromRect(
              rect: Rect.fromLTWH(left, top, canvas.width, canvas.height),
              child: Visibility(
                visible: _active == _ActiveLayer.like,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: videoBox(_likeC),
              ),
            ),
            Positioned.fromRect(
              rect: Rect.fromLTWH(left, top, canvas.width, canvas.height),
              child: Visibility(
                visible: _active == _ActiveLayer.curious,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: videoBox(_curiousC),
              ),
            ),
          ],

          // 트레이
          if (ready)
            Positioned.fill(
              child: Image(image: _trayImage!, fit: BoxFit.cover),
            ),

          // 샤인 + 과일
          if (ready)
            ShineEmphasis(
              controller: _shine,
              imagePath: widget.isSlice
                  ? learnHalfPath(widget.fruit)
                  : learnNormalPath(widget.fruit),
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
