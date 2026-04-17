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

  @override
  void initState() {
    super.initState();
    if (widget.initialLevel != null) {
      _levelLines = widget.initialLevel!;
      _gameState = GameState.parse(_levelLines);
    } else {
      _loadLevelFromAsset();
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
            Theme.of(context).colorScheme.surface, Colors.brown.shade50, 0.3),
        appBar: AppBar(
          titleSpacing: 16,
          scrolledUnderElevation: 1,
          surfaceTintColor: Colors.brown.shade100,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CustomPaint(
                      painter: SokobanLogoPainter(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Sokoban',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              Text(
                'ステージ 1',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          toolbarHeight: 64,
          actions: [
            IconButton(
              key: const ValueKey('appbar-undo'),
              icon: SizedBox(
                width: 22,
                height: 22,
                child: CustomPaint(
                  painter: UndoIconPainter(
                    color: _history.isNotEmpty
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.38),
                  ),
                ),
              ),
              tooltip: '元に戻す',
              onPressed: _history.isNotEmpty ? _undo : null,
            ),
            IconButton(
              key: const ValueKey('appbar-restart'),
              icon: SizedBox(
                width: 22,
                height: 22,
                child: CustomPaint(
                  painter: RestartIconPainter(
                    color: _history.isNotEmpty
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.38),
                  ),
                ),
              ),
              tooltip: 'リスタート',
              onPressed: _history.isNotEmpty ? _restart : null,
            ),
          ],
        ),
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
                onMove: _move,
                onUndo: _undo,
                onRestart: _restart,
              );

              final playContextBanner = _PlayContextBanner(
                isSolved: gameState.isSolved,
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
            border: Border.all(
              color: const Color(0xFFD7CCC8),
            ),
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
              // --- ヘッダー行 ---
              Padding(
                padding: const EdgeInsets.only(
                    left: 10, right: 10, top: 6, bottom: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 13,
                      height: 13,
                      child: CustomPaint(
                        painter: PuzzleSectionIconPainter(
                          color: const Color(0xFF8D6E63).withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ステージ 1',
                      key: const Key('board_header_stage'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8D6E63),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      key: const Key('board_header_box_count'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: gameState.isSolved
                            ? Colors.green.shade50
                            : const Color(0xFFEFEBE9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '📦 $placed / $total',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: gameState.isSolved
                              ? Colors.green.shade700
                              : const Color(0xFF8D6E63),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // --- 区切り線 ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
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
                  child: AspectRatio(
                    aspectRatio: gameState.board.width / gameState.board.height,
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
                                onRestart: onRestart,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    required this.onMove,
    required this.onUndo,
    required this.onRestart,
  });

  final GameState gameState;
  final List<GameState> history;
  final int remainingBoxes;
  final int totalBoxes;
  final void Function(Direction) onMove;
  final VoidCallback onUndo;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final hasHistory = history.isNotEmpty;
    return Container(
      padding: const EdgeInsets.only(top: 8, left: 12, right: 12, bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF3E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD7CCC8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ControlSubLabel(
            key: const Key('control_sub_label_move'),
            icon: Icons.control_camera,
            text: '移動',
          ),
          _DirectionPad(
            onMove: onMove,
            enabled: !gameState.isSolved,
            isSolved: gameState.isSolved,
            remainingBoxes: remainingBoxes,
            totalBoxes: totalBoxes,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Expanded(child: Divider(color: Color(0xFFD7CCC8))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _ControlSubLabel(
                    key: const Key('control_sub_label_assist'),
                    icon: Icons.history,
                    text: 'やり直し',
                  ),
                ),
                const Expanded(child: Divider(color: Color(0xFFD7CCC8))),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: hasHistory ? onUndo : null,
                  icon: SizedBox(
                    width: 20,
                    height: 20,
                    child: CustomPaint(
                      painter: UndoIconPainter(
                        color: hasHistory
                            ? const Color(0xFF5D4037)
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  label: const Text('元に戻す'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor:
                        hasHistory ? const Color(0xFFF5E6CC) : null,
                    foregroundColor:
                        hasHistory ? const Color(0xFF5D4037) : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: hasHistory
                            ? const Color(0xFF8D6E63)
                            : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: hasHistory ? onRestart : null,
                  icon: SizedBox(
                    width: 20,
                    height: 20,
                    child: CustomPaint(
                      painter: RestartIconPainter(
                        color: hasHistory
                            ? const Color(0xFF5D4037)
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  label: const Text('リスタート'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor:
                        hasHistory ? const Color(0xFFF5E6CC) : null,
                    foregroundColor:
                        hasHistory ? const Color(0xFF5D4037) : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: hasHistory
                            ? const Color(0xFF8D6E63)
                            : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 操作セクション内のサブラベル（「移動」「やり直し」など）。
class _ControlSubLabel extends StatelessWidget {
  const _ControlSubLabel({
    super.key,
    required this.icon,
    required this.text,
  });

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

/// プレイ画面上部のヒーローバナー。
///
/// ステージ情報と目的を視覚階層のある小さなカード風に表示し、
/// プレイ中の文脈を伝える。クリア時は配色が切り替わる。
class _PlayContextBanner extends StatelessWidget {
  const _PlayContextBanner({required this.isSolved});

  final bool isSolved;

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
      child: Container(
        key: ValueKey<bool>(isSolved),
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.2),
          ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      // アイコン背景
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(icon, size: 19, color: accentColor),
                      ),
                      const SizedBox(width: 12),
                      // テキスト 2 行
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 狭い画面向けの縦積みレイアウト。
///
/// モバイル端末で盤面をできるだけ大きく表示するため、
/// バナーやセクション見出しを省略し、余白を詰めている。
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

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: statusCard,
              ),
              Expanded(child: boardSection),
              const SizedBox(height: 6),
              controlSection,
              const SizedBox(height: 8),
            ],
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
    final color =
        Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
    final subtitleColor =
        Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
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
              style: TextStyle(
                fontSize: 10,
                color: subtitleColor,
              ),
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
        color: isSolved
            ? Colors.green.shade50
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSolved
              ? Colors.green.shade200
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
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
                        vertical: 10, horizontal: 16),
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
                : const SizedBox.shrink(
                    key: ValueKey('no-banner'),
                  ),
          ),
          // --- 進捗情報（手数・配置状況） ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: _StatItem(
                    iconWidget: CustomPaint(
                      painter: MoveCountIconPainter(
                        color: const Color(0xFF1565C0),
                      ),
                    ),
                    iconColor: const Color(0xFF1565C0),
                    label: '手数',
                    value: '$moveCount',
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: _StatItem(
                    iconWidget: CustomPaint(
                      painter: PlacementIconPainter(
                        color:
                            allPlaced ? Colors.green : Colors.orange.shade800,
                      ),
                    ),
                    iconColor:
                        allPlaced ? Colors.green : Colors.orange.shade800,
                    label: '配置',
                    value: allPlaced
                        ? '全配置！'
                        : '${totalBoxes - remainingBoxes} / $totalBoxes',
                  ),
                ),
              ],
            ),
          ),
          // --- 配置プログレスバー ---
          Padding(
            padding:
                const EdgeInsets.only(left: 14, right: 14, bottom: 4, top: 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0,
                  end: totalBoxes > 0
                      ? (totalBoxes - remainingBoxes) / totalBoxes
                      : 0,
                ),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                builder: (context, animatedValue, _) {
                  return LinearProgressIndicator(
                    value: animatedValue,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.18),
                    color: allPlaced
                        ? Colors.green.shade400
                        : Colors.orange.shade400,
                  );
                },
              ),
            ),
          ),
          // --- 区切り線 ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Divider(
              height: 1,
              thickness: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.18),
            ),
          ),
          // --- ヒントテキスト ---
          Padding(
            padding:
                const EdgeInsets.only(left: 14, right: 14, bottom: 8, top: 6),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Wrap(
                key: ValueKey(isSolved ? 'hint-cleared' : 'hint-normal'),
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: isSolved
                    ? [
                        _HintChip(
                          label: 'クリア済み',
                          color: Colors.green.shade600,
                          bgColor: Colors.green.shade50,
                        ),
                        _HintChip(
                          label: '戻す  Ctrl+Z',
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        _HintChip(
                          label: 'やり直し  R',
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ]
                    : [
                        _HintChip(
                          label: '移動  ボタン／矢印・WASD',
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        _HintChip(
                          label: '戻す  Ctrl+Z',
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        _HintChip(
                          label: 'やり直し  R',
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

    final int placedCount = totalBoxes - remainingBoxes;

    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 14),
      color: bgColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          if (totalBoxes > 0) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalBoxes, (i) {
                final bool placed = i < placedCount;
                return Padding(
                  padding: EdgeInsets.only(
                    left: i == 0 ? 0 : 4,
                  ),
                  child: Container(
                    key: ValueKey('progress-dot-$i'),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: placed ? textColor.withValues(alpha: 0.8) : null,
                      border: placed
                          ? null
                          : Border.all(
                              color: textColor.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
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
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: iconWidget,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                value,
                key: ValueKey(value),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// ヒント行の個別チップ。
class _HintChip extends StatelessWidget {
  const _HintChip({
    required this.label,
    required this.color,
    this.bgColor,
  });

  final String label;
  final Color color;
  final Color? bgColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color:
            bgColor ?? theme.colorScheme.outlineVariant.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          color: color.withValues(alpha: 0.72),
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// クリア時に盤面上へ表示する完了オーバーレイ。
class _ClearOverlay extends StatelessWidget {
  const _ClearOverlay({
    required this.moveCount,
    required this.onRestart,
  });

  final int moveCount;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: const Color(0xFFFCFFF8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: CustomPaint(
                          painter: TrophyIconPainter(
                            color: Colors.amber.shade600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'クリア！',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$moveCount手でクリア',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const ValueKey('overlay-restart'),
                      onPressed: onRestart,
                      icon: SizedBox(
                        width: 18,
                        height: 18,
                        child: CustomPaint(
                          painter: RestartIconPainter(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      label: const Text('もう一度'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(130, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
              child: Padding(
                padding: EdgeInsets.all(2),
                child: PlayerWidget(),
              ),
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
            child: Padding(
              padding: EdgeInsets.all(2),
              child: PlayerWidget(),
            ),
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
            child: Padding(
              padding: EdgeInsets.all(1),
              child: BoxWidget(),
            ),
          ),
        ],
      );
    }

    // --- ゴール（空） ---
    if (isGoal) {
      return Container(
        color: goalBgColor,
        child: const GoalMarkerWidget(),
      );
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
    this.remainingBoxes = 0,
    this.totalBoxes = 0,
  });

  final void Function(Direction) onMove;
  final bool enabled;
  final bool isSolved;
  final int remainingBoxes;
  final int totalBoxes;

  @override
  Widget build(BuildContext context) {
    const btnSize = 60.0;

    const activeColor = Color(0xFF5D4037);
    final disabledColor = Colors.grey.shade400;

    Widget dirButton(Direction dir, String label) {
      final arrowColor = enabled ? activeColor : disabledColor;
      return SizedBox(
        width: btnSize,
        height: btnSize,
        child: Tooltip(
          message: label,
          child: Material(
            color: enabled ? const Color(0xFFF5E6CC) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(14),
            elevation: enabled ? 3 : 1,
            shadowColor: const Color(0x40000000),
            child: InkWell(
              onTap: enabled ? () => onMove(dir) : null,
              borderRadius: BorderRadius.circular(14),
              splashColor: const Color(0x308D6E63),
              highlightColor: const Color(0x188D6E63),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: enabled
                        ? const Color(0xFF8D6E63)
                        : Colors.grey.shade300,
                    width: enabled ? 1.5 : 1.0,
                  ),
                  gradient: enabled
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFF9EDDA),
                            Color(0xFFF0DDBF),
                          ],
                        )
                      : null,
                ),
                child: CustomPaint(
                  painter: ArrowPainter(
                    direction: dir,
                    color: arrowColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // --- 中央ステータスチップ ---
    Widget centerChip() {
      final String chipText;
      final Color chipBg;
      final Color chipFg;

      if (isSolved) {
        chipText = '完了';
        chipBg = const Color(0xFFE8F5E9);
        chipFg = const Color(0xFF388E3C);
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: chipFg.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            chipText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: chipFg,
              letterSpacing: 0.3,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          dirButton(Direction.up, '上'),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              dirButton(Direction.left, '左'),
              SizedBox(
                width: btnSize + 8,
                height: btnSize,
                child: Center(
                  child: centerChip(),
                ),
              ),
              dirButton(Direction.right, '右'),
            ],
          ),
          const SizedBox(height: 4),
          dirButton(Direction.down, '下'),
        ],
      ),
    );
  }
}
