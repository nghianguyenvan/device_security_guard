import 'dart:typed_data';

import 'models.dart';

/// Connects platform attestation primitives to the host application's backend.
abstract interface class AttestationAdapter {
  Future<AttestationAssessment> assess(
    AttestationProvider provider,
    AttestationClient client,
  );
}

/// Client-side primitives used by a host-provided [AttestationAdapter].
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
