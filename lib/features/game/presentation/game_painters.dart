import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/direction.dart';

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

/// ゴールマーカー（床に描かれた同心円ターゲット）を描画する。
class _GoalMarkerPainter extends CustomPainter {
  const _GoalMarkerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = math.min(w, h) * 0.34;

    // 外側リング（薄い影）
    canvas.drawCircle(
      Offset(cx + r * 0.04, cy + r * 0.06),
      r,
      Paint()
        ..color = const Color(0x18000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // 外側リング
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.22
        ..color = const Color(0xFF43A047),
    );

    // 中間リング
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.58,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.16
        ..color = const Color(0xFF66BB6A),
    );

    // 中心の丸
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.22,
      Paint()..color = const Color(0xFF81C784),
    );

    // 十字線（照準風）
    final crossPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.06
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x442E7D32);
    // 上
    canvas.drawLine(Offset(cx, cy - r * 1.1), Offset(cx, cy - r * 0.40), crossPaint);
    // 下
    canvas.drawLine(Offset(cx, cy + r * 0.40), Offset(cx, cy + r * 1.1), crossPaint);
    // 左
    canvas.drawLine(Offset(cx - r * 1.1, cy), Offset(cx - r * 0.40, cy), crossPaint);
    // 右
    canvas.drawLine(Offset(cx + r * 0.40, cy), Offset(cx + r * 1.1, cy), crossPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 壁セルを描画する（レンガ調テクスチャ）。
class WallPainter extends CustomPainter {
  const WallPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // ベース色
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6D4C41), Color(0xFF4E342E)],
        ).createShader(rect),
    );

    // レンガ模様
    final mortarPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..color = const Color(0xFF3E2723);
    final brickH = h / 3;

    // 横目地
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(Offset(0, brickH * i), Offset(w, brickH * i), mortarPaint);
    }

    // 縦目地（互い違い）
    for (var row = 0; row < 3; row++) {
      final y0 = brickH * row;
      final y1 = y0 + brickH;
      final offset = (row % 2 == 0) ? 0.0 : w * 0.5;
      for (var bx = offset; bx < w; bx += w) {
        if (bx > 0 && bx < w) {
          canvas.drawLine(Offset(bx, y0), Offset(bx, y1), mortarPaint);
        }
      }
      // 中間の縦目地
      final mid = offset + w * 0.5;
      if (mid > 0 && mid < w) {
        canvas.drawLine(Offset(mid, y0), Offset(mid, y1), mortarPaint);
      }
    }

    // 各レンガにハイライト
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..color = const Color(0x20FFFFFF);
    for (var row = 0; row < 3; row++) {
      final y0 = brickH * row;
      final offset = (row % 2 == 0) ? 0.0 : w * 0.5;
      // 上辺ハイライト
      canvas.drawLine(
        Offset(math.max(0, offset) + w * 0.02, y0 + w * 0.03),
        Offset(math.min(w, offset + w) - w * 0.02, y0 + w * 0.03),
        highlightPaint,
      );
    }

    // 外枠
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = const Color(0xFF3E2723),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 床セルを描画する（タイル調テクスチャ）。
class FloorPainter extends CustomPainter {
  const FloorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // ベース色
    canvas.drawRect(rect, Paint()..color = const Color(0xFFF5E6CC));

    // タイル溝（十字）
    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02
      ..color = const Color(0x18000000);
    // 下辺
    canvas.drawLine(Offset(0, h - 0.5), Offset(w, h - 0.5), groovePaint);
    // 右辺
    canvas.drawLine(Offset(w - 0.5, 0), Offset(w - 0.5, h), groovePaint);

