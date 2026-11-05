import 'package:flutter_test/flutter_test.dart';
import 'package:master_chess_game/main.dart';

void main() {
  testWidgets('Master Chess home renders', (tester) async {
    await tester.pumpWidget(const MasterChessApp());
    expect(find.text('MASTER CHESS'), findsOneWidget);
    expect(find.text('LIVE MATCH'), findsOneWidget);
  });
}
