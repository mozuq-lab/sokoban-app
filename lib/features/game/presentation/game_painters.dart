import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 盤面上のプレイヤーを描画するウィジェット。
///
/// テスト等で `find.byType(PlayerWidget)` として検索可能。
class PlayerWidget extends StatelessWidget {
  const PlayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: const _PlayerPainter());
  }
}

/// 盤面上の箱を描画するウィジェット。
///
/// [onGoal] が true のときはゴール配置済みの見た目になる。
/// テスト等で `find.byType(BoxWidget)` として検索可能。
class BoxWidget extends StatelessWidget {
  const BoxWidget({super.key, this.onGoal = false});

  final bool onGoal;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CratePainter(onGoal: onGoal));
  }
}

/// 盤面上のゴールマーカーを描画するウィジェット。
class GoalMarkerWidget extends StatelessWidget {
  const GoalMarkerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: const _GoalMarkerPainter());
  }
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

/// プレイヤー（倉庫番の作業員）を描画する。
///
/// 円形のゲームトークン風。上部にハイライト、中央に顔を描く。
class _PlayerPainter extends CustomPainter {
  const _PlayerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = math.min(w, h) * 0.42;

    // --- 影 ---
    canvas.drawCircle(
      Offset(cx + r * 0.06, cy + r * 0.10),
      r,
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // --- 本体（グラデーション円） ---
    final bodyRect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.40),
          radius: 1.1,
          colors: [
            const Color(0xFF5C9CE6), // 明るい青
            const Color(0xFF2B6CB0), // 中間
            const Color(0xFF1A4D80), // 暗い青
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(bodyRect),
    );

    // --- 外枠 ---
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..color = const Color(0xFF163D5C),
    );

    // --- ハイライト弧 ---
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.10
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x55FFFFFF);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.78),
      -math.pi * 0.85,
      math.pi * 0.55,
      false,
      highlightPaint,
    );

    // --- 帽子 ---
    final capColor = const Color(0xFFD04040);
    final capDark = const Color(0xFF9E2020);
    // 帽子の本体
    final capPath = Path()
      ..moveTo(cx - r * 0.52, cy - r * 0.18)
      ..quadraticBezierTo(cx - r * 0.45, cy - r * 0.70, cx, cy - r * 0.72)
      ..quadraticBezierTo(cx + r * 0.45, cy - r * 0.70, cx + r * 0.52, cy - r * 0.18)
      ..close();
    canvas.drawPath(
      capPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [capColor, capDark],
        ).createShader(Rect.fromLTWH(cx - r * 0.5, cy - r * 0.75, r, r * 0.6)),
    );
    // つば
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - r * 0.15), width: r * 1.2, height: r * 0.14),
        Radius.circular(r * 0.07),
      ),
      Paint()..color = capDark,
    );

    // --- 顔 ---
    // 肌色ベース
    canvas.drawCircle(
      Offset(cx, cy + r * 0.10),
      r * 0.38,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.3),
          colors: [
            const Color(0xFFF8D8B0), // ハイライト肌色
            const Color(0xFFDEA970), // 肌色
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(cx, cy + r * 0.10), radius: r * 0.38),
        ),
    );

    // 目
    final eyePaint = Paint()..color = const Color(0xFF1A1A2E);
    canvas.drawCircle(Offset(cx - r * 0.15, cy + r * 0.04), r * 0.055, eyePaint);
    canvas.drawCircle(Offset(cx + r * 0.15, cy + r * 0.04), r * 0.055, eyePaint);

    // 目のハイライト
    final eyeHighlight = Paint()..color = const Color(0xCCFFFFFF);
    canvas.drawCircle(Offset(cx - r * 0.13, cy + r * 0.02), r * 0.025, eyeHighlight);
    canvas.drawCircle(Offset(cx + r * 0.17, cy + r * 0.02), r * 0.025, eyeHighlight);

    // 口（小さなカーブ）
    final mouthPath = Path()
      ..moveTo(cx - r * 0.10, cy + r * 0.20)
      ..quadraticBezierTo(cx, cy + r * 0.28, cx + r * 0.10, cy + r * 0.20);
    canvas.drawPath(
      mouthPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.04
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF8B4513),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 木箱を描画する。[onGoal] で配置済みの見た目に変わる。
class _CratePainter extends CustomPainter {
  const _CratePainter({this.onGoal = false});

