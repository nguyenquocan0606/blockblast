import 'dart:math';
import 'dart:ui';

/// Ngón tay đi 1px thì khối đi [dragGain] px, để với ra mép bàn cờ
/// mà không phải đưa tay xa.
const double dragGain = 1.5;

/// Vị trí góc trên-trái của khối đang kéo (toạ độ màn hình).
///
/// Khối bị giữ trong mép trái/phải và mép trên của bàn cờ, nên đẩy quá tay
/// vẫn đặt được vào hàng/cột sát mép. Mép dưới để mở để kéo khối về khay (huỷ).
Offset dragPiecePosition({
  required Offset pieceStart,
  required Offset pointerStart,
  required Offset pointer,
  required Rect board,
  required Size piece,
}) {
  final moved = pieceStart + (pointer - pointerStart) * dragGain;
  final maxLeft = max(board.left, board.right - piece.width);
  return Offset(moved.dx.clamp(board.left, maxLeft), max(moved.dy, board.top));
}
