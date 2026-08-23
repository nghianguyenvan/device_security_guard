import 'attestation.dart';

/// Cấu hình cho một lần đánh giá bảo mật thiết bị.
final class SecurityOptions {
  SecurityOptions({
    this.enablePlayIntegrity = false,
    this.enableAppAttest = false,
    Set<String> expectedAndroidCertificateSha256 = const {},
    Set<String> expectedIosTeamIdentifiers = const {},
    this.attestationAdapter,
  }) : expectedAndroidCertificateSha256 = Set.unmodifiable(
         expectedAndroidCertificateSha256,
       ),
       expectedIosTeamIdentifiers = Set.unmodifiable(
         expectedIosTeamIdentifiers,
       );

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
    final certificatePattern = RegExp(
      r'^(?:[0-9A-Fa-f]{64}|(?:[0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2})$',
    );
    for (final certificate in expectedAndroidCertificateSha256) {
      if (!certificatePattern.hasMatch(certificate.trim())) {
        throw ArgumentError.value(
          certificate,
          'expectedAndroidCertificateSha256',
          'Mỗi certificate phải là SHA-256 gồm 64 ký tự hex, có thể ngăn cách bằng dấu hai chấm.',
        );
      }
    }
    final teamIdentifierPattern = RegExp(r'^[A-Z0-9]{10}$');
    for (final teamIdentifier in expectedIosTeamIdentifiers) {
      if (!teamIdentifierPattern.hasMatch(teamIdentifier)) {
        throw ArgumentError.value(
          teamIdentifier,
          'expectedIosTeamIdentifiers',
          'Mỗi Apple Team ID phải gồm 10 ký tự in hoa hoặc chữ số.',
        );
      }
    }
  }
}
