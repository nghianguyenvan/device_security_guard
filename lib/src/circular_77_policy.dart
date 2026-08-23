import 'models.dart';

/// Policy helper aligned with the device-side signs in Circular 77/2025.
abstract final class Circular77Policy {
  static PolicyDecision evaluate(
    SecurityAssessment assessment, {
    bool failClosed = false,
  }) {
    final blocked = <String>[
      ...assessment.signals.values
          .where((result) => result.status == CheckStatus.detected)
          .map((result) => result.reasonCode),
      ...assessment.attestations
          .where((result) => result.status == AttestationStatus.untrusted)
          .map((result) => result.reasonCode),
    ];
    if (blocked.isNotEmpty) {
      return PolicyDecision(
        action: RecommendedAction.block,
        reasonCodes: blocked,
      );
    }

    final inconclusive = <String>[
      ...assessment.signals.values
          .where((result) => result.status == CheckStatus.inconclusive)
          .map((result) => result.reasonCode),
      ...assessment.attestations
          .where((result) => result.status == AttestationStatus.inconclusive)
          .map((result) => result.reasonCode),
    ];
    if (inconclusive.isNotEmpty) {
      return PolicyDecision(
        action: failClosed
            ? RecommendedAction.block
            : RecommendedAction.indeterminate,
        reasonCodes: inconclusive,
      );
    }

    return PolicyDecision(
      action: RecommendedAction.allow,
      reasonCodes: const [],
    );
  }
}