  final bool onGoal;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final inset = math.min(w, h) * 0.08;
    final rect = Rect.fromLTWH(inset, inset, w - inset * 2, h - inset * 2);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.08));
    final innerW = rect.width;
    final innerH = rect.height;

    // 色テーマ
    final Color topLeft;
    final Color bottomRight;
    final Color borderColor;
    final Color plankColor;
    final Color highlightColor;

    if (onGoal) {
      topLeft = const Color(0xFF5DAA68);
      bottomRight = const Color(0xFF2E7D32);
      borderColor = const Color(0xFF1B5E20);
      plankColor = const Color(0xFF4CAF50);
      highlightColor = const Color(0x44FFFFFF);
    } else {
      topLeft = const Color(0xFFD4A054);
      bottomRight = const Color(0xFF8B6914);
      borderColor = const Color(0xFF5C4003);
      plankColor = const Color(0xFFC08830);
      highlightColor = const Color(0x33FFFFFF);
    }

    // --- 影 ---
    canvas.drawRRect(
      rr.shift(const Offset(1.5, 2.5)),
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    // --- 本体（グラデーション） ---
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [topLeft, bottomRight],
        ).createShader(rect),
    );

    // --- 木目の横線 ---
    final grainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = borderColor.withValues(alpha: 0.2);
    for (var i = 1; i <= 3; i++) {
      final y = rect.top + innerH * (i / 4.0);
      canvas.drawLine(
        Offset(rect.left + innerW * 0.05, y),
        Offset(rect.right - innerW * 0.05, y),
        grainPaint,
      );
    }

    // --- 十字の板張り ---
    final plankPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = innerW * 0.06
      ..strokeCap = StrokeCap.round
      ..color = plankColor;

    // 横板
    canvas.drawLine(
      Offset(rect.left + innerW * 0.12, rect.top + innerH * 0.50),
      Offset(rect.right - innerW * 0.12, rect.top + innerH * 0.50),
      plankPaint,
    );
    // 縦板
    canvas.drawLine(
      Offset(rect.left + innerW * 0.50, rect.top + innerH * 0.12),
      Offset(rect.left + innerW * 0.50, rect.bottom - innerH * 0.12),
      plankPaint,
    );

    // --- ベベルハイライト（上・左辺） ---
    final bevelPath = Path()
      ..moveTo(rect.left + w * 0.08, rect.bottom - innerH * 0.05)
      ..lineTo(rect.left + w * 0.08, rect.top + innerH * 0.05)
      ..quadraticBezierTo(rect.left + w * 0.08, rect.top, rect.left + innerW * 0.08, rect.top)
      ..lineTo(rect.right - innerW * 0.05, rect.top);
    canvas.drawPath(
      bevelPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = innerW * 0.05
        ..strokeCap = StrokeCap.round
        ..color = highlightColor,
    );

    // --- 外枠 ---
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = innerW * 0.05
        ..color = borderColor,
    );

    // --- 四隅の鋲 ---
    final nailPaint = Paint()..color = borderColor;
    final nailHighlight = Paint()..color = highlightColor;
    final nailR = innerW * 0.045;
    final nailPositions = [
      Offset(rect.left + innerW * 0.18, rect.top + innerH * 0.18),
      Offset(rect.right - innerW * 0.18, rect.top + innerH * 0.18),
      Offset(rect.left + innerW * 0.18, rect.bottom - innerH * 0.18),
      Offset(rect.right - innerW * 0.18, rect.bottom - innerH * 0.18),
    ];
    for (final pos in nailPositions) {
      canvas.drawCircle(pos, nailR, nailPaint);
      canvas.drawCircle(Offset(pos.dx - nailR * 0.3, pos.dy - nailR * 0.3), nailR * 0.35, nailHighlight);
    }

    // --- ゴール配置時のチェック印 ---
    if (onGoal) {
      final checkPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = innerW * 0.10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xDDFFFFFF);
      final checkPath = Path()
        ..moveTo(rect.left + innerW * 0.28, rect.top + innerH * 0.52)
        ..lineTo(rect.left + innerW * 0.44, rect.top + innerH * 0.68)
        ..lineTo(rect.left + innerW * 0.72, rect.top + innerH * 0.32);
      canvas.drawPath(checkPath, checkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CratePainter oldDelegate) =>
      onGoal != oldDelegate.onGoal;
}

/// ゴールマーカー（床に描かれたひし形ターゲット）を描画する。
class _GoalMarkerPainter extends CustomPainter {
  const _GoalMarkerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = math.min(w, h) * 0.34;

    // 外側のひし形（薄い影）
    _drawDiamond(canvas, cx, cy, r * 1.08, Paint()..color = const Color(0x18000000));

    // 外側のひし形
    _drawDiamond(
      canvas,
      cx,
      cy,
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF66BB6A),
            const Color(0xFF388E3C),
          ],
        ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2)),
    );

    // 外枠
    _drawDiamond(
      canvas,
      cx,
      cy,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.10
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF2E7D32),
    );

    // 内側のひし形
    _drawDiamond(
      canvas,
      cx,
      cy,
      r * 0.50,
      Paint()..color = const Color(0xFFA5D6A7),
    );

    // 中心の点
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.12,
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }

  void _drawDiamond(Canvas canvas, double cx, double cy, double r, Paint paint) {
    final path = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r, cy)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r, cy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
