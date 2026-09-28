import 'package:blockblast/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('game mở lên với điểm 0 và 3 khối trong khay', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BlockBlastApp());
    await tester.pump();
    expect(find.text('ĐIỂM'), findsOneWidget);
    expect(find.text('KỶ LỤC'), findsOneWidget);
    expect(find.text('Hết chỗ đặt!'), findsNothing);
  });
}
