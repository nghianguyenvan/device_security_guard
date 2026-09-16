import 'package:device_security_guard/device_security_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects malformed signing identities', () {
    expect(
      () => SecurityOptions(
        expectedAndroidCertificateSha256: {'not-a-sha256'},
      ).validate(),
      throwsArgumentError,
    );
    expect(
      () => SecurityOptions(
        expectedIosApplicationIdentifierPrefixes: {' '},
      ).validate(),
      throwsArgumentError,
    );
  });
}
