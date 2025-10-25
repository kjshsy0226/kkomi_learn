import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'utils/window_fit.dart';
import 'screens/splash_screen.dart';

/// ─────────────────────────────────────────────────────────────────
/// 데스크톱 앱 시작 흐름:
///  - window_manager 초기화
///  - 창 옵션 설정(제목/배경/센터링/풀스크린 해제)
///  - **fitWindowToDisplay()**로 16:9 & 화면맞춤 사이즈 적용
///  - 창 표시(show) + 포커스(focus)
///  - (선택) 이후 F11 / Alt+Enter / ESC / macOS Ctrl+Cmd+F 핫키로
///    풀스크린 토글/해제 지원
/// ─────────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) window_manager 초기화 (데스크톱 창 제어를 위해 필수)
  await windowManager.ensureInitialized();

  // 2) 창 기본 옵션(최초 표시는 창 모드, 검은 배경, 중앙 정렬)
  const opts = WindowOptions(
    title: '꼬미와 알록달록 채소 과일',
    backgroundColor: Colors.black, // 투명은 OS/테마에 따라 아티팩트 발생 가능
    center: true,
    fullScreen: false,
  );

  // 3) 창을 실제로 보여주기 직전에 사이즈/위치 조정
  windowManager.waitUntilReadyToShow(opts, () async {
    // (핵심) 작업 영역에 맞춰 16:9로 리사이즈 + 중앙정렬
    await fitWindowToDisplay();

    // 창 표시 & 포커스
    await windowManager.show();
    await windowManager.focus();

    // ※ 자동으로 풀스크린 진입시키고 싶다면 아래 주석 해제
    await Future.delayed(const Duration(milliseconds: 120));
    // 풀스크린에서는 비율 고정(setAspectRatio)이 의미 없을 수 있어 0으로 해제
    await windowManager.setAspectRatio(0);
    await windowManager.setFullScreen(true);
  });

  runApp(const BaseApp());
}

class BaseApp extends StatelessWidget {
  const BaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '꼬미와 알록달록 채소 과일',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      // 전역 핫키(F11/Alt+Enter/ESC 등) 처리용 래퍼
      builder: (context, child) =>
          HotkeyGlobal(child: child ?? const SizedBox()),
      home: const SplashScreen(),
    );
  }
}

/// 앱 전역 핫키 위젯
/// - ESC: 풀스크린 해제 + 창 모드에서 화면맞춤 리핏
/// - F11: 풀스크린 토글(Windows/macOS/Linux 공통)
/// - Alt+Enter: 풀스크린 토글(Windows/Linux)
/// - Ctrl+Cmd+F: 풀스크린 토글(macOS 전통 단축키)
class HotkeyGlobal extends StatefulWidget {
  final Widget child;
  const HotkeyGlobal({super.key, required this.child});

  @override
  State<HotkeyGlobal> createState() => _HotkeyGlobalState();
}

class _HotkeyGlobalState extends State<HotkeyGlobal> {
  /// 풀스크린 <-> 창 모드 토글
  Future<void> _toggleFullscreen() async {
    final isFull = await windowManager.isFullScreen();
    if (isFull) {
      // 풀스크린 → 창 모드 전환 후, 화면맞춤으로 예쁘게 리핏
      await windowManager.setFullScreen(false);
      await fitWindowToDisplay();
    } else {
      // 창 모드 → 풀스크린 전환 전 비율 고정 해제(플랫폼 따라 무시될 수 있음)
      await windowManager.setAspectRatio(0);
      await windowManager.setFullScreen(true);
    }
  }

  /// 풀스크린이면 해제하고 창 모드 화면맞춤
  Future<void> _exitFullscreenIfNeeded() async {
    if (await windowManager.isFullScreen()) {
      await windowManager.setFullScreen(false);
      await fitWindowToDisplay();
    }
  }

  /// 키 이벤트 핸들러
  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;

    bool isPressed(LogicalKeyboardKey k) => pressed.contains(k);
    final isAlt =
        isPressed(LogicalKeyboardKey.altLeft) ||
        isPressed(LogicalKeyboardKey.altRight) ||
        isPressed(LogicalKeyboardKey.alt);
    final isMeta =
        isPressed(LogicalKeyboardKey.metaLeft) ||
        isPressed(LogicalKeyboardKey.metaRight) ||
        isPressed(LogicalKeyboardKey.meta);
    final isCtrl =
        isPressed(LogicalKeyboardKey.controlLeft) ||
        isPressed(LogicalKeyboardKey.controlRight) ||
        isPressed(LogicalKeyboardKey.control);

    // ESC → 풀스크린 해제 + 창 모드 화면맞춤
    if (key == LogicalKeyboardKey.escape) {
      _exitFullscreenIfNeeded();
      return true;
    }

    // F11 → 풀스크린 토글
    if (key == LogicalKeyboardKey.f11) {
      _toggleFullscreen();
      return true;
    }

    // Alt+Enter → 풀스크린 토글 (Windows/Linux)
    if (isAlt && key == LogicalKeyboardKey.enter) {
      _toggleFullscreen();
      return true;
    }

    // macOS: Ctrl+Cmd+F → 풀스크린 토글
    if (isMeta && isCtrl && key == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
      return true;
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
