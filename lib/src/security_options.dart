/// Cấu hình cho một lần đánh giá bảo mật thiết bị.
final class SecurityOptions {
  SecurityOptions({
    Set<String> expectedAndroidCertificateSha256 = const {},
    Set<String> expectedIosApplicationIdentifierPrefixes = const {},
  }) : expectedAndroidCertificateSha256 = Set.unmodifiable(
         expectedAndroidCertificateSha256,
       ),
       expectedIosApplicationIdentifierPrefixes = Set.unmodifiable(
         expectedIosApplicationIdentifierPrefixes,
       );

  final Set<String> expectedAndroidCertificateSha256;

  /// App ID Prefix đứng trước dấu chấm trong Keychain access group của app iOS.
  final Set<String> expectedIosApplicationIdentifierPrefixes;
  void validate() {
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
    final applicationIdentifierPrefixPattern = RegExp(r'^[A-Z0-9]{10}$');
    for (final prefix in expectedIosApplicationIdentifierPrefixes) {
      if (!applicationIdentifierPrefixPattern.hasMatch(prefix)) {
        throw ArgumentError.value(
          prefix,
          'expectedIosApplicationIdentifierPrefixes',
          'Mỗi Apple App ID Prefix phải gồm 10 ký tự in hoa hoặc chữ số.',
        );
      }
    }
  }
}
