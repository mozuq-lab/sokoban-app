import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/direction.dart';
import '../domain/game_state.dart';
import 'game_painters.dart';

/// 固定 1 ステージの倉庫番プレイ画面。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialLevel});

  /// テスト等で直接レベルデータを渡す場合に使う。
  /// null の場合は asset から読み込む。
  final List<String>? initialLevel;

  /// asset のレベルファイルパス。
  static const String levelAssetPath = 'assets/levels/level_001.txt';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GameState? _gameState;
  late List<String> _levelLines;
  final List<GameState> _history = [];
  int _moveCount = 0;
  bool _moveBlocked = false;
  Timer? _blockedHintTimer;
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    if (widget.initialLevel != null) {
      _levelLines = widget.initialLevel!;
      _gameState = GameState.parse(_levelLines);
    } else {
      _loadLevelFromAsset();
    }
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
    }
  }

  Future<void> _loadLevelFromAsset() async {
    final text = await rootBundle.loadString(HomeScreen.levelAssetPath);
    final lines = const LineSplitter().convert(text);
    // 末尾の空行を除去
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    if (mounted) {
      setState(() {
        _levelLines = lines;
        _gameState = GameState.parse(_levelLines);
      });
    }
  }

  @override
  void dispose() {
    _blockedHintTimer?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  /// キーボードイベントを処理する。
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (_gameState == null) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final isCtrlOrMeta = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    // Undo: Ctrl+Z / Cmd+Z
    if (isCtrlOrMeta && key == LogicalKeyboardKey.keyZ) {
      _undo();
      return KeyEventResult.handled;
    }

    // Restart: R キー（修飾キーなし・履歴があるときのみ）
    if (!isCtrlOrMeta && key == LogicalKeyboardKey.keyR) {
      if (_history.isNotEmpty) {
        _restart();
      }
      return KeyEventResult.handled;
    }

    // 方向キー（クリア後は無効）
    final direction = _directionFromKey(key);
    if (direction != null) {
      if (!_gameState!.isSolved) {
        _move(direction);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// キーから方向を返す。対応しないキーは null。
  static Direction? _directionFromKey(LogicalKeyboardKey key) {
    // 矢印キー
    if (key == LogicalKeyboardKey.arrowUp) return Direction.up;
    if (key == LogicalKeyboardKey.arrowDown) return Direction.down;
    if (key == LogicalKeyboardKey.arrowLeft) return Direction.left;
    if (key == LogicalKeyboardKey.arrowRight) return Direction.right;
    // WASD
    if (key == LogicalKeyboardKey.keyW) return Direction.up;
    if (key == LogicalKeyboardKey.keyS) return Direction.down;
    if (key == LogicalKeyboardKey.keyA) return Direction.left;
    if (key == LogicalKeyboardKey.keyD) return Direction.right;
    // HJKL (Vim 風)
    if (key == LogicalKeyboardKey.keyH) return Direction.left;
    if (key == LogicalKeyboardKey.keyJ) return Direction.down;
    if (key == LogicalKeyboardKey.keyK) return Direction.up;
    if (key == LogicalKeyboardKey.keyL) return Direction.right;
    return null;
  }

  void _move(Direction dir) {
    final current = _gameState!;
    final next = current.move(dir);
    if (!identical(next, current)) {
      _blockedHintTimer?.cancel();
      setState(() {
        _history.add(current);
        _gameState = next;
        _moveCount++;
        _moveBlocked = false;
      });
    } else {
      _blockedHintTimer?.cancel();
      setState(() {
        _moveBlocked = true;
      });
      _blockedHintTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _moveBlocked = false;
          });
        }
      });
    }
    _focusNode.requestFocus();
  }

  void _undo() {
    if (_history.isEmpty) return;
    _blockedHintTimer?.cancel();
    setState(() {
      _gameState = _history.removeLast();
      _moveCount--;
      _moveBlocked = false;
    });
    _focusNode.requestFocus();
  }

  void _restart() {
    _blockedHintTimer?.cancel();
    setState(() {
      _history.clear();
      _moveCount = 0;
      _moveBlocked = false;
      _gameState = GameState.parse(_levelLines);
    });
    _focusNode.requestFocus();
  }

  /// 画面幅に応じて密度を調整した AppBar を構築する。
  ///
  /// 360px 未満の幅ではタイトルやアクションボタンを小さくし、
  /// 余白を詰めることで overflow を防ぐ。
  static const double _compactAppBarThreshold = 360;

  AppBar _buildAppBar(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < _compactAppBarThreshold;

    final double logoSize = isCompact ? 16 : 20;
    final double titleFontSize = isCompact ? 15 : 18;
    final double titleSpacing = isCompact ? 8 : 16;
    final double actionBoxSize = isCompact ? 28 : 34;
    final double actionIconSize = isCompact ? 14 : 18;
    final double actionRadius = isCompact ? 7 : 9;

    return AppBar(
      titleSpacing: titleSpacing,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: const Color(0xFFD7CCC8).withValues(alpha: 0.4),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: logoSize,
            height: logoSize,
            child: CustomPaint(
              painter: SokobanLogoPainter(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          SizedBox(width: isCompact ? 6 : 8),
          Text(
            'Sokoban',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              fontSize: titleFontSize,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          key: const ValueKey('appbar-undo'),
          icon: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: actionBoxSize,
            height: actionBoxSize,
            decoration: BoxDecoration(
              color: _history.isNotEmpty
                  ? const Color(0xFFF5E6CC)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(actionRadius),
              border: _history.isNotEmpty
                  ? Border.all(
                      color: const Color(0xFFD7CCC8),
                      width: 0.5,
                    )
                  : null,
            ),
            child: Center(
              child: SizedBox(
                width: actionIconSize,
                height: actionIconSize,
                child: CustomPaint(
                  painter: UndoIconPainter(
                    color: _history.isNotEmpty
                        ? const Color(0xFF5D4037)
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.30),
                  ),
                ),
              ),
            ),
          ),
          tooltip: '元に戻す',
          onPressed: _history.isNotEmpty ? _undo : null,
        ),
        IconButton(
          key: const ValueKey('appbar-restart'),
          icon: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: actionBoxSize,
            height: actionBoxSize,
            decoration: BoxDecoration(
              color: _history.isNotEmpty
                  ? const Color(0xFFF5E6CC)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(actionRadius),
              border: _history.isNotEmpty
                  ? Border.all(
                      color: const Color(0xFFD7CCC8),
                      width: 0.5,
                    )
                  : null,
            ),
            child: Center(
              child: SizedBox(
                width: actionIconSize,
                height: actionIconSize,
                child: CustomPaint(
                  painter: RestartIconPainter(
                    color: _history.isNotEmpty
                        ? const Color(0xFF5D4037)
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.30),
                  ),
                ),
              ),
            ),
          ),
          tooltip: 'リスタート',
          onPressed: _history.isNotEmpty ? _restart : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = _gameState;
    if (gameState == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sokoban')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Color.lerp(
          Theme.of(context).colorScheme.surface,
          Colors.brown.shade50,
          0.3,
        ),
        appBar: _buildAppBar(context),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, outerConstraints) {
              final useWideLayout = outerConstraints.maxWidth >= 700;

              final boardSection = _BoardSection(
                gameState: gameState,
                moveCount: _moveCount,
                onRestart: _restart,
              );

              final totalBoxes = gameState.boxes.length;
              final statusCard = _StatusCard(
                moveCount: _moveCount,
                remainingBoxes: gameState.remainingBoxes,
                totalBoxes: totalBoxes,
                isSolved: gameState.isSolved,
                moveBlocked: _moveBlocked,
              );

              final controlSection = _ControlSection(
                gameState: gameState,
                history: _history,
                remainingBoxes: gameState.remainingBoxes,
                totalBoxes: totalBoxes,
                moveBlocked: _moveBlocked,
                onMove: _move,
                onUndo: _undo,
                onRestart: _restart,
                hasFocus: _hasFocus,
                onRequestFocus: () => _focusNode.requestFocus(),
              );

              final playContextBanner = _PlayContextBanner(
                isSolved: gameState.isSolved,
                remainingBoxes: gameState.remainingBoxes,
                totalBoxes: totalBoxes,
              );

              if (useWideLayout) {
                return _WideLayout(
                  playContextBanner: playContextBanner,
                  boardSection: boardSection,
                  statusCard: statusCard,
                  controlSection: controlSection,
                );
              }

              return _NarrowLayout(
                playContextBanner: playContextBanner,
                boardSection: boardSection,
                statusCard: statusCard,
                controlSection: controlSection,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 盤面セクション（コンテナ装飾 + AspectRatio + オーバーレイ）。
class _BoardSection extends StatelessWidget {
  const _BoardSection({
    required this.gameState,
    required this.moveCount,
    required this.onRestart,
  });

  final GameState gameState;
  final int moveCount;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final placed = gameState.boxes.length - gameState.remainingBoxes;
    final total = gameState.boxes.length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.brown.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD7CCC8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.brown.withValues(alpha: 0.04),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- ヘッダー行 ---
              LayoutBuilder(
                builder: (context, constraints) {
                  // 幅 300px 未満では 2 行に分割して窮屈さを緩和する。
                  final isCompactHeader = constraints.maxWidth < 300;

                  // --- 左: ステージ名 + ステータス ---
                  final stageRow = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CustomPaint(
                          painter: PuzzleSectionIconPainter(
                            color:
                                const Color(0xFF8D6E63).withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'ステージ 1',
                          key: const Key('board_header_stage'),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF5D4037),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // ステータスバッジ
                      Container(
                        key: const Key('board_header_status'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: gameState.isSolved
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFF8D6E63).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          gameState.isSolved ? 'クリア' : 'プレイ中',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: gameState.isSolved
                                ? const Color(0xFF388E3C)
                                : const Color(0xFF8D6E63),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  );

                  // --- 右: 統計チップ ---
                  final statChips = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 手数チップ
                      Container(
                        key: const Key('board_header_move_count'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFEBE9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFD7CCC8),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 10,
                              height: 10,
                              child: CustomPaint(
                                painter: MoveCountIconPainter(
                                  color: const Color(0xFF8D6E63),
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$moveCount 手',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF8D6E63),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 箱カウントチップ
                      Container(
                        key: const Key('board_header_box_count'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: gameState.isSolved
                              ? Colors.green.shade50
                              : const Color(0xFFEFEBE9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: gameState.isSolved
                                ? Colors.green.shade200
                                : const Color(0xFFD7CCC8),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 10,
                              height: 10,
                              child: CustomPaint(
                                painter: PlacementIconPainter(
                                  color: gameState.isSolved
                                      ? Colors.green.shade700
                                      : const Color(0xFF8D6E63),
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$placed/$total',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: gameState.isSolved
                                    ? Colors.green.shade700
                                    : const Color(0xFF8D6E63),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  if (isCompactHeader) {
                    // 狭い幅: 2 行に分けて表示する
                    return Padding(
                      key: const Key('board_header_compact'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          stageRow,
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: statChips,
                          ),
                        ],
                      ),
                    );
                  }

                  // 広い幅: 1 行に横並び（従来と同等）
                  return Padding(
                    key: const Key('board_header_wide'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Flexible(child: stageRow),
                        const Spacer(),
                        statChips,
                      ],
                    ),
                  );
                },
              ),
              // --- 区切り線 ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: const Color(0xFFD7CCC8).withValues(alpha: 0.5),
                ),
              ),
              // --- 盤面 ---
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  // 盤面を一段沈み込ませるインセット溝
                  child: Container(
                    key: const Key('board_inset_groove'),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8DDD0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Container(
                      key: const Key('board_tile_frame'),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.brown.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          // 上辺の内側影で沈み込み感を強調
                          BoxShadow(
                            color: Colors.brown.withValues(alpha: 0.13),
                            blurRadius: 3,
                            offset: const Offset(0, 1.5),
                          ),
                          // 下辺のハイライトで立体感を追加
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.5),
                            blurRadius: 1,
                            offset: const Offset(0, -0.5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6.5),
                        child: AspectRatio(
                          aspectRatio:
                              gameState.board.width / gameState.board.height,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final cellSize =
                                  constraints.maxWidth / gameState.board.width;
                              return Stack(
                                children: [
                                  _BoardView(
                                    gameState: gameState,
                                    cellSize: cellSize,
                                  ),
                                  if (gameState.isSolved)
                                    _ClearOverlay(
                                      moveCount: moveCount,
                                      totalBoxes: gameState.boxes.length,
                                      onRestart: onRestart,
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // --- フッター行: グリッドサイズ + 凡例 ---
              Padding(
                padding: const EdgeInsets.only(
                  left: 12,
                  right: 12,
                  bottom: 6,
                  top: 2,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final dimensionsRow = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CustomPaint(
                            painter: PuzzleSectionIconPainter(
                              color: const Color(0xFF8D6E63)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${gameState.board.width} × ${gameState.board.height}',
                          key: const Key('board_footer_dimensions'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF8D6E63)
                                .withValues(alpha: 0.5),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    );
                    const legend = _BoardLegend(
                      key: Key('board_legend'),
                    );

                    // 狭い画面では 2 段構成にして窮屈さを回避
                    if (constraints.maxWidth < 260) {
                      return Column(
                        key: const Key('board_footer'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          dimensionsRow,
                          const SizedBox(height: 4),
                          legend,
                        ],
                      );
                    }
                    return Row(
                      key: const Key('board_footer'),
                      children: [
                        dimensionsRow,
                        const Spacer(),
                        legend,
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 盤面フッターの凡例（プレイヤー・箱・ゴール）。
///
/// ゲーム用ウィジェット (PlayerWidget 等) を直接使うとテストの
/// `findsOneWidget` と衝突するため、簡易な図形で表現する。
class _BoardLegend extends StatelessWidget {
  const _BoardLegend({super.key});

  static const _labelStyle = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w500,
    color: Color(0xFF8D6E63),
    letterSpacing: 0.2,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF8D6E63).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // プレイヤー: 青い丸
          _legendItem(
            icon: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF3B82B8),
              ),
            ),
            label: 'プレイヤー',
          ),
          const SizedBox(width: 10),
          // 箱: 琥珀色の角丸四角
          _legendItem(
            icon: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: const Color(0xFFC08830),
              ),
            ),
            label: '箱',
          ),
          const SizedBox(width: 10),
          // ゴール: 緑のリング
          _legendItem(
            icon: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF43A047),
                  width: 1.5,
                ),
              ),
            ),
            label: 'ゴール',
          ),
        ],
      ),
    );
  }

  Widget _legendItem({required Widget icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 4),
        Text(
          label,
          style: _labelStyle.copyWith(
            color: const Color(0xFF8D6E63).withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

/// 操作パッド + Undo / Restart ボタンをまとめたセクション。
class _ControlSection extends StatelessWidget {
  const _ControlSection({
    required this.gameState,
    required this.history,
    required this.remainingBoxes,
    required this.totalBoxes,
    this.moveBlocked = false,
    required this.onMove,
    required this.onUndo,
    required this.onRestart,
    this.hasFocus = false,
    this.onRequestFocus,
  });

  final GameState gameState;
  final List<GameState> history;
  final int remainingBoxes;
  final int totalBoxes;
  final bool moveBlocked;
  final void Function(Direction) onMove;
  final VoidCallback onUndo;
  final VoidCallback onRestart;
  final bool hasFocus;
  final VoidCallback? onRequestFocus;

  /// 方向パッドと補助ボタンの密度を切り替える幅しきい値。
  ///
  /// 320px 幅の端末では親パディング (12×2) を引くと約 296px になるため、
  /// 340 を境にコンパクトモードへ切り替える。
  static const double _compactThreshold = 340;

  @override
  Widget build(BuildContext context) {
    final hasHistory = history.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < _compactThreshold;
        final double hPad = isCompact ? 8 : 12;
        final double vPad = isCompact ? 6 : 8;
        final double dpadInsetH = isCompact ? 6 : 10;
        final double dpadInsetV = isCompact ? 4 : 6;
        final double sectionGap = isCompact ? 6 : 8;
        final double dividerGap = isCompact ? 4 : 6;
        final double assistGap = isCompact ? 8 : 12;
        final double bottomGap = isCompact ? 6 : 8;

        return Container(
          padding: EdgeInsets.only(
            top: vPad,
            left: hPad,
            right: hPad,
            bottom: vPad + 4,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF3E8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD7CCC8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ControlSubLabel(
                key: const Key('control_sub_label_move'),
                icon: Icons.control_camera,
                text: '移動',
              ),
              SizedBox(height: isCompact ? 2 : 4),
              // 方向パッドを囲むインセット背景
              Container(
                padding: EdgeInsets.symmetric(
                  vertical: dpadInsetV,
                  horizontal: dpadInsetH,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5EDE0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE8DDD0),
                    width: 0.5,
                  ),
                ),
                child: _DirectionPad(
                  onMove: onMove,
                  enabled: !gameState.isSolved,
                  isSolved: gameState.isSolved,
                  moveBlocked: moveBlocked,
                  remainingBoxes: remainingBoxes,
                  totalBoxes: totalBoxes,
                  compact: isCompact,
                ),
              ),
              SizedBox(height: sectionGap),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    const Expanded(child: Divider(color: Color(0xFFE0D6CC))),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 6 : 10,
                      ),
                      child: _ControlSubLabel(
                        key: const Key('control_sub_label_assist'),
                        icon: Icons.history,
                        text: 'やり直し',
                      ),
                    ),
                    const Expanded(child: Divider(color: Color(0xFFE0D6CC))),
                  ],
                ),
              ),
              SizedBox(height: dividerGap),
              Row(
                children: [
                  Expanded(
                    child: _AssistButton(
                      key: const ValueKey('bottom-undo'),
                      onPressed: hasHistory ? onUndo : null,
                      iconPainter: UndoIconPainter(
                        color: hasHistory
                            ? const Color(0xFF5D4037)
                            : Colors.grey.shade400,
                      ),
                      label: '元に戻す',
                      compact: isCompact,
                    ),
                  ),
                  SizedBox(width: assistGap),
                  Expanded(
                    child: _AssistButton(
                      key: const ValueKey('bottom-restart'),
                      onPressed: hasHistory ? onRestart : null,
                      iconPainter: RestartIconPainter(
                        color: hasHistory
                            ? const Color(0xFF5D4037)
                            : Colors.grey.shade400,
                      ),
                      label: 'リスタート',
                      compact: isCompact,
                    ),
                  ),
                ],
              ),
              SizedBox(height: bottomGap),
              _KeyboardFocusIndicator(
                hasFocus: hasFocus,
                onRequestFocus: onRequestFocus,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 操作セクション内のサブラベル（「移動」「やり直し」など）。
class _ControlSubLabel extends StatelessWidget {
  const _ControlSubLabel({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF8D6E63)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8D6E63),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

/// キーボードフォーカス状態を伝える小さなインジケーター。
///
/// フォーカスがあるときは「キーボード有効」、
/// ないときは「タップしてキーボードを有効化」と表示する。
class _KeyboardFocusIndicator extends StatelessWidget {
  const _KeyboardFocusIndicator({
    required this.hasFocus,
    this.onRequestFocus,
  });

  final bool hasFocus;
  final VoidCallback? onRequestFocus;

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color fgColor;
    final Color borderColor;
    final String label;
    final IconData icon;

    if (hasFocus) {
      bgColor = const Color(0xFFE8F5E9);
      fgColor = const Color(0xFF388E3C);
      borderColor = const Color(0xFF388E3C).withValues(alpha: 0.2);
      label = 'キーボード有効';
      icon = Icons.keyboard_rounded;
    } else {
      bgColor = const Color(0xFFFFF8E1);
      fgColor = const Color(0xFF8D6E63);
      borderColor = const Color(0xFF8D6E63).withValues(alpha: 0.2);
      label = 'タップしてキーボードを有効化';
      icon = Icons.keyboard_hide_rounded;
    }

    return GestureDetector(
      onTap: hasFocus ? null : onRequestFocus,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        key: const Key('keyboard_focus_indicator'),
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                key: ValueKey(hasFocus),
                size: 14,
                color: fgColor,
              ),
            ),
            const SizedBox(width: 5),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                label,
                key: ValueKey(label),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: fgColor.withValues(alpha: 0.8),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 押下時に軽い縮小アニメーションで触感を伝える共通ラッパー。
class _PressableControl extends StatefulWidget {
  const _PressableControl({
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  State<_PressableControl> createState() => _PressableControlState();
}

class _PressableControlState extends State<_PressableControl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent _) {
    if (widget.enabled) _controller.forward();
  }

  void _onPointerUp(PointerUpEvent _) {
    _controller.reverse();
  }

  void _onPointerCancel(PointerCancelEvent _) {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.translucent,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// 方向パッドと統一感のあるグラデーション付き補助ボタン。
class _AssistButton extends StatelessWidget {
  const _AssistButton({
    super.key,
    required this.onPressed,
    required this.iconPainter,
    required this.label,
    this.compact = false,
  });

  final VoidCallback? onPressed;
  final CustomPainter iconPainter;
  final String label;
  final bool compact;

  bool get enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final double height = compact ? 42 : 48;
    final double iconSize = compact ? 16 : 20;
    final double fontSize = compact ? 12 : 14;
    final double radius = compact ? 12 : 14;
    final double iconGap = compact ? 6 : 8;

    return _PressableControl(
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Material(
          color: enabled ? const Color(0xFFF5E6CC) : const Color(0xFFEDE7E0),
          borderRadius: BorderRadius.circular(radius),
          elevation: enabled ? 2 : 0,
          shadowColor: const Color(0x40000000),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(radius),
            splashColor: const Color(0x308D6E63),
            highlightColor: const Color(0x188D6E63),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: enabled
                      ? const Color(0xFF8D6E63)
                      : const Color(0xFFCCC3BA),
                  width: enabled ? 1.5 : 1.0,
                ),
                gradient: enabled
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFF9EDDA), Color(0xFFF0DDBF)],
                      )
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: CustomPaint(painter: iconPainter),
                  ),
                  SizedBox(width: iconGap),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? const Color(0xFF5D4037)
                          : const Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// プレイ画面上部のヒーローバナー。
///
/// ステージ情報と目的を視覚階層のある小さなカード風に表示し、
/// プレイ中の文脈を伝える。クリア時は配色が切り替わる。
class _PlayContextBanner extends StatelessWidget {
  const _PlayContextBanner({
    required this.isSolved,
    required this.remainingBoxes,
    required this.totalBoxes,
  });

  final bool isSolved;
  final int remainingBoxes;
  final int totalBoxes;

  /// チップを横に並べるか下に落とすかの幅しきい値。
  ///
  /// バナー内のアクセントバー (4) + パディング (8×2) + アイコン (28–36) +
  /// ギャップ + テキスト列 + チップ (~70) が無理なく並ぶ最低幅。
  static const double _compactThreshold = 300;

  @override
  Widget build(BuildContext context) {
    final Color accentColor;
    final Color bgColor;
    final Color fgColor;
    final Color subtitleColor;
    final String stageLabel;
    final String description;
    final IconData icon;

    if (isSolved) {
      accentColor = const Color(0xFF388E3C);
      bgColor = const Color(0xFFE8F5E9);
      fgColor = const Color(0xFF2E7D32);
      subtitleColor = const Color(0xFF388E3C);
      stageLabel = 'ステージ 1';
      description = 'クリア済み';
      icon = Icons.emoji_events_rounded;
    } else {
      accentColor = const Color(0xFF8D6E63);
      bgColor = const Color(0xFFFFF8E1);
      fgColor = const Color(0xFF5D4037);
      subtitleColor = const Color(0xFF8D6E63);
      stageLabel = 'ステージ 1';
      description = '箱をすべてゴールへ運ぼう';
      icon = Icons.grid_on_rounded;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: LayoutBuilder(
        key: ValueKey<bool>(isSolved),
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < _compactThreshold;
          final double iconSize = isCompact ? 28 : 36;
          final double iconInner = isCompact ? 16 : 19;
          final double hPad = isCompact ? 8 : 12;
          final double vPad = isCompact ? 8 : 10;
          final double gap = isCompact ? 8 : 12;

          final progressChip = totalBoxes > 0
              ? _BannerProgressChip(
                  placed: totalBoxes - remainingBoxes,
                  total: totalBoxes,
                  isSolved: isSolved,
                  accentColor: accentColor,
                )
              : null;

          return Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // 左アクセントバー
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                      ),
                    ),
                  ),
                  // コンテンツ部分
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: hPad,
                        vertical: vPad,
                      ),
                      child: Row(
                        children: [
                          // アイコン背景
                          Container(
                            width: iconSize,
                            height: iconSize,
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child:
                                Icon(icon, size: iconInner, color: accentColor),
                          ),
                          SizedBox(width: gap),
                          // テキスト 2 行 + 進捗バー (+ compact 時はチップも)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  stageLabel,
                                  key: const Key('play_context_label'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: fgColor,
                                    letterSpacing: 0.3,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  description,
                                  key: const Key('play_context_description'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: subtitleColor,
                                    letterSpacing: 0.2,
                                    height: 1.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (totalBoxes > 0) ...[
                                  const SizedBox(height: 6),
                                  _BannerProgressBar(
                                    placed: totalBoxes - remainingBoxes,
                                    total: totalBoxes,
                                    isSolved: isSolved,
                                    accentColor: accentColor,
                                  ),
                                ],
                                // compact: チップをバーの下に配置
                                if (isCompact && progressChip != null) ...[
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: progressChip,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // wide: チップを横に並べる
                          if (!isCompact && progressChip != null) ...[
                            SizedBox(width: gap),
                            progressChip,
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// バナー内の配置進捗チップ。
class _BannerProgressChip extends StatelessWidget {
  const _BannerProgressChip({
    required this.placed,
    required this.total,
    required this.isSolved,
    required this.accentColor,
  });

  final int placed;
  final int total;
  final bool isSolved;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color chipBg;
    final Color chipFg;

    if (isSolved) {
      label = '全配置';
      chipBg = const Color(0xFFE8F5E9);
      chipFg = const Color(0xFF388E3C);
    } else {
      label = '$placed / $total';
      chipBg = accentColor.withValues(alpha: 0.10);
      chipFg = accentColor;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: Key('banner_progress_$label'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: chipFg.withValues(alpha: 0.25), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_rounded, size: 12, color: chipFg),
            const SizedBox(width: 4),
            if (isSolved)
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: chipFg,
                  letterSpacing: 0.3,
                ),
              )
            else
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$placed',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: chipFg,
                      ),
                    ),
                    TextSpan(
                      text: ' / $total',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: chipFg.withValues(alpha: 0.7),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// バナー内のコンパクトな進捗バー。
///
/// 配置済み箱数を直感的に把握できるよう、テキスト下にインライン表示する。
class _BannerProgressBar extends StatelessWidget {
  const _BannerProgressBar({
    required this.placed,
    required this.total,
    required this.isSolved,
    required this.accentColor,
  });

  final int placed;
  final int total;
  final bool isSolved;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final double progress = total > 0 ? placed / total : 0;
    final trackColor = accentColor.withValues(alpha: 0.12);
    final fillColor = isSolved ? const Color(0xFF388E3C) : accentColor;

    return ClipRRect(
      key: Key('banner_bar_${placed}_$total'),
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fillWidth = constraints.maxWidth * progress;
            return Stack(
              children: [
                // トラック
                Container(color: trackColor),
                // フィル
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: fillWidth,
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 狭い画面向けの縦積みレイアウト。
///
/// モバイル端末で盤面をできるだけ大きく表示しつつ、
/// ヒーローバナーも表示して文脈を伝える。
class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.playContextBanner,
    required this.boardSection,
    required this.statusCard,
    required this.controlSection,
  });

  final Widget playContextBanner;
  final Widget boardSection;
  final Widget statusCard;
  final Widget controlSection;

  /// 盤面の最低限の表示高さ。
  ///
  /// これ以下になるとパズルが視認しづらくなるため、
  /// スクロールで対処する。
  static const double _minBoardHeight = 140;

  /// 高さが十分でないときに周辺 UI を圧縮するしきい値。
  static const double _compactHeightThreshold = 600;

  /// 盤面に画面高さの何割を割り当てるか。
  ///
  /// 残りをバナー・ステータスカード・操作パッド等が占める。
  static const double _boardRatio = 0.55;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final available = constraints.maxHeight;
              final isCompact = available < _compactHeightThreshold;
              final boardHeight =
                  (available * _boardRatio).clamp(_minBoardHeight, available);
              final sectionGap = isCompact ? 4.0 : 6.0;

              final headingColor = Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.6);

              return SingleChildScrollView(
                child: ConstrainedBox(
                  // 画面全体を使い切れるよう最低高さを設定。
                  constraints: BoxConstraints(minHeight: available),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: isCompact ? 2 : 4),
                      playContextBanner,
                      SizedBox(height: sectionGap),
                      _SectionHeading(
                        iconWidget: CustomPaint(
                          painter:
                              PuzzleSectionIconPainter(color: headingColor),
                        ),
                        label: 'パズル',
                      ),
                      SizedBox(height: isCompact ? 2 : 4),
                      SizedBox(height: boardHeight, child: boardSection),
                      SizedBox(height: sectionGap),
                      _SectionHeading(
                        iconWidget: CustomPaint(
                          painter:
                              StatusSectionIconPainter(color: headingColor),
                        ),
                        label: '状況',
                      ),
                      SizedBox(height: isCompact ? 2 : 4),
                      statusCard,
                      SizedBox(height: sectionGap),
                      _SectionHeading(
                        iconWidget: CustomPaint(
                          painter:
                              ControlSectionIconPainter(color: headingColor),
                        ),
                        label: '操作',
                      ),
                      SizedBox(height: isCompact ? 2 : 4),
                      controlSection,
                      SizedBox(height: isCompact ? 4 : 8),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 広い画面向けの 2 カラムレイアウト。
/// 左に盤面、右にステータスカードと操作セクションを配置する。
class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.playContextBanner,
    required this.boardSection,
    required this.statusCard,
    required this.controlSection,
  });

  final Widget playContextBanner;
  final Widget boardSection;
  final Widget statusCard;
  final Widget controlSection;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              playContextBanner,
              const SizedBox(height: 14),
              Flexible(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // --- 左カラム: 盤面 ---
                    Expanded(
                      flex: 3,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SectionHeading(
                            iconWidget: CustomPaint(
                              painter: PuzzleSectionIconPainter(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                            label: 'パズル',
                            subtitle: '— 箱をゴールへ運ぼう',
                          ),
                          const SizedBox(height: 4),
                          Flexible(child: boardSection),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // --- 右カラム: ステータス + 操作 ---
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SectionHeading(
                              iconWidget: CustomPaint(
                                painter: StatusSectionIconPainter(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              label: '状況',
                              subtitle: '— 手数と配置の進み具合',
                            ),
                            const SizedBox(height: 4),
                            statusCard,
                            const SizedBox(height: 12),
                            _SectionHeading(
                              iconWidget: CustomPaint(
                                painter: ControlSectionIconPainter(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              label: '操作',
                              subtitle: '— ボタンまたはキーで移動',
                            ),
                            const SizedBox(height: 4),
                            controlSection,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// セクション見出し（アイコン + ラベル + 補足テキスト）。
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.iconWidget,
    required this.label,
    this.subtitle,
  });

  final Widget iconWidget;
  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
    final subtitleColor = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: [
          SizedBox(width: 14, height: 14, child: iconWidget),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 6),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 10, color: subtitleColor),
            ),
          ],
        ],
      ),
    );
  }
}

/// 手数・残り箱数・クリア状態・ヒントを統合表示するステータスカード。
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.moveCount,
    required this.remainingBoxes,
    required this.totalBoxes,
    required this.isSolved,
    required this.moveBlocked,
  });

  final int moveCount;
  final int remainingBoxes;
  final int totalBoxes;
  final bool isSolved;
  final bool moveBlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allPlaced = remainingBoxes == 0;

    return Container(
      decoration: BoxDecoration(
        color: isSolved ? Colors.green.shade50 : const Color(0xFFFDF8F3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSolved ? Colors.green.shade200 : const Color(0xFFD7CCC8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- 状態サマリー帯 ---
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: _buildSummaryStrip(theme),
          ),
          // --- クリアバナー（クリア時のみ表示） ---
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: child,
                ),
              );
            },
            child: isSolved
                ? Container(
                    key: const ValueKey('clear-banner'),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CustomPaint(
                              painter: TrophyIconPainter(
                                color: Colors.green.shade600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'クリア！',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            Text(
                              '$moveCount手でクリア',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no-banner')),
          ),
          // --- 進捗情報（手数・配置状況） ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useVertical = constraints.maxWidth < 260;
                return _StatArea(
                  moveCount: moveCount,
                  remainingBoxes: remainingBoxes,
                  totalBoxes: totalBoxes,
                  allPlaced: allPlaced,
                  useVertical: useVertical,
                );
              },
            ),
          ),
          // --- 配置セグメントバー ---
          Padding(
            padding: const EdgeInsets.only(
              left: 14,
              right: 14,
              bottom: 8,
              top: 0,
            ),
            child: _SegmentedProgressBar(
              placedCount: totalBoxes - remainingBoxes,
              totalCount: totalBoxes,
              isSolved: isSolved,
            ),
          ),
          // --- ヒントテキスト（背景色で副次情報として区別） ---
          Container(
            key: const Key('status_hint_section'),
            width: double.infinity,
            padding: const EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: 8,
              top: 0,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.25),
              border: Border(
                top: BorderSide(
                  color: const Color(0xFFE8E0D8).withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Wrap(
                key: ValueKey(isSolved ? 'hint-cleared' : 'hint-normal'),
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 5,
                children: isSolved
                    ? [
                        _HintChip(
                          key: const Key('hint_cleared'),
                          action: 'クリア済み',
                          color: Colors.green.shade600,
                          bgColor: Colors.green.shade50,
                          icon: Icons.check_circle_outline,
                        ),
                        _HintChip(
                          key: const Key('hint_undo'),
                          action: '戻す',
                          keyHint: 'Ctrl+Z',
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        _HintChip(
                          key: const Key('hint_restart'),
                          action: 'やり直し',
                          keyHint: 'R',
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ]
                    : [
                        _HintChip(
                          key: const Key('hint_move'),
                          action: '移動',
                          keyHint: 'ボタン／矢印・WASD',
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        _HintChip(
                          key: const Key('hint_undo'),
                          action: '戻す',
                          keyHint: 'Ctrl+Z',
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        _HintChip(
                          key: const Key('hint_restart'),
                          action: 'やり直し',
                          keyHint: 'R',
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStrip(ThemeData theme) {
    final Color bgColor;
    final Color textColor;
    final String text;
    final Key key;

    if (isSolved) {
      bgColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
      text = 'すべて配置完了！';
      key = const ValueKey('summary-cleared');
    } else if (moveBlocked) {
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade700;
      text = 'その方向には進めません';
      key = const ValueKey('summary-blocked');
    } else {
      bgColor = Colors.orange.shade50;
      textColor = Colors.brown.shade700;
      text = remainingBoxes == 0 ? 'すべて配置完了！' : 'あと $remainingBoxes 個で完了';
      key = ValueKey('summary-progress-$remainingBoxes');
    }

    final IconData summaryIcon;
    if (isSolved) {
      summaryIcon = Icons.check_circle_outline;
    } else if (moveBlocked) {
      summaryIcon = Icons.block;
    } else {
      summaryIcon = Icons.trending_up;
    }

    // 状態に応じたアクセント色（PlayContextBanner と同じパターン）
    final Color accentColor;
    if (isSolved) {
      accentColor = Colors.green.shade600;
    } else if (moveBlocked) {
      accentColor = Colors.red.shade400;
    } else {
      accentColor = Colors.orange.shade600;
    }

    return Container(
      key: key,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bgColor,
        // カード上端の角丸に合わせる
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // 左アクセントバー
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(summaryIcon, size: 14, color: textColor),
                    const SizedBox(width: 5),
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 手数・配置状況の 2 項目を横並び or 縦積みで表示するエリア。
///
/// 狭い画面（幅 260px 未満）では自動的に縦積みレイアウトに切り替わる。
class _StatArea extends StatelessWidget {
  const _StatArea({
    required this.moveCount,
    required this.remainingBoxes,
    required this.totalBoxes,
    required this.allPlaced,
    required this.useVertical,
  });

  final int moveCount;
  final int remainingBoxes;
  final int totalBoxes;
  final bool allPlaced;
  final bool useVertical;

  @override
  Widget build(BuildContext context) {
    final placementColor = allPlaced ? Colors.green : Colors.orange.shade800;

    final moveItem = _StatItem(
      iconWidget: CustomPaint(
        painter: MoveCountIconPainter(
          color: const Color(0xFF1565C0),
        ),
      ),
      iconColor: const Color(0xFF1565C0),
      label: '手数',
      value: '$moveCount',
    );

    final placementItem = _StatItem(
      iconWidget: CustomPaint(
        painter: PlacementIconPainter(
          color: placementColor,
        ),
      ),
      iconColor: placementColor,
      label: '配置',
      value: allPlaced
          ? '全配置！'
          : '${totalBoxes - remainingBoxes} / $totalBoxes',
    );

    final borderColor = const Color(0xFFE0D6CC).withValues(alpha: 0.6);

    if (useVertical) {
      return Container(
        key: const Key('stat_area_vertical'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(9.5),
                  topRight: Radius.circular(9.5),
                ),
              ),
              child: moveItem,
            ),
            Container(
              key: const Key('stat_divider'),
              height: 1,
              color: borderColor,
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: placementColor.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(9.5),
                  bottomRight: Radius.circular(9.5),
                ),
              ),
              child: placementItem,
            ),
          ],
        ),
      );
    }

    return Container(
      key: const Key('stat_area_horizontal'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(9.5),
                    bottomLeft: Radius.circular(9.5),
                  ),
                ),
                child: moveItem,
              ),
            ),
            Container(
              key: const Key('stat_divider'),
              width: 1,
              color: borderColor,
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 6,
                ),
                decoration: BoxDecoration(
                  color: placementColor.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(9.5),
                    bottomRight: Radius.circular(9.5),
                  ),
                ),
                child: placementItem,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 進捗カード内の個別項目（アイコン + ラベル + 値）。
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.iconWidget,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final Widget iconWidget;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: iconWidget,
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.55,
                  ),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 1),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  value,
                  key: ValueKey(value),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: iconColor,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 箱ごとに 1 セグメントを持つ進捗バー。
///
/// 各セグメントはゴールに配置済みかどうかで塗り分ける。
class _SegmentedProgressBar extends StatelessWidget {
  const _SegmentedProgressBar({
    required this.placedCount,
    required this.totalCount,
    required this.isSolved,
  });

  final int placedCount;
  final int totalCount;
  final bool isSolved;

  @override
  Widget build(BuildContext context) {
    if (totalCount <= 0) return const SizedBox.shrink();

    final Color filledColor =
        isSolved ? Colors.green.shade400 : Colors.orange.shade400;
    final Color emptyColor = const Color(0xFFD7CCC8).withValues(alpha: 0.35);

    return Row(
      children: List.generate(totalCount, (i) {
        final bool placed = i < placedCount;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
            child: AnimatedContainer(
              key: ValueKey('segment_$i'),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: 8,
              decoration: BoxDecoration(
                color: placed ? filledColor : emptyColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// ヒント行の個別チップ。
///
/// [action] は操作名、[keyHint] はキーボードショートカットの表記。
/// 両者を視覚的に区別して表示し、情報の優先度を伝える。
class _HintChip extends StatelessWidget {
  const _HintChip({
    super.key,
    required this.action,
    this.keyHint,
    required this.color,
    this.bgColor,
    this.icon,
  });

  final String action;
  final String? keyHint;
  final Color color;
  final Color? bgColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBg =
        bgColor ?? theme.colorScheme.outlineVariant.withValues(alpha: 0.10);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color.withValues(alpha: 0.85)),
            const SizedBox(width: 4),
          ],
          if (keyHint != null)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: action,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: color.withValues(alpha: 0.80),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                  TextSpan(
                    text: '  $keyHint',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: color.withValues(alpha: 0.48),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              action,
              style: TextStyle(
                fontSize: 10.5,
                color: color.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
        ],
      ),
    );
  }
}

/// クリア時に盤面上へ表示する完了オーバーレイ。
class _ClearOverlay extends StatefulWidget {
  const _ClearOverlay({
    required this.moveCount,
    required this.totalBoxes,
    required this.onRestart,
  });

  final int moveCount;
  final int totalBoxes;
  final VoidCallback onRestart;

  @override
  State<_ClearOverlay> createState() => _ClearOverlayState();
}

class _ClearOverlayState extends State<_ClearOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// サマリーチップを Wrap に切り替える幅しきい値。
  static const double _compactOverlayThreshold = 280;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Positioned.fill(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth;
                  final isCompact = availableWidth < _compactOverlayThreshold;
                  final double hPad = isCompact ? 16 : 32;
                  final double vPadTop = isCompact ? 14 : 22;
                  final double trophyOuter = isCompact ? 8 : 12;
                  final double trophySize = isCompact ? 28 : 40;
                  final double titleSize = isCompact ? 18 : 24;
                  final double chipFontSize = isCompact ? 11 : 13;
                  final double boxChipFontSize = isCompact ? 10 : 12;
                  final double btnHPad = isCompact ? 16 : 32;
                  final double dividerHPad = isCompact ? 16 : 24;

                  // サマリーチップ
                  final moveChip = Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 8 : 12,
                      vertical: isCompact ? 4 : 5,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.moveCount}手でクリア',
                      style: TextStyle(
                        fontSize: chipFontSize,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );

                  final boxChip = Container(
                    key: const Key('overlay-box-count'),
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 7 : 10,
                      vertical: isCompact ? 4 : 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.shade200,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      '${widget.totalBoxes}/${widget.totalBoxes} 配置',
                      key: const Key('overlay-box-count-text'),
                      style: TextStyle(
                        fontSize: boxChipFontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  );

                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: (availableWidth * 0.92).clamp(0, 360),
                    ),
                    child: Card(
                      key: Key(isCompact
                          ? 'overlay-card-compact'
                          : 'overlay-card-wide'),
                      elevation: 8,
                      shadowColor: Colors.amber.withValues(alpha: 0.25),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ゴールドのアクセントライン
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.amber.shade300,
                                  Colors.amber.shade600,
                                  Colors.amber.shade300,
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              hPad,
                              vPadTop,
                              hPad,
                              10,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // トロフィーアイコン
                                Container(
                                  padding: EdgeInsets.all(trophyOuter),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: SizedBox(
                                    width: trophySize,
                                    height: trophySize,
                                    child: CustomPaint(
                                      painter: TrophyIconPainter(
                                        color: Colors.amber.shade600,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: isCompact ? 8 : 12),
                                // メインタイトル
                                Text(
                                  'クリア！',
                                  style: TextStyle(
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // ステージ完了サブタイトル
                                Text(
                                  'ステージ 1 完了',
                                  key: const Key('overlay-stage-complete'),
                                  style: TextStyle(
                                    fontSize: isCompact ? 11 : 12,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.7),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                SizedBox(height: isCompact ? 10 : 14),
                                // サマリーチップ — 狭い幅では Wrap で折り返し
                                isCompact
                                    ? Wrap(
                                        key: const Key(
                                          'overlay-chips-wrap',
                                        ),
                                        alignment: WrapAlignment.center,
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [moveChip, boxChip],
                                      )
                                    : Row(
                                        key: const Key(
                                          'overlay-chips-row',
                                        ),
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          moveChip,
                                          const SizedBox(width: 8),
                                          boxChip,
                                        ],
                                      ),
                              ],
                            ),
                          ),
                          // ディバイダー
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: dividerHPad,
                            ),
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          // ボタンエリア
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              btnHPad,
                              isCompact ? 10 : 14,
                              btnHPad,
                              isCompact ? 12 : 18,
                            ),
                            child: FilledButton.icon(
                              key: const ValueKey('overlay-restart'),
                              onPressed: widget.onRestart,
                              icon: SizedBox(
                                width: 18,
                                height: 18,
                                child: CustomPaint(
                                  painter: RestartIconPainter(
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                              label: const Text('もう一度'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 盤面をグリッド描画するウィジェット。
class _BoardView extends StatelessWidget {
  const _BoardView({required this.gameState, required this.cellSize});

  final GameState gameState;
  final double cellSize;

  @override
  Widget build(BuildContext context) {
    final board = gameState.board;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(board.height, (y) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(board.width, (x) {
            return SizedBox(
              width: cellSize,
              height: cellSize,
              child: _CellWidget(
                isWall: board.isWall(x, y),
                isGoal: board.isGoal(x, y),
                isPlayer: x == gameState.playerX && y == gameState.playerY,
                isBox: gameState.boxes.contains((x, y)),
              ),
            );
          }),
        );
      }),
    );
  }
}

/// 1 セルの描画。
class _CellWidget extends StatelessWidget {
  const _CellWidget({
    required this.isWall,
    required this.isGoal,
    required this.isPlayer,
    required this.isBox,
  });

  final bool isWall;
  final bool isGoal;
  final bool isPlayer;
  final bool isBox;

  @override
  Widget build(BuildContext context) {
    // --- 壁 ---
    if (isWall) {
      return const CustomPaint(painter: WallPainter());
    }

    const goalBgColor = Color(0xFFE8F5E9);

    // --- ゴール上のプレイヤー ---
    if (isPlayer && isGoal) {
      return Container(
        color: goalBgColor,
        child: const Stack(
          children: [
            Positioned.fill(child: GoalMarkerWidget()),
            Positioned.fill(
              child: Padding(padding: EdgeInsets.all(2), child: PlayerWidget()),
            ),
          ],
        ),
      );
    }

    // --- プレイヤー ---
    if (isPlayer) {
      return const Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: FloorPainter())),
          Positioned.fill(
            child: Padding(padding: EdgeInsets.all(2), child: PlayerWidget()),
          ),
        ],
      );
    }

    // --- ゴール上の箱 ---
    if (isBox && isGoal) {
      return Container(
        color: goalBgColor,
        padding: const EdgeInsets.all(1),
        child: const BoxWidget(onGoal: true),
      );
    }

    // --- 箱 ---
    if (isBox) {
      return const Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: FloorPainter())),
          Positioned.fill(
            child: Padding(padding: EdgeInsets.all(1), child: BoxWidget()),
          ),
        ],
      );
    }

    // --- ゴール（空） ---
    if (isGoal) {
      return Container(color: goalBgColor, child: const GoalMarkerWidget());
    }

    // --- 床 ---
    return const CustomPaint(painter: FloorPainter());
  }
}

/// 方向パッド（上下左右ボタン）。
class _DirectionPad extends StatelessWidget {
  const _DirectionPad({
    required this.onMove,
    this.enabled = true,
    this.isSolved = false,
    this.moveBlocked = false,
    this.remainingBoxes = 0,
    this.totalBoxes = 0,
    this.compact = false,
  });

  final void Function(Direction) onMove;
  final bool enabled;
  final bool isSolved;
  final bool moveBlocked;
  final int remainingBoxes;
  final int totalBoxes;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double btnSize = compact ? 50.0 : 60.0;

    const activeColor = Color(0xFF5D4037);
    final disabledColor = Colors.grey.shade400;

    // キーヒント: 方向ボタンに対応するキーボードショートカットを小さく表示
    String keyHint(Direction dir) {
      switch (dir) {
        case Direction.up:
          return 'W';
        case Direction.down:
          return 'S';
        case Direction.left:
          return 'A';
        case Direction.right:
          return 'D';
      }
    }

    final double btnRadius = compact ? 11 : 14;
    final double hintFontSize = compact ? 8 : 9;

    Widget dirButton(Direction dir, String label) {
      final arrowColor = enabled ? activeColor : disabledColor;
      final hintColor = enabled
          ? const Color(0xFF8D6E63).withValues(alpha: 0.55)
          : const Color(0xFF9E9E9E).withValues(alpha: 0.5);
      return SizedBox(
        width: btnSize,
        height: btnSize,
        child: Tooltip(
          message: label,
          child: _PressableControl(
            enabled: enabled,
            child: Opacity(
              opacity: enabled ? 1.0 : 0.45,
              child: Material(
                color:
                    enabled ? const Color(0xFFF5E6CC) : const Color(0xFFEDE7E0),
                borderRadius: BorderRadius.circular(btnRadius),
                elevation: enabled ? 3 : 0,
                shadowColor: const Color(0x40000000),
                child: InkWell(
                  onTap: enabled ? () => onMove(dir) : null,
                  borderRadius: BorderRadius.circular(btnRadius),
                  splashColor: const Color(0x308D6E63),
                  highlightColor: const Color(0x188D6E63),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(btnRadius),
                      border: Border.all(
                        color: enabled
                            ? const Color(0xFF8D6E63)
                            : const Color(0xFFCCC3BA),
                        width: enabled ? 1.5 : 1.0,
                      ),
                      gradient: enabled
                          ? const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFF9EDDA), Color(0xFFF0DDBF)],
                            )
                          : null,
                    ),
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: Size.infinite,
                          painter:
                              ArrowPainter(direction: dir, color: arrowColor),
                        ),
                        Positioned(
                          right: compact ? 4 : 5,
                          bottom: compact ? 2 : 3,
                          child: Text(
                            keyHint(dir),
                            style: TextStyle(
                              fontSize: hintFontSize,
                              fontWeight: FontWeight.w600,
                              color: hintColor,
                              letterSpacing: 0.2,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // --- 中央ステータスチップ ---
    final double chipPadH = compact ? 7 : 10;
    final double chipPadV = compact ? 3 : 5;
    final double chipFontSize = compact ? 10 : 12;
    final double chipRadius = compact ? 8 : 10;

    Widget centerChip() {
      final String chipText;
      final Color chipBg;
      final Color chipFg;

      if (isSolved) {
        chipText = '完了';
        chipBg = const Color(0xFFE8F5E9);
        chipFg = const Color(0xFF388E3C);
      } else if (moveBlocked) {
        chipText = '進めません';
        chipBg = const Color(0xFFFFEBEE);
        chipFg = const Color(0xFFC62828);
      } else if (remainingBoxes == 0 && totalBoxes > 0) {
        chipText = '全配置';
        chipBg = const Color(0xFFE8F5E9);
        chipFg = const Color(0xFF388E3C);
      } else if (totalBoxes > 0) {
        chipText = '残 $remainingBoxes';
        chipBg = const Color(0xFFFFF3E0);
        chipFg = const Color(0xFFE65100);
      } else {
        chipText = '↑↓←→';
        chipBg = const Color(0xFFEFEBE9);
        chipFg = const Color(0xFF8D6E63);
      }

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Container(
          key: Key('dpad_center_status_$chipText'),
          padding: EdgeInsets.symmetric(
            horizontal: chipPadH,
            vertical: chipPadV,
          ),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(chipRadius),
            border: Border.all(color: chipFg.withValues(alpha: 0.25), width: 1),
            boxShadow: [
              BoxShadow(
                color: chipFg.withValues(alpha: 0.08),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            chipText,
            style: TextStyle(
              fontSize: chipFontSize,
              fontWeight: FontWeight.w700,
              color: chipFg,
              letterSpacing: 0.3,
            ),
          ),
        ),
      );
    }

    final double btnGap = compact ? 4 : 6;
    final double centerWidth = btnSize + (compact ? 8 : 12);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        dirButton(Direction.up, '上'),
        SizedBox(height: btnGap),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dirButton(Direction.left, '左'),
            SizedBox(
              width: centerWidth,
              height: btnSize,
              child: Center(child: centerChip()),
            ),
            dirButton(Direction.right, '右'),
          ],
        ),
        SizedBox(height: btnGap),
        dirButton(Direction.down, '下'),
      ],
    );
  }
}
