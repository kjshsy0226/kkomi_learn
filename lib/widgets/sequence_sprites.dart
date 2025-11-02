import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:audioplayers/audioplayers.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// 배치 도우미: 부모 Stack 좌표(position)에 child를 배치.
/// anchor가 center면 (x,y)를 child의 중심으로 간주.
class AnchoredBox extends StatelessWidget {
  final Widget child;
  final Offset position; // 부모 Stack 좌표(px)
  final Anchor anchor; // topLeft | center
  final Size? size; // 고정 크기 (없으면 child 본래 크기)

  const AnchoredBox({
    super.key,
    required this.child,
    required this.position,
    this.anchor = Anchor.topLeft,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final w = size?.width ?? 0;
    final h = size?.height ?? 0;
    final dx = anchor == Anchor.center ? position.dx - w / 2 : position.dx;
    final dy = anchor == Anchor.center ? position.dy - h / 2 : position.dy;
    return Positioned(
      left: dx,
      top: dy,
      width: w == 0 ? null : w,
      height: h == 0 ? null : h,
      child: size == null ? child : SizedBox(width: w, height: h, child: child),
    );
  }
}

enum Anchor { topLeft, center }

/// ─────────────────────────────────────────────────────────────────────────
/// 1) 이미지 시퀀스 전용 위젯
class SequenceSprite extends StatefulWidget {
  final SequenceController controller;
  final List<String> assetPaths; // 예: ['assets/..._000.png', ...]
  final double fps; // 초당 프레임
  final bool loop; // 반복 재생
  final bool autoplay; // 렌더 직후 자동 재생
  final bool holdLastFrameWhenFinished; // 1회 재생 시 마지막 프레임 유지
  final bool precache; // 재생 전 전부 로드
  final BoxFit fit;
  final bool gaplessPlayback;

  const SequenceSprite({
    super.key,
    required this.controller,
    required this.assetPaths,
    this.fps = 24,
    this.loop = false,
    this.autoplay = false,
    this.holdLastFrameWhenFinished = true,
    this.precache = false,
    this.fit = BoxFit.contain,
    this.gaplessPlayback = true,
  });

  @override
  State<SequenceSprite> createState() => _SequenceSpriteState();
}

class _SequenceSpriteState extends State<SequenceSprite> {
  late int _frameCount;
  int _index = 0;
  Timer? _timer;
  bool _isPlaying = false;

  // 프리캐시 & 자동재생 제어 플래그
  bool _didPrecache = false;
  bool _didAutoplayStart = false;

  List<ImageProvider>? _cache;

  Duration get _frameDur => Duration(microseconds: (1e6 / widget.fps).round());

  @override
  void initState() {
    super.initState();
    _frameCount = widget.assetPaths.length.clamp(0, 1 << 20);
    widget.controller._attach(this);
    // ⚠️ precache/자동재생은 MediaQuery 의존이 있으니 didChangeDependencies에서 처리
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 1) 프리캐시가 켜져 있고 아직 안 했다면, 여기서 진행
    if (widget.precache && !_didPrecache && _frameCount > 0) {
      _didPrecache = true;
      _precacheAll().whenComplete(() {
        if (mounted && widget.autoplay && !_didAutoplayStart) {
          _didAutoplayStart = true;
          start();
        }
      });
      return; // 프리캐시 완료 후 자동재생을 트리거하므로 여기서 종료
    }

    // 2) 프리캐시 사용 안 할 때 자동재생은 여기서 한 번만
    if (widget.autoplay && !_didAutoplayStart) {
      _didAutoplayStart = true;
      start();
    }
  }

