import 'models.dart';
import 'required_signals.dart';

/// Policy helper cho các dấu hiệu phía thiết bị trong Thông tư 77/2025/TT-NHNN.
abstract final class Circular77Policy {
  static PolicyDecision evaluate(
    SecurityAssessment assessment, {
    bool failClosed = false,
  }) {
    final blocked = <String>[
      ...assessment.signals.values
          .where((result) => result.status == CheckStatus.detected)
          .map((result) => result.reasonCode),
    ];
    if (blocked.isNotEmpty) {
      return PolicyDecision(
        action: RecommendedAction.block,
        reasonCodes: blocked,
      );
    }

    final inconclusive = <String>[
      if (requiredSignalsFor(
        assessment.platform,
      ).any((signal) => !assessment.signals.containsKey(signal)))
        'missing_signal',
      ...assessment.signals.values
          .where((result) => result.status == CheckStatus.inconclusive)
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
