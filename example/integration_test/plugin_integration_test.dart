import 'package:device_security_guard/device_security_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('trả assessment native của nền tảng', (_) async {
    final assessment = await DeviceSecurityGuard.assess();

    expect(assessment.signals, isNotEmpty);
    expect(
      assessment.platform,
      anyOf(SecurityPlatform.android, SecurityPlatform.iOS),
    );
  });
}
