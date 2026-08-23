import 'package:device_security_guard/device_security_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('attestation providers are disabled by default', () {
    const options = SecurityOptions();

    expect(options.enablePlayIntegrity, isFalse);
    expect(options.enableAppAttest, isFalse);
    expect(options.attestationAdapter, isNull);
  });

  test('enabled Play Integrity requires an adapter', () {
    const options = SecurityOptions(enablePlayIntegrity: true);

    expect(options.validate, throwsArgumentError);
  });

  test('enabled App Attest requires an adapter', () {
    const options = SecurityOptions(enableAppAttest: true);

    expect(options.validate, throwsArgumentError);
  });
}
