import 'dart:math';

import 'package:blockblast/game_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Game game;

  setUp(() => game = Game(random: Random(1)));

  /// Bàn cờ caro: không hàng/cột nào đầy, chỉ khối 1 ô còn đặt vừa.
  void fillCheckerboard() {
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        game.grid[r][c] = (r + c).isOdd ? 0 : null;
      }
    }
  }

  test('đặt khối lấp ô, cộng điểm và bỏ khối khỏi khay', () {
    game.tray[0] = Piece(Shape.parse('##'), 2);
    game.place(0, 3, 4);
    expect(game.grid[3][4], 2);
    expect(game.grid[3][5], 2);
    expect(game.score, 2);
    expect(game.tray[0], isNull);
  });

  test('không đặt được ra ngoài bàn hoặc chồng lên khối khác', () {
    final domino = Shape.parse('##');
    expect(game.canPlace(domino, 0, 7), isFalse);
    game.grid[2][2] = 0;
    expect(game.canPlace(domino, 2, 1), isFalse);
    expect(game.canPlace(domino, 2, 3), isTrue);
  });

  test('xoá hàng và cột đầy cùng lúc, tính điểm theo số đường', () {
    for (var i = 1; i < boardSize; i++) {
      game.grid[0][i] = 1;
      game.grid[i][0] = 1;
    }
    game.tray[0] = Piece(Shape.parse('#'), 0);
    final result = game.place(0, 0, 0);
    expect(result.lines, 2);
    expect(result.cleared.length, 15);
    expect(game.grid.expand((row) => row).every((v) => v == null), isTrue);
    expect(game.score, 1 + 10 * 2 * 2);
  });

  test('đặt hết 3 khối thì phát khay mới', () {
    game.tray = [Piece(Shape.parse('#'), 0), null, null];
    game.place(0, 0, 0);
    expect(game.tray.every((p) => p != null), isTrue);
  });

  test('hết lượt khi không khối nào đặt vừa', () {
    fillCheckerboard();
    game.tray = [Piece(Shape.parse('##'), 0), null, null];
    expect(game.isGameOver, isTrue);
  });

  test('hồi sinh vô hạn: lần nào cũng phát khối đặt vừa', () {
    fillCheckerboard();
    for (var i = 0; i < 50; i++) {
      game.revive();
      expect(game.tray.every((p) => p != null && game.fitsAnywhere(p.shape)), isTrue);
      expect(game.isGameOver, isFalse);
    }
  });
}