    // 微妙な内側ハイライト（左上角）
    final hlPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02
      ..color = const Color(0x0AFFFFFF);
    canvas.drawLine(Offset(0.5, 0.5), Offset(w * 0.8, 0.5), hlPaint);
    canvas.drawLine(Offset(0.5, 0.5), Offset(0.5, h * 0.8), hlPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 方向パッドの矢印ボタン内にシェブロン（くの字）を描画する。
///
/// 塗りつぶし三角形ではなく、丸いストロークキャップのシェブロン線を使い、
/// 軽く洗練された印象にする。
class ArrowPainter extends CustomPainter {
  const ArrowPainter({required this.direction, required this.color});

  final Direction direction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final s = math.min(w, h) * 0.28;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.min(w, h) * 0.065
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    switch (direction) {
      case Direction.up:
        path.moveTo(cx - s * 0.8, cy + s * 0.45);
        path.lineTo(cx, cy - s * 0.45);
        path.lineTo(cx + s * 0.8, cy + s * 0.45);
      case Direction.down:
        path.moveTo(cx - s * 0.8, cy - s * 0.45);
        path.lineTo(cx, cy + s * 0.45);
        path.lineTo(cx + s * 0.8, cy - s * 0.45);
      case Direction.left:
        path.moveTo(cx + s * 0.45, cy - s * 0.8);
        path.lineTo(cx - s * 0.45, cy);
        path.lineTo(cx + s * 0.45, cy + s * 0.8);
      case Direction.right:
        path.moveTo(cx - s * 0.45, cy - s * 0.8);
        path.lineTo(cx + s * 0.45, cy);
        path.lineTo(cx - s * 0.45, cy + s * 0.8);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ArrowPainter oldDelegate) =>
      direction != oldDelegate.direction || color != oldDelegate.color;
}

/// 手数カウントのアイコン（階段状の歩数パス）を描画する。
class MoveCountIconPainter extends CustomPainter {
  const MoveCountIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 階段状のパス（歩数を表す）
    final path = Path()
      ..moveTo(w * 0.15, h * 0.82)
      ..lineTo(w * 0.15, h * 0.55)
      ..lineTo(w * 0.45, h * 0.55)
      ..lineTo(w * 0.45, h * 0.28)
      ..lineTo(w * 0.72, h * 0.28);
    canvas.drawPath(path, paint);

    // 矢印の先端
    final arrowPaint = Paint()..color = color;
    final arrow = Path()
      ..moveTo(w * 0.82, h * 0.28)
      ..lineTo(w * 0.66, h * 0.17)
      ..lineTo(w * 0.66, h * 0.39)
      ..close();
    canvas.drawPath(arrow, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant MoveCountIconPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// 配置状況のアイコン（ターゲットマーク）を描画する。
class PlacementIconPainter extends CustomPainter {
  const PlacementIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = math.min(w, h) * 0.38;

    // 外側リング
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.22
        ..color = color,
    );

    // 内側リング
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.52,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.16
        ..color = color.withValues(alpha: 0.7),
    );

    // 中心の丸
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.18,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant PlacementIconPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// 元に戻すアイコン（カーブした戻り矢印）を描画する。
class UndoIconPainter extends CustomPainter {
  const UndoIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.12
      ..strokeCap = StrokeCap.round;

    // カーブした矢印（左向き戻り）
    final path = Path()
      ..moveTo(w * 0.65, h * 0.28)
      ..arcToPoint(
        Offset(w * 0.35, h * 0.28),
        radius: Radius.circular(w * 0.24),
        clockwise: false,
      )
      ..lineTo(w * 0.35, h * 0.68);
    canvas.drawPath(path, paint);

    // 矢印の先端
    final arrowPaint = Paint()..color = color;
    final arrow = Path()
      ..moveTo(w * 0.22, h * 0.28)
      ..lineTo(w * 0.38, h * 0.14)
      ..lineTo(w * 0.38, h * 0.42)
      ..close();
    canvas.drawPath(arrow, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant UndoIconPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// リスタートアイコン（円形の回転矢印）を描画する。
class RestartIconPainter extends CustomPainter {
  const RestartIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = math.min(w, h) * 0.34;

    // 円弧（270度）
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.30
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi * 0.5,
      math.pi * 1.5,
      false,
      paint,
    );

    // 矢印の先端（上向き）
    final arrowPaint = Paint()..color = color;
    final arrow = Path()
      ..moveTo(cx, cy - r - r * 0.32)
      ..lineTo(cx - r * 0.38, cy - r + r * 0.18)
      ..lineTo(cx + r * 0.38, cy - r + r * 0.18)
      ..close();
    canvas.drawPath(arrow, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant RestartIconPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// アプリロゴアイコン（箱とゴールを組み合わせた倉庫番モチーフ）を描画する。
class SokobanLogoPainter extends CustomPainter {
  const SokobanLogoPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // --- ゴールマーカー（背景の同心円） ---
    final cx = w * 0.52;
    final cy = h * 0.48;
    final r = math.min(w, h) * 0.38;
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.18
        ..color = color.withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.50,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14
        ..color = color.withValues(alpha: 0.18),
    );

    // --- 箱（手前に重ねた角丸四角） ---
    final boxSize = math.min(w, h) * 0.48;
    final boxRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: boxSize,
      height: boxSize,
    );
    final rr = RRect.fromRectAndRadius(boxRect, Radius.circular(boxSize * 0.12));

    // 箱の塗り
    canvas.drawRRect(rr, Paint()..color = color.withValues(alpha: 0.85));

    // 箱の十字
    final crossPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = boxSize * 0.07
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.6);
    canvas.drawLine(
      Offset(boxRect.left + boxSize * 0.22, cy),
      Offset(boxRect.right - boxSize * 0.22, cy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(cx, boxRect.top + boxSize * 0.22),
      Offset(cx, boxRect.bottom - boxSize * 0.22),
      crossPaint,
    );

    // 箱の外枠
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = boxSize * 0.06
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant SokobanLogoPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// トロフィーアイコンを描画する。
class TrophyIconPainter extends CustomPainter {
  const TrophyIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final lighterColor = Color.lerp(color, Colors.white, 0.3) ?? color;

    // --- カップ本体 ---
    final cupPath = Path()
      ..moveTo(w * 0.22, h * 0.15)
      ..lineTo(w * 0.78, h * 0.15)
      ..lineTo(w * 0.70, h * 0.52)
      ..quadraticBezierTo(w * 0.50, h * 0.68, w * 0.30, h * 0.52)
      ..close();
    canvas.drawPath(
      cupPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lighterColor, color],
        ).createShader(Rect.fromLTWH(w * 0.22, h * 0.15, w * 0.56, h * 0.53)),
    );

    // --- 取っ手（左右） ---
    final handlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round
      ..color = color;
    // 左取っ手
    final leftHandle = Path()
      ..moveTo(w * 0.24, h * 0.22)
      ..quadraticBezierTo(w * 0.08, h * 0.30, w * 0.18, h * 0.44);
    canvas.drawPath(leftHandle, handlePaint);
    // 右取っ手
    final rightHandle = Path()
      ..moveTo(w * 0.76, h * 0.22)
      ..quadraticBezierTo(w * 0.92, h * 0.30, w * 0.82, h * 0.44);
    canvas.drawPath(rightHandle, handlePaint);

    // --- ハイライト ---
    final hlPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.45);
    canvas.drawLine(
      Offset(w * 0.34, h * 0.24),
      Offset(w * 0.36, h * 0.42),
      hlPaint,
    );

    // --- 台座の柱 ---
    canvas.drawLine(
      Offset(w * 0.50, h * 0.58),
      Offset(w * 0.50, h * 0.72),
      Paint()
        ..color = color
        ..strokeWidth = w * 0.08
        ..strokeCap = StrokeCap.round,
    );

    // --- 台座 ---
    final basePath = Path()
      ..moveTo(w * 0.30, h * 0.72)
      ..lineTo(w * 0.70, h * 0.72)
      ..lineTo(w * 0.74, h * 0.82)
      ..lineTo(w * 0.26, h * 0.82)
      ..close();
    canvas.drawPath(basePath, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant TrophyIconPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// パズルセクション見出しアイコン（小さなグリッド盤面）を描画する。
class PuzzleSectionIconPainter extends CustomPainter {
  const PuzzleSectionIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final inset = math.min(w, h) * 0.12;
    final cellW = (w - inset * 2) / 3;
    final cellH = (h - inset * 2) / 3;

    // 3x3 グリッドのセルを描く
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        final rect = Rect.fromLTWH(
          inset + col * cellW + 1,
          inset + row * cellH + 1,
          cellW - 2,
          cellH - 2,
        );
        final isHighlighted = (row == 1 && col == 1) || (row == 2 && col == 2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cellW * 0.15)),
          Paint()
            ..color = isHighlighted
                ? color.withValues(alpha: 0.8)
                : color.withValues(alpha: 0.35),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant PuzzleSectionIconPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// 操作セクション見出しアイコン（十字キーパッド）を描画する。
class ControlSectionIconPainter extends CustomPainter {
  const ControlSectionIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final arm = math.min(w, h) * 0.20;
    final thick = arm * 0.85;
    final r = arm * 0.15;

    // 十字の横棒
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: arm * 3, height: thick),
        Radius.circular(r),
      ),
      Paint()..color = color.withValues(alpha: 0.55),
    );

    // 十字の縦棒
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: thick, height: arm * 3),
        Radius.circular(r),
      ),
      Paint()..color = color.withValues(alpha: 0.55),
    );

    // 中央の丸ボタン
    canvas.drawCircle(
      Offset(cx, cy),
      arm * 0.32,
      Paint()..color = color.withValues(alpha: 0.8),
    );

    // 三角矢印（上）
    final arrowSize = arm * 0.30;
    final arrowColor = Colors.white.withValues(alpha: 0.7);
    // 上
    _drawTriangle(canvas, Offset(cx, cy - arm * 1.10), arrowSize, 0, arrowColor);
    // 下
    _drawTriangle(canvas, Offset(cx, cy + arm * 1.10), arrowSize, math.pi, arrowColor);
    // 左
    _drawTriangle(canvas, Offset(cx - arm * 1.10, cy), arrowSize, -math.pi / 2, arrowColor);
    // 右
    _drawTriangle(canvas, Offset(cx + arm * 1.10, cy), arrowSize, math.pi / 2, arrowColor);
  }

  void _drawTriangle(Canvas canvas, Offset center, double s, double angle, Color color) {
    final path = Path()
      ..moveTo(0, -s)
      ..lineTo(s * 0.75, s * 0.5)
      ..lineTo(-s * 0.75, s * 0.5)
      ..close();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ControlSectionIconPainter oldDelegate) =>
      color != oldDelegate.color;
}
