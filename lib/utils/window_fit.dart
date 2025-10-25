import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

/// ─────────────────────────────────────────────────────────────────
/// 데스크톱(Windows/macOS/Linux) 환경에서 **창 모드**일 때
/// - 화면의 작업 영역(work area)에 **맞추어**
/// - **16:9 비율**을 유지하며
/// - **최대 1920×1080**(기본값)을 상한으로
/// 창 크기를 자동 조절하고 중앙 정렬합니다.
///
/// 사용처:
/// 1) 앱 시작 직후 최초 표시 전에 1회 호출 (권장)
/// 2) 풀스크린을 해제(Escape 등)할 때 창 모드로 돌아오며 재호출
///
/// 참고:
/// - 풀스크린 상태에서는 사이즈/비율 조정이 무시될 수 있으므로
///   본 함수는 내부에서 **풀스크린을 해제**한 뒤 진행합니다.
/// ─────────────────────────────────────────────────────────────────

/// 화면에 맞춰 창 크기를 16:9로 맞추고 중앙 정렬한다.
///
/// [base]는 상한(최대) 크기. 기본 1920×1080.
///  - 실제 적용 크기 = min(base, 가용 화면 크기)를 16:9로 보정한 값.
Future<void> fitWindowToDisplay({Size base = const Size(1920, 1080)}) async {
  // 1) 현재 기본(주) 디스플레이의 "작업 영역(도킹/메뉴바 제외)" 크기를 가져온다.
  final display = await screenRetriever.getPrimaryDisplay();
  final availW = display.visibleSize?.width.toDouble();
  final availH = display.visibleSize?.height.toDouble();
  if (availW == null || availH == null) return;

  // 2) 16:9 비율로 목표 크기를 계산한다. (상한: base, 하한: 가용 화면)
  const aspect = 16 / 9;
  double targetW = math.min(base.width, availW);
  double targetH = targetW / aspect;

  // 3) 세로가 넘치면 세로를 맞추고 가로를 다시 계산
  if (targetH > availH) {
    targetH = availH;
    targetW = targetH * aspect;
  }

  // 4) 풀스크린이면 먼저 해제 → 비율 고정 → 크기 적용 → 중앙정렬
  await windowManager.setFullScreen(false);
  await windowManager.setAspectRatio(aspect); // 창 모드에서만 의미 있음
  await windowManager.setSize(Size(targetW, targetH));
  await windowManager.center();
}
