import Darwin
import Foundation
import MachO

internal final class IOSSecurityDetector {
  func assess(
    expectedTeamIdentifiers: Set<String>
  ) -> [String: [String: String]] {
    return [
      "debugger": safely { try self.debugger() },
      "emulator": safely { try self.emulator() },
      "hooking": safely { try self.hooking() },
      "repackaging": safely {
        try self.repackaging(expectedTeamIdentifiers: expectedTeamIdentifiers)
      },
      "jailbreak": safely { try self.jailbreak() },
    ]
  }

  private func debugger() throws -> IOSSignalResult {
    var processInfo = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    guard sysctl(&name, u_int(name.count), &processInfo, &size, nil, 0) == 0 else {
      throw IOSDetectorError.systemQueryFailed
    }
    let traced = (processInfo.kp_proc.p_flag & P_TRACED) != 0
    return traced
      ? IOSSignalResult(.detected, "debugger_attached")
      : IOSSignalResult(.notDetected, "debugger_not_detected")
  }

  private func emulator() throws -> IOSSignalResult {
    #if targetEnvironment(simulator)
      return IOSSignalResult(.detected, "simulator_detected")
    #else
      return IOSSignalResult(.notDetected, "simulator_not_detected")
    #endif
  }

  private func hooking() throws -> IOSSignalResult {
    var loadedImages: [String] = []
    for index in 0..<_dyld_image_count() {
      if let image = _dyld_get_image_name(index) {
        loadedImages.append(String(cString: image))
      }
    }
    let value = IOSSignalClassifier.hooking(
      loadedImages: loadedImages,
      environment: ProcessInfo.processInfo.environment
    )
    return value.result(
      detected: "hook_framework_detected",
      notDetected: "hook_framework_not_detected"
    )
  }

  private func repackaging(
    expectedTeamIdentifiers: Set<String>
  ) throws -> IOSSignalResult {
    let value = IOSSignalClassifier.repackaging(
      actualTeamIdentifier: actualTeamIdentifier(),
      expectedTeamIdentifiers: expectedTeamIdentifiers
    )
    return value.result(
      detected: "team_identifier_mismatch",
      notDetected: "team_identifier_match",
      inconclusive: expectedTeamIdentifiers.isEmpty
        ? "team_identifier_unconfigured"
        : "team_identifier_unavailable"
    )
  }

  private func jailbreak() throws -> IOSSignalResult {
    #if targetEnvironment(simulator)
      return IOSSignalResult(.inconclusive, "jailbreak_check_on_simulator")
    #else
      let artifactPaths = [
        "/Applications/Cydia.app",
        "/Applications/Sileo.app",
        "/Applications/Zebra.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/usr/bin/ssh",
        "/usr/sbin/sshd",
        "/var/lib/apt",
        "/var/jb",
      ]
      let existing = Set(artifactPaths.filter(FileManager.default.fileExists))
      let value = IOSSignalClassifier.jailbreak(
        existingArtifacts: existing,
        canWriteOutsideSandbox: canWriteOutsideSandbox()
      )
      return value.result(
        detected: "jailbreak_indicator_detected",
        notDetected: "jailbreak_indicator_not_detected"
      )
    #endif
  }

  private func actualTeamIdentifier() -> String? {
    if let prefix = Bundle.main.object(
      forInfoDictionaryKey: "AppIdentifierPrefix"
    ) as? String {
      return prefix.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
          let data = try? Data(contentsOf: url),
          let text = String(data: data, encoding: .isoLatin1),
          let start = text.range(of: "<?xml"),
          let end = text.range(of: "</plist>"),
          start.lowerBound < end.upperBound else {
      return nil
    }
    let plistText = String(text[start.lowerBound..<end.upperBound])
    guard let plistData = plistText.data(using: .isoLatin1),
          let plist = try? PropertyListSerialization.propertyList(
            from: plistData,
            options: [],
            format: nil
          ) as? [String: Any],
          let entitlements = plist["Entitlements"] as? [String: Any] else {
      return nil
    }
    return entitlements["com.apple.developer.team-identifier"] as? String
  }

  private func canWriteOutsideSandbox() -> Bool {
    let url = URL(fileURLWithPath: "/private/device_security_guard_\(UUID().uuidString)")
    do {
      try Data([0]).write(to: url)
      try? FileManager.default.removeItem(at: url)
      return true
    } catch {
      return false
    }
  }

  private func safely(
    _ detector: () throws -> IOSSignalResult
  ) -> [String: String] {
    do {
      return try detector().dictionary
    } catch {
      return IOSSignalResult(.inconclusive, "detector_error").dictionary
    }
  }
}

private enum IOSDetectorError: Error {
  case systemQueryFailed
}

private struct IOSSignalResult {
  let status: NativeCheckStatus
  let reasonCode: String

  init(_ status: NativeCheckStatus, _ reasonCode: String) {
    self.status = status
    self.reasonCode = reasonCode
  }

  var dictionary: [String: String] {
    return ["status": status.rawValue, "reasonCode": reasonCode]
  }
}

private extension NativeCheckStatus {
  func result(
    detected: String,
    notDetected: String,
    inconclusive: String = "detector_inconclusive"
  ) -> IOSSignalResult {
    switch self {
    case .detected:
      return IOSSignalResult(self, detected)
    case .notDetected:
      return IOSSignalResult(self, notDetected)
    case .inconclusive:
      return IOSSignalResult(self, inconclusive)
    }
  }
}
