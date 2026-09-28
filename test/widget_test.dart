import 'package:blockblast/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> startGame(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BlockBlastApp());
    await tester.pump();
  }

  testWidgets('game mở lên với điểm 0 và 3 khối trong khay', (tester) async {
    await startGame(tester);
    expect(find.text('ĐIỂM'), findsOneWidget);
    expect(find.text('KỶ LỤC'), findsOneWidget);
    expect(find.byKey(const ValueKey('tray-0')), findsOneWidget);
    expect(find.text('Hết chỗ đặt!'), findsNothing);
  });

  testWidgets('kéo khối lên bàn cờ trống thì đặt được và cộng điểm', (tester) async {
    await startGame(tester);
    // Kéo mạnh lên trên: khối bị giữ ở mép trên bàn cờ nên luôn đặt vừa.
    await tester.drag(find.byKey(const ValueKey('tray-0')), const Offset(0, -400));
    await tester.pump();
    expect(find.text('0'), findsNothing); // cả điểm lẫn kỷ lục đã > 0
  });

  testWidgets('chạm rồi thả mà không kéo thì không đặt khối', (tester) async {
    await startGame(tester);
    await tester.tap(find.byKey(const ValueKey('tray-0')));
    await tester.pump();
    expect(find.text('0'), findsNWidgets(2));
  });
}
