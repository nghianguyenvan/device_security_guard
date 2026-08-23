import 'attestation.dart';

/// Configuration for a device security assessment.
final class SecurityOptions {
  const SecurityOptions({
    this.enablePlayIntegrity = false,
    this.enableAppAttest = false,
    this.expectedAndroidCertificateSha256 = const {},
    this.expectedIosTeamIdentifiers = const {},
    this.attestationAdapter,
  });

  final bool enablePlayIntegrity;
  final bool enableAppAttest;
  final Set<String> expectedAndroidCertificateSha256;
  final Set<String> expectedIosTeamIdentifiers;
  final AttestationAdapter? attestationAdapter;

  void validate() {
    if ((enablePlayIntegrity || enableAppAttest) &&
        attestationAdapter == null) {
      throw ArgumentError(
        'An AttestationAdapter is required when attestation is enabled.',
      );
    }
  }
}
