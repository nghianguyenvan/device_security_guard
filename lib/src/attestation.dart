import 'dart:typed_data';

import 'models.dart';

/// Kết nối primitive attestation của nền tảng với backend ứng dụng chủ.
abstract interface class AttestationAdapter {
  Future<AttestationAssessment> assess(
    AttestationProvider provider,
    AttestationClient client,
  );
}

/// Primitive phía client dành cho [AttestationAdapter] do ứng dụng chủ cung cấp.
abstract interface class AttestationClient {
  Future<String> requestPlayIntegrityToken({
    required int cloudProjectNumber,
    required String requestHash,
  });

  Future<bool> isAppAttestSupported();

  Future<String> generateAppAttestKey();

  Future<Uint8List> attestAppAttestKey({
    required String keyId,
    required Uint8List clientDataHash,
  });

  Future<Uint8List> generateAppAttestAssertion({
    required String keyId,
    required Uint8List clientDataHash,
  });
}
