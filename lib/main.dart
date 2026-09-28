import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_logic.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const BlockBlastApp());
}

const _background = Color(0xFF1B2A4E);
const _boardColor = Color(0xFF121C36);
const _emptyCell = Color(0xFF22305A);
const _muted = Color(0xFF9FB0D8);
const _accent = Color(0xFFFFB400);
const _reviveColor = Color(0xFF3ECF8E);
const _restartColor = Color(0xFF3A86FF);
const _palette = [
  Color(0xFFFF5A5F),
  Color(0xFFFFB400),
  Color(0xFF3ECF8E),
  Color(0xFF3A86FF),
  Color(0xFF8338EC),
  Color(0xFFFF7B00),
  Color(0xFF06D6A0),
  Color(0xFFEF476F),
];
const _clearDuration = Duration(milliseconds: 300);

typedef _Preview = ({int index, int row, int col});

class BlockBlastApp extends StatelessWidget {
  const BlockBlastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Block Blast',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _background,
        useMaterial3: true,
      ),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  static const _bestKey = 'best_score';

  final _game = Game();
  final _boardKey = GlobalKey();
  int _best = 0;
  _Preview? _preview;
  Map<Cell, int> _clearing = {};
  int _clearId = 0;
  String? _comboText;
  int _comboId = 0;
  bool _showGameOver = false;

  @override
  void initState() {
    super.initState();
    _loadBest();
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _best = prefs.getInt(_bestKey) ?? 0);
  }

  Future<void> _saveBest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bestKey, _best);
  }

  /// Ô trên bàn cờ mà góc trên-trái của khối đang kéo sẽ rơi vào, nếu đặt được.
  _Preview? _previewFor(DragTargetDetails<int> details, double cellSize) {
    final piece = _game.tray[details.data];
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (piece == null || box == null) return null;
    final local = box.globalToLocal(details.offset);
    final row = (local.dy / cellSize).round(), col = (local.dx / cellSize).round();
    if (!_game.canPlace(piece.shape, row, col)) return null;
    return (index: details.data, row: row, col: col);
  }

  void _onMove(DragTargetDetails<int> details, double cellSize) {
    final next = _previewFor(details, cellSize);
    if (next != _preview) setState(() => _preview = next);
  }

  void _onDrop(DragTargetDetails<int> details, double cellSize) {
    final target = _previewFor(details, cellSize);
    setState(() {
      _preview = null;
      if (target != null) _place(target);
    });
  }

  void _place(_Preview target) {
    final result = _game.place(target.index, target.row, target.col);
    HapticFeedback.lightImpact();

    if (result.lines > 0) {
      _clearing = result.cleared;
      final id = ++_clearId;
      Future.delayed(_clearDuration, () {
        if (mounted && id == _clearId) setState(() => _clearing = {});
      });
      _comboText = _game.combo > 1
          ? 'Combo x${_game.combo}!'
          : result.lines > 1
              ? '${result.lines} hàng!'
              : 'Tuyệt!';
      _comboId++;
    }

    if (_game.score > _best) {
      _best = _game.score;
      _saveBest();
    }

    if (_game.isGameOver) {
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _showGameOver = true);
      });
    }
  }

  void _revive() => setState(() {
        _game.revive();
        _showGameOver = false;
      });

  void _restart() => setState(() {
        _game.reset();
        _showGameOver = false;
        _clearing = {};
        _comboText = null;
      });

  @override
  Widget build(BuildContext context) {
    final boardSide = min(MediaQuery.sizeOf(context).width - 44, 428.0);
    final cellSize = boardSide / boardSize;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Vùng thả phủ cả màn hình: khi đặt khối ở hàng dưới cùng,
            // ngón tay nằm dưới bàn cờ (vì khối được nhấc lên trên ngón tay).
            DragTarget<int>(
              onMove: (d) => _onMove(d, cellSize),
              onLeave: (_) => setState(() => _preview = null),
              onAcceptWithDetails: (d) => _onDrop(d, cellSize),
              builder: (context, _, __) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(boardSide + 12),
                    const SizedBox(height: 16),
                    _board(boardSide, cellSize),
                    const SizedBox(height: 24),
                    _tray(boardSide + 12, cellSize),
                  ],
                ),
              ),
            ),
            if (_comboText != null) _comboOverlay(),
            if (_showGameOver) _gameOverOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _header(double width) {
    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _stat('ĐIỂM', _game.score, Colors.white, 40, CrossAxisAlignment.start),
          _stat('KỶ LỤC', _best, _accent, 22, CrossAxisAlignment.end),
        ],
      ),
    );
  }

  Widget _stat(String label, int value, Color color, double size, CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: _muted, letterSpacing: 1)),
        Text('$value', style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: color, height: 1.1)),
      ],
    );
  }

  Widget _board(double side, double cellSize) {
    final preview = _preview;
    final piece = preview == null ? null : _game.tray[preview.index];
    final ghost = <Cell>{
      if (preview != null && piece != null)
        for (final (r, c) in piece.shape.cells) (preview.row + r, preview.col + c),
    };

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: _boardColor, borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        key: _boardKey,
        width: side,
        height: side,
        child: Column(
          children: [
            for (var r = 0; r < boardSize; r++)
              Row(
                children: [
                  for (var c = 0; c < boardSize; c++)
                    SizedBox(width: cellSize, height: cellSize, child: _cell(r, c, ghost, piece)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(int r, int c, Set<Cell> ghost, Piece? piece) {
    final color = _game.grid[r][c];
    if (color != null) return _Block(color: _palette[color]);
    if (piece != null && ghost.contains((r, c))) {
      return Opacity(opacity: 0.45, child: _Block(color: _palette[piece.color]));
    }
    final cleared = _clearing[(r, c)];
    if (cleared != null) {
      return TweenAnimationBuilder<double>(
        key: ValueKey(_clearId),
        tween: Tween(begin: 1, end: 0),
        duration: _clearDuration,
        builder: (_, v, child) => Transform.scale(scale: v, child: Opacity(opacity: v, child: child)),
        child: _Block(color: _palette[cleared]),
      );
    }
    return const _Block(color: _emptyCell, flat: true);
  }

  Widget _tray(double width, double cellSize) {
    final small = min(cellSize * 0.5, 22.0);
    return SizedBox(
      width: width,
      height: small * 5 + 32,
      child: Row(
        children: [
          for (var i = 0; i < traySize; i++)
            Expanded(child: Center(child: _trayPiece(i, cellSize, small))),
        ],
      ),
    );
  }

  Widget _trayPiece(int index, double cellSize, double small) {
    final piece = _game.tray[index];
    if (piece == null) return const SizedBox.shrink();
    final shape = piece.shape;
    return Draggable<int>(
      data: index,
      feedback: _PieceView(piece, cellSize),
      childWhenDragging: const SizedBox.shrink(),
      // Nhấc khối lên trên ngón tay một ô để ngón tay không che khối.
      dragAnchorStrategy: (_, __, ___) =>
          Offset(shape.width * cellSize / 2, (shape.height + 1) * cellSize),
      onDragStarted: HapticFeedback.selectionClick,
      // Nền trong suốt để khối nhỏ (1 ô) vẫn dễ chạm.
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.all(16),
        child: _PieceView(piece, small),
      ),
    );
  }

  Widget _comboOverlay() {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.3),
        child: TweenAnimationBuilder<double>(
          key: ValueKey(_comboId),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          builder: (_, t, child) => Opacity(
            opacity: 1 - t,
            child: Transform.translate(offset: Offset(0, -40 * t), child: child),
          ),
          child: Text(
            _comboText!,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: _accent,
              shadows: [Shadow(offset: Offset(0, 3), color: Colors.black38)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gameOverOverlay() {
    return ColoredBox(
      color: const Color(0xD9080E1E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Hết chỗ đặt!', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Điểm: ${_game.score}', style: const TextStyle(fontSize: 22, color: _muted)),
            const SizedBox(height: 24),
            _button('Hồi sinh (miễn phí)', _reviveColor, _revive),
            const SizedBox(height: 12),
            _button('Chơi lại', _restartColor, _restart),
          ],
        ),
      ),
    );
  }

  Widget _button(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: 260,
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _PieceView extends StatelessWidget {
  const _PieceView(this.piece, this.cellSize);

  final Piece piece;
  final double cellSize;

  @override
  Widget build(BuildContext context) {
    final shape = piece.shape;
    return SizedBox(
      width: shape.width * cellSize,
      height: shape.height * cellSize,
      child: Stack(
        children: [
          for (final (r, c) in shape.cells)
            Positioned(
              left: c * cellSize,
              top: r * cellSize,
              width: cellSize,
              height: cellSize,
              child: _Block(color: _palette[piece.color]),
            ),
        ],
      ),
    );
  }
}

/// Một ô vuông; `flat` là ô trống, còn lại có hiệu ứng nổi 3D nhẹ.
class _Block extends StatelessWidget {
  const _Block({required this.color, this.flat = false});

  final Color color;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(5),
          gradient: flat
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(color, Colors.white, 0.35)!, color, color, Color.lerp(color, Colors.black, 0.3)!],
                  stops: const [0, 0.18, 0.82, 1],
                ),
        ),
      ),
    );
  }
}
