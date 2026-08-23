import 'dart:collection';

/// A security-relevant condition covered by the package.
enum SecuritySignal {
  debugger,
  emulator,
  adbEnabled,
  hooking,
  repackaging,
  root,
  jailbreak,
  bootloaderUnlocked,
}

/// The deliberately small result space for a local security check.
enum CheckStatus { detected, notDetected, inconclusive }

/// A host platform supported by the plugin.
enum SecurityPlatform { android, iOS }

/// A platform attestation provider.
enum AttestationProvider { playIntegrity, appAttest }

/// The server-verified outcome of platform attestation.
enum AttestationStatus { trusted, untrusted, inconclusive }

/// The action recommended by a policy evaluation.
enum RecommendedAction { allow, block, indeterminate }

/// Result of checking one [signal].
final class SignalResult {
  const SignalResult({
    required this.signal,
    required this.status,
    required this.reasonCode,
  });

  final SecuritySignal signal;
  final CheckStatus status;
  final String reasonCode;
}

/// Normalized result returned by a host-provided attestation adapter.
final class AttestationAssessment {
  const AttestationAssessment({
    required this.provider,
    required this.status,
    required this.reasonCode,
  });

  final AttestationProvider provider;
  final AttestationStatus status;
  final String reasonCode;
}

/// A point-in-time assessment of the current app and device environment.
final class SecurityAssessment {
  SecurityAssessment({
    required this.platform,
    required this.operatingSystemVersion,
    required this.assessedAt,
    required Map<SecuritySignal, SignalResult> signals,
    List<AttestationAssessment> attestations = const [],
  }) : signals = UnmodifiableMapView(Map.of(signals)),
       attestations = List.unmodifiable(attestations);

  final SecurityPlatform platform;
  final String operatingSystemVersion;
  final DateTime assessedAt;
  final Map<SecuritySignal, SignalResult> signals;
  final List<AttestationAssessment> attestations;

  SecurityAssessment withAttestations(List<AttestationAssessment> values) =>
      SecurityAssessment(
        platform: platform,
        operatingSystemVersion: operatingSystemVersion,
        assessedAt: assessedAt,
        signals: signals,
        attestations: values,
      );
}

/// Result of evaluating a [SecurityAssessment] against a policy.
final class PolicyDecision {
  PolicyDecision({required this.action, required List<String> reasonCodes})
    : reasonCodes = List.unmodifiable(reasonCodes);

  final RecommendedAction action;
  final List<String> reasonCodes;
}