  @override
  void didUpdateWidget(covariant SequenceSprite oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 에셋 목록/설정 변경 시 타이머 재설정
    final needRestartTimer =
        oldWidget.fps != widget.fps || oldWidget.loop != widget.loop;
    if (oldWidget.assetPaths != widget.assetPaths) {
      _frameCount = widget.assetPaths.length.clamp(0, 1 << 20);
      _index = _index.clamp(0, (_frameCount - 1).clamp(0, _frameCount)); // 안전
      _didPrecache = false; // 에셋 바뀌면 프리캐시 다시
    }

    if (needRestartTimer && _isPlaying) {
      // fps 변경 등의 경우 타이머 재시작
      _timer?.cancel();
      _timer = Timer.periodic(_frameDur, (_) => _tick());
    }
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _precacheAll() async {
    _cache = widget.assetPaths.map((p) => AssetImage(p)).toList();
    for (final p in _cache!) {
      if (!mounted) return;
      await precacheImage(p, context); // ← didChangeDependencies 이후 안전
    }
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _index++;
      if (_index >= _frameCount) {
        if (widget.loop) {
          _index = 0;
          widget.controller._notifyLoopRestart();
        } else {
          _index = widget.holdLastFrameWhenFinished ? _frameCount - 1 : 0;
          stop(resetToFirstFrame: !widget.holdLastFrameWhenFinished);
        }
      }
    });
  }

  // 외부 제어
  void start() {
    if (_frameCount == 0 || _isPlaying) return;
    _isPlaying = true;
    _timer?.cancel();
    _timer = Timer.periodic(_frameDur, (_) => _tick());
    if (mounted) setState(() {});
  }

  void stop({bool resetToFirstFrame = true}) {
    _timer?.cancel();
    _isPlaying = false;
    if (resetToFirstFrame) _index = 0;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_frameCount == 0) return const SizedBox.shrink();
    return Image.asset(
      widget.assetPaths[_index],
      fit: widget.fit,
      gaplessPlayback: widget.gaplessPlayback,
    );
  }
}

/// 컨트롤러: start/stop만 외부 노출
class SequenceController {
  _SequenceSpriteState? _state;
  VoidCallback? _onLoopRestart;

  void _attach(_SequenceSpriteState s) => _state = s;
  void _detach(_SequenceSpriteState s) {
    if (identical(_state, s)) _state = null;
  }

  void _notifyLoopRestart() => _onLoopRestart?.call();

  void start() => _state?.start();
  void stop({bool resetToFirstFrame = true}) =>
      _state?.stop(resetToFirstFrame: resetToFirstFrame);

  bool get isPlaying => _state?._isPlaying ?? false;
  int get frameIndex => _state?._index ?? 0;

  set onLoopRestart(VoidCallback? cb) => _onLoopRestart = cb;
}

/// ─────────────────────────────────────────────────────────────────────────
/// 2) 이미지 + 사운드 동시 재생 위젯
enum AudioSyncMode {
  none, // 오디오 사용 안 함
  followImageLoopRestart, // 이미지 루프 시작마다 오디오 0초로
  independentLoop, // 오디오는 완전 독립 loop
  oneShotPerPlay, // start() 호출 때 한 번만 재생
}

class SequenceSpriteAudio extends StatefulWidget {
  final SequenceAudioController controller;
  final List<String> assetPaths;
  final String? audioAsset; // 예: assets/audio/bgm/game_theme.wav (pubspec 등록)
  final AudioSyncMode audioSyncMode;

  final double fps;
  final bool loop;
  final bool autoplay; // 렌더링 즉시 start()
  final bool autoplayAudio; // 오디오 자동 시작
  final bool holdLastFrameWhenFinished;
  final bool precache;

  final double volume;
  final BoxFit fit;
  final bool gaplessPlayback;

  const SequenceSpriteAudio({
    super.key,
    required this.controller,
    required this.assetPaths,
    this.audioAsset,
    this.audioSyncMode = AudioSyncMode.none,
    this.fps = 24,
    this.loop = false,
    this.autoplay = false,
    this.autoplayAudio = true,
    this.holdLastFrameWhenFinished = true,
    this.precache = false,
    this.volume = 1.0,
    this.fit = BoxFit.contain,
    this.gaplessPlayback = true,
  });

