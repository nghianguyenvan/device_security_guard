library;

import 'device_security_guard_platform_interface.dart';
import 'src/attestation.dart';
import 'src/models.dart';
import 'src/security_options.dart';

export 'src/attestation.dart';
export 'src/circular_77_policy.dart';
export 'src/models.dart';
export 'src/security_options.dart';

/// Entry point for local device assessment and optional attestation.
abstract final class DeviceSecurityGuard {
  static Future<SecurityAssessment> assess({
    SecurityOptions options = const SecurityOptions(),
  }) async {
    options.validate();
    final platformClient = DeviceSecurityGuardPlatform.instance;
    final local = await platformClient.assessLocal(options);
    final provider = switch (local.platform) {
      SecurityPlatform.android when options.enablePlayIntegrity =>
        AttestationProvider.playIntegrity,
      SecurityPlatform.iOS when options.enableAppAttest =>
        AttestationProvider.appAttest,
      _ => null,
    };
    if (provider == null) {
      return local;
    }

    final attestation = await _assessAttestation(
      provider,
      options.attestationAdapter!,
      platformClient,
    );
    return local.withAttestations([attestation]);
  }

  static Future<AttestationAssessment> _assessAttestation(
    AttestationProvider provider,
    AttestationAdapter adapter,
    DeviceSecurityGuardPlatform platformClient,
  ) async {
    try {
      final value = await adapter.assess(provider, platformClient);
      return value.provider == provider
          ? value
          : AttestationAssessment(
              provider: provider,
              status: AttestationStatus.inconclusive,
              reasonCode: 'adapter_provider_mismatch',
            );
    } catch (_) {
      return AttestationAssessment(
        provider: provider,
        status: AttestationStatus.inconclusive,
        reasonCode: 'attestation_error',
      );
    }
  }
}
