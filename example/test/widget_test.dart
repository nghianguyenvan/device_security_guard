import 'package:device_security_guard_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hiển thị trạng thái ban đầu và nút kiểm tra', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Chưa kiểm tra'), findsOneWidget);
    expect(find.text('Kiểm tra thiết bị'), findsOneWidget);
  });
}
