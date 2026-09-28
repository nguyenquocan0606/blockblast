import 'dart:math';

const int boardSize = 8;
const int colorCount = 8;
const int traySize = 3;

typedef Cell = (int row, int col);

class Shape {
  const Shape(this.cells, this.height, this.width);

  /// Tạo hình từ chuỗi: '#' là ô có khối, '.' là ô trống, '\n' xuống hàng.
  factory Shape.parse(String pattern) {
    final rows = pattern.split('\n');
    final cells = <Cell>[
      for (var r = 0; r < rows.length; r++)
        for (var c = 0; c < rows[r].length; c++)
          if (rows[r][c] == '#') (r, c),
    ];
    return Shape(cells, rows.length, rows.first.length);
  }

  final List<Cell> cells;
  final int height;
  final int width;
}

final List<Shape> allShapes = const [
  '#', '##', '#\n#', '###', '#\n#\n#', '####', '#\n#\n#\n#', '#####', '#\n#\n#\n#\n#',
  '##\n##', '###\n###\n###', '###\n###', '##\n##\n##',
  '##\n#.', '##\n.#', '#.\n##', '.#\n##',
  '###\n#..', '###\n..#', '#..\n###', '..#\n###',
  '#.\n#.\n##', '.#\n.#\n##', '##\n#.\n#.', '##\n.#\n.#',
  '###\n.#.', '.#.\n###', '#.\n##\n#.', '.#\n##\n.#',
  '##.\n.##', '.##\n##.', '#.\n##\n.#', '.#\n##\n#.',
].map(Shape.parse).toList(growable: false);

class Piece {
  const Piece(this.shape, this.color);

  final Shape shape;
  final int color;
}

class PlaceResult {
  const PlaceResult(this.lines, this.cleared);

  final int lines;

  /// Các ô vừa bị xoá cùng màu của chúng (để chạy hiệu ứng).
  final Map<Cell, int> cleared;
}

class Game {
  Game({Random? random}) : _random = random ?? Random() {
    reset();
  }

  final Random _random;
  late List<List<int?>> grid;
  late List<Piece?> tray;
  int score = 0;
  int combo = 0;

  void reset() {
    grid = List.generate(boardSize, (_) => List<int?>.filled(boardSize, null));
    score = 0;
    combo = 0;
    tray = _newTray(allShapes);
  }

  bool canPlace(Shape shape, int row, int col) => shape.cells.every((cell) {
        final r = row + cell.$1, c = col + cell.$2;
        return r >= 0 && r < boardSize && c >= 0 && c < boardSize && grid[r][c] == null;
      });

  bool fitsAnywhere(Shape shape) {
    for (var r = 0; r <= boardSize - shape.height; r++) {
      for (var c = 0; c <= boardSize - shape.width; c++) {
        if (canPlace(shape, r, c)) return true;
      }
    }
    return false;
  }

  bool get isGameOver => !tray.any((p) => p != null && fitsAnywhere(p.shape));

  PlaceResult place(int index, int row, int col) {
    final piece = tray[index]!;
    assert(canPlace(piece.shape, row, col));
    for (final (r, c) in piece.shape.cells) {
      grid[row + r][col + c] = piece.color;
    }
    tray[index] = null;
    score += piece.shape.cells.length;

    final fullRows = [
      for (var r = 0; r < boardSize; r++)
        if (grid[r].every((v) => v != null)) r,
    ];
    final fullCols = [
      for (var c = 0; c < boardSize; c++)
        if (grid.every((row) => row[c] != null)) c,
    ];
    final cleared = <Cell, int>{
      for (final r in fullRows)
        for (var c = 0; c < boardSize; c++) (r, c): grid[r][c]!,
      for (final c in fullCols)
        for (var r = 0; r < boardSize; r++) (r, c): grid[r][c]!,
    };
    for (final (r, c) in cleared.keys) {
      grid[r][c] = null;
    }

    final lines = fullRows.length + fullCols.length;
    if (lines > 0) {
      combo++;
      score += 10 * lines * lines * combo;
    } else {
      combo = 0;
    }

    if (tray.every((p) => p == null)) tray = _newTray(allShapes);
    return PlaceResult(lines, cleared);
  }

  /// Hồi sinh miễn phí, không giới hạn: phát khay mới mà mọi khối đều đặt vừa.
  /// Luôn có ít nhất khối 1 ô vừa, vì hàng/cột đầy sẽ bị xoá nên bàn không bao giờ kín.
  void revive() => tray = _newTray(allShapes.where(fitsAnywhere).toList());

  List<Piece?> _newTray(List<Shape> pool) => List.generate(
        traySize,
        (_) => Piece(pool[_random.nextInt(pool.length)], _random.nextInt(colorCount)),
      );
}
