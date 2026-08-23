import 'package:device_security_guard_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.vannghia/device_security_guard');
  var assessmentCalls = 0;

  setUp(() {
    assessmentCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          assessmentCalls++;
          return <String, Object?>{
            'schemaVersion': 1,
            'platform': 'android',
            'operatingSystemVersion': '16',
            'assessedAtEpochMs': 1787443200000,
            'signals': <String, Object?>{},
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('tự kiểm tra khi mở ứng dụng', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(assessmentCalls, 1);
    expect(find.text('Khuyến nghị: indeterminate'), findsOneWidget);
  });

  testWidgets('kiểm tra lại trước thao tác nhạy cảm', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kiểm tra trước giao dịch'));
    await tester.pumpAndSettle();

    expect(assessmentCalls, 2);
  });

  testWidgets('kiểm tra lại khi ứng dụng resume', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(assessmentCalls, 2);
  });
}
