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

  test('copies signing identity sets', () {
    final certificates = <String>{'A' * 64};
    final teams = <String>{'ABCDE12345'};
    final options = SecurityOptions(
      expectedAndroidCertificateSha256: certificates,
      expectedIosApplicationIdentifierPrefixes: teams,
    );

    certificates.clear();
    teams.clear();

    expect(options.expectedAndroidCertificateSha256, hasLength(1));
    expect(options.expectedIosApplicationIdentifierPrefixes, {'ABCDE12345'});
  });
}