  @override
  State<SequenceSpriteAudio> createState() => _SequenceSpriteAudioState();
}

class _SequenceSpriteAudioState extends State<SequenceSpriteAudio> {
  final SequenceController _imgCtrl = SequenceController();
  late final AudioPlayer _audio;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    _audio = AudioPlayer()..setVolume(widget.volume);
    _configureReleaseMode();

    // 이미지 루프 시작 이벤트 → 필요 시 오디오 리스타트
    _imgCtrl.onLoopRestart = () {
      if (widget.audioSyncMode == AudioSyncMode.followImageLoopRestart) {
        _playAudio(resetToZero: true);
      }
    };

    if (widget.autoplay) {
      // 오디오는 autoplayAudio, audioSyncMode에 따라 start()에서 처리
      start();
    }
  }

  void _configureReleaseMode() {
    switch (widget.audioSyncMode) {
      case AudioSyncMode.independentLoop:
        _audio.setReleaseMode(ReleaseMode.loop);
        break;
      default:
        _audio.setReleaseMode(ReleaseMode.stop);
        break;
    }
  }

  Future<void> _playAudio({required bool resetToZero}) async {
    if (widget.audioAsset == null) return;
    try {
      // audioplayers는 assets/ 루트 기준 경로를 받음 (pubspec에 등록 필요)
      final src = AssetSource(widget.audioAsset!.replaceFirst('assets/', ''));
      if (resetToZero) {
        await _audio.stop();
        await _audio.play(src);
      } else {
        // 아직 재생중이 아니면 시작
        final dur = await _audio.getDuration();
        if (dur == null) await _audio.play(src);
      }
    } catch (e) {
      // 에셋이 없거나 비었을 때 등
      // 무한 예외 방지용 로그만 남기고 무시
      // (원하면 debugPrint로 바꿔도 됨)
      // print('Audio play failed: $e');
    }
  }

  Future<void> _stopAudio() async {
    if (widget.audioAsset == null) return;
    try {
      await _audio.stop();
    } catch (_) {}
  }

  Future<void> start() async {
    _imgCtrl.start();

    if (!widget.autoplayAudio || widget.audioAsset == null) return;

    switch (widget.audioSyncMode) {
      case AudioSyncMode.none:
        break;
      case AudioSyncMode.followImageLoopRestart:
        await _playAudio(resetToZero: true);
        break;
      case AudioSyncMode.independentLoop:
        await _playAudio(resetToZero: false);
        break;
      case AudioSyncMode.oneShotPerPlay:
        await _playAudio(resetToZero: true);
        break;
    }
  }

  Future<void> stop() async {
    _imgCtrl.stop();
    if (widget.audioSyncMode != AudioSyncMode.none) {
      await _stopAudio();
    }
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SequenceSprite(
      controller: _imgCtrl,
      assetPaths: widget.assetPaths,
      fps: widget.fps,
      loop: widget.loop,
      autoplay: widget.autoplay,
      holdLastFrameWhenFinished: widget.holdLastFrameWhenFinished,
      precache: widget.precache,
      fit: widget.fit,
      gaplessPlayback: widget.gaplessPlayback,
    );
  }
}

/// 오디오 컨트롤러 (start/stop만 노출, 필요 시 오디오만 제어할 보조 메서드 포함)
class SequenceAudioController {
  _SequenceSpriteAudioState? _state;
  void _attach(_SequenceSpriteAudioState s) => _state = s;
  void _detach(_SequenceSpriteAudioState s) {
    if (identical(_state, s)) _state = null;
  }

  Future<void> start() async => _state?.start();
  Future<void> stop() async => _state?.stop();

  // 선택: 오디오만 따로 제어하고 싶을 때
  Future<void> startAudioOnly() async => _state?._playAudio(resetToZero: false);
  Future<void> stopAudioOnly() async => _state?._stopAudio();
}
