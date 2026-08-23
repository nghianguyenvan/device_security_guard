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
    actualApplicationIdentifierPrefix: String?,
    expectedApplicationIdentifierPrefixes: Set<String>
  ) -> NativeCheckStatus {
    guard !expectedApplicationIdentifierPrefixes.isEmpty,
          let actualApplicationIdentifierPrefix,
          !actualApplicationIdentifierPrefix.isEmpty else {
      return .inconclusive
    }
    return expectedApplicationIdentifierPrefixes.contains(actualApplicationIdentifierPrefix)
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
