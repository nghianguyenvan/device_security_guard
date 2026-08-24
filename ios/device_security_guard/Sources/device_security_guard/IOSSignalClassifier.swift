import Foundation

internal enum NativeCheckStatus: String {
  case detected
  case notDetected
  case inconclusive
}

internal enum IOSProbeResult {
  case positive
  case negative
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
      !actualApplicationIdentifierPrefix.isEmpty
    else {
      return .inconclusive
    }
    return expectedApplicationIdentifierPrefixes.contains(actualApplicationIdentifierPrefix)
      ? .notDetected
      : .detected
  }

  static func jailbreak(
    existingArtifacts: Set<String>,
    outsideSandboxWrite: IOSProbeResult
  ) -> NativeCheckStatus {
    if !existingArtifacts.isEmpty || outsideSandboxWrite == .positive {
      return .detected
    }
    return outsideSandboxWrite == .inconclusive ? .inconclusive : .notDetected
  }

  static func sandboxWrite(error: Error?) -> IOSProbeResult {
    guard let error else { return .positive }

    let nsError = error as NSError
    let permissionDenied =
      (nsError.domain == NSCocoaErrorDomain
        && nsError.code == CocoaError.fileWriteNoPermission.rawValue)
      || (nsError.domain == NSPOSIXErrorDomain
        && [Int(EACCES), Int(EPERM)].contains(nsError.code))
    return permissionDenied ? .negative : .inconclusive
  }
}
