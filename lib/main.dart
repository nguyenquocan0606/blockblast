import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'drag_math.dart';
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

/// Khối đang kéo; các toạ độ là toạ độ màn hình.
typedef _Drag = ({int index, Offset pieceStart, Offset pointerStart, Offset position});

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
  final _stackKey = GlobalKey();
  int _best = 0;
  _Drag? _drag;
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

  Rect? _boardRect() {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  void _dragStart(int index, Offset pointer, double cellSize) {
    if (_drag != null) return; // bỏ qua ngón tay thứ hai
    final shape = _game.tray[index]!.shape;
    // Nhấc khối lên trên ngón tay một ô để ngón tay không che khối.
    final pieceStart = pointer - Offset(shape.width * cellSize / 2, (shape.height + 1) * cellSize);
    HapticFeedback.selectionClick();
    setState(() => _drag = (index: index, pieceStart: pieceStart, pointerStart: pointer, position: pieceStart));
    _dragUpdate(index, pointer, cellSize);
  }

  void _dragUpdate(int index, Offset pointer, double cellSize) {
    final drag = _drag;
    final board = _boardRect();
    if (drag == null || drag.index != index || board == null) return;
    final shape = _game.tray[index]!.shape;
    final position = dragPiecePosition(
      pieceStart: drag.pieceStart,
      pointerStart: drag.pointerStart,
      pointer: pointer,
      board: board,
      piece: Size(shape.width * cellSize, shape.height * cellSize),
    );
    final row = ((position.dy - board.top) / cellSize).round();
    final col = ((position.dx - board.left) / cellSize).round();
    setState(() {
      _drag = (index: index, pieceStart: drag.pieceStart, pointerStart: drag.pointerStart, position: position);
      _preview = _game.canPlace(shape, row, col) ? (index: index, row: row, col: col) : null;
    });
  }

  void _dragEnd(int index) {
    if (_drag?.index != index) return;
    final target = _preview;
    setState(() {
      _drag = null;
      _preview = null;
      if (target != null) _place(target);
    });
  }

  /// Chạm rồi thả mà không kéo: trả khối về khay, không đặt.
  void _dragCancel(int index) {
    if (_drag?.index != index) return;
    setState(() {
      _drag = null;
      _preview = null;
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
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          // Bàn cờ phải vừa cả chiều ngang lẫn chiều dọc (màn hình thấp như iPhone SE).
          final boardSide = max(
            0.0,
            min(min(constraints.maxWidth - 44, constraints.maxHeight - _reservedHeight), 428.0),
          );
          return _content(boardSide, boardSide / boardSize);
        }),
      ),
    );
  }

  /// Chiều cao cố định ngoài bàn cờ: điểm số, khoảng cách, viền bàn và khay khối.
  static const _reservedHeight = 60 + 16 + 12 + 24 + _maxTrayHeight + 16;
  static const _maxTrayHeight = _maxTrayCell * 5 + 32;
  static const _maxTrayCell = 22.0;

  Widget _content(double boardSide, double cellSize) {
    final drag = _drag;
    return Stack(
      key: _stackKey,
      fit: StackFit.expand,
      children: [
        Center(
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
        if (drag != null) _draggedPiece(drag, cellSize),
        if (_comboText != null) _comboOverlay(),
        if (_showGameOver) _gameOverOverlay(),
      ],
    );
  }

  Widget _draggedPiece(_Drag drag, double cellSize) {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return const SizedBox.shrink();
    final local = stackBox.globalToLocal(drag.position);
    return Positioned(
      left: local.dx,
      top: local.dy,
      child: IgnorePointer(child: _PieceView(_game.tray[drag.index]!, cellSize)),
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
    final small = min(cellSize * 0.5, _maxTrayCell);
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
    // Giữ nguyên GestureDetector khi đang kéo (chỉ ẩn khối), nếu không cử chỉ sẽ bị huỷ.
    return GestureDetector(
      key: ValueKey('tray-$index'),
      behavior: HitTestBehavior.opaque, // khối nhỏ (1 ô) vẫn dễ chạm
      onPanDown: (d) => _dragStart(index, d.globalPosition, cellSize),
      onPanUpdate: (d) => _dragUpdate(index, d.globalPosition, cellSize),
      onPanEnd: (_) => _dragEnd(index),
      onPanCancel: () => _dragCancel(index),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Opacity(
          opacity: _drag?.index == index ? 0 : 1,
          child: _PieceView(piece, small),
        ),
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
