import 'dart:ui';

import 'package:blockblast/drag_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const board = Rect.fromLTWH(100, 100, 400, 400);
  const piece = Size(100, 50);

  Offset move(Offset pointer, {Offset pieceStart = const Offset(250, 300)}) => dragPiecePosition(
        pieceStart: pieceStart,
        pointerStart: const Offset(300, 400),
        pointer: pointer,
        board: board,
        piece: piece,
      );

  test('khối đi xa hơn ngón tay theo hệ số dragGain', () {
    expect(move(const Offset(320, 380)), const Offset(250 + 20 * dragGain, 300 - 20 * dragGain));
  });

  test('đẩy quá mép trái/phải/trên thì khối dừng sát mép bàn cờ', () {
    expect(move(const Offset(0, 400)).dx, board.left);
    expect(move(const Offset(900, 400)).dx, board.right - piece.width);
    expect(move(const Offset(300, 0)).dy, board.top);
  });

  test('mép dưới để mở để kéo khối về khay', () {
    expect(move(const Offset(300, 700)).dy, 300 + 300 * dragGain);
  });
}
