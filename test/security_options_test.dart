import 'package:device_security_guard/device_security_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('attestation providers are disabled by default', () {
    final options = SecurityOptions();

    expect(options.enablePlayIntegrity, isFalse);
    expect(options.enableAppAttest, isFalse);
    expect(options.attestationAdapter, isNull);
  });

  test('enabled Play Integrity requires an adapter', () {
    final options = SecurityOptions(enablePlayIntegrity: true);

    expect(options.validate, throwsArgumentError);
  });

  test('enabled App Attest requires an adapter', () {
    final options = SecurityOptions(enableAppAttest: true);

    expect(options.validate, throwsArgumentError);
  });

  test('rejects malformed signing identities', () {
    expect(
      () => SecurityOptions(
        expectedAndroidCertificateSha256: {'not-a-sha256'},
      ).validate(),
      throwsArgumentError,
    );
    expect(
      () => SecurityOptions(expectedIosTeamIdentifiers: {' '}).validate(),
      throwsArgumentError,
    );
  });

  test('copies signing identity sets', () {
    final certificates = <String>{'A' * 64};
    final teams = <String>{'ABCDE12345'};
    final options = SecurityOptions(
      expectedAndroidCertificateSha256: certificates,
      expectedIosTeamIdentifiers: teams,
    );

    certificates.clear();
    teams.clear();

    expect(options.expectedAndroidCertificateSha256, hasLength(1));
    expect(options.expectedIosTeamIdentifiers, {'ABCDE12345'});
  });
}
