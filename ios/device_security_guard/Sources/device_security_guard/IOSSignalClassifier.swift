import Foundation

internal enum NativeCheckStatus: String {
  case detected
  case notDetected
  case inconclusive
}

internal enum IOSSignalClassifier {
  private static let hookMarkers = [
    "frida", "substrate", "substitute", "libhooker", "ellekit", "cycript",
  ]

  static func hooking(
    loadedImages: [String],
    environment: [String: String]
  ) -> NativeCheckStatus {
    let values = loadedImages + [environment["DYLD_INSERT_LIBRARIES"] ?? ""]
    let detected = values.contains { value in
      let normalized = value.lowercased()
      return hookMarkers.contains(where: normalized.contains)
    }
    return detected ? .detected : .notDetected
  }

  static func repackaging(
    actualTeamIdentifier: String?,
    expectedTeamIdentifiers: Set<String>
  ) -> NativeCheckStatus {
    guard !expectedTeamIdentifiers.isEmpty,
          let actualTeamIdentifier,
          !actualTeamIdentifier.isEmpty else {
      return .inconclusive
    }
    return expectedTeamIdentifiers.contains(actualTeamIdentifier)
      ? .notDetected
      : .detected
  }

  static func jailbreak(
    existingArtifacts: Set<String>,
    canWriteOutsideSandbox: Bool
  ) -> NativeCheckStatus {
    return existingArtifacts.isEmpty && !canWriteOutsideSandbox
      ? .notDetected
      : .detected
  }
}
