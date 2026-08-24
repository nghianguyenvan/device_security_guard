import Darwin
import Foundation
import MachO
import Security

internal final class IOSSecurityDetector {
  private let applicationIdentifierPrefixReader: () -> String?

  init(
    applicationIdentifierPrefixReader: @escaping () -> String? =
      IOSSecurityDetector.readApplicationIdentifierPrefix
  ) {
    self.applicationIdentifierPrefixReader = applicationIdentifierPrefixReader
  }

  func assess(
    expectedApplicationIdentifierPrefixes: Set<String>
  ) -> [String: [String: String]] {
    return [
      "debugger": safely { try self.debugger() },
      "emulator": safely { try self.emulator() },
      "hooking": safely { try self.hooking() },
      "repackaging": safely {
        try self.repackaging(
          expectedApplicationIdentifierPrefixes: expectedApplicationIdentifierPrefixes
        )
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
    expectedApplicationIdentifierPrefixes: Set<String>
  ) throws -> IOSSignalResult {
    guard !expectedApplicationIdentifierPrefixes.isEmpty else {
      return IOSSignalResult(.inconclusive, "application_identifier_prefix_unconfigured")
    }
    let value = IOSSignalClassifier.repackaging(
      actualApplicationIdentifierPrefix: applicationIdentifierPrefixReader(),
      expectedApplicationIdentifierPrefixes: expectedApplicationIdentifierPrefixes
    )
    return value.result(
      detected: "application_identifier_prefix_mismatch",
      notDetected: "application_identifier_prefix_match",
      inconclusive: "application_identifier_prefix_unavailable"
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
        outsideSandboxWrite: outsideSandboxWrite()
      )
      return value.result(
        detected: "jailbreak_indicator_detected",
        notDetected: "jailbreak_indicator_not_detected"
      )
    #endif
  }

  private static func readApplicationIdentifierPrefix() -> String? {
    let account = UUID().uuidString
    let service = "dev.vannghia.device_security_guard.app_id_prefix"
    let deleteQuery: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrAccount: account,
      kSecAttrService: service,
    ]
    let addQuery: [CFString: Any] = deleteQuery.merging([
      kSecValueData: Data([0]),
      kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      kSecReturnAttributes: true,
    ]) { _, new in new }
    var item: CFTypeRef?
    guard SecItemAdd(addQuery as CFDictionary, &item) == errSecSuccess else {
      return nil
    }
    defer { SecItemDelete(deleteQuery as CFDictionary) }
    guard let attributes = item as? [CFString: Any],
      let accessGroup = attributes[kSecAttrAccessGroup] as? String,
      let applicationIdentifierPrefix = accessGroup.split(separator: ".").first
    else {
      return nil
    }
    return String(applicationIdentifierPrefix)
  }

  private func outsideSandboxWrite() -> IOSProbeResult {
    let url = URL(fileURLWithPath: "/private/device_security_guard_\(UUID().uuidString)")
    do {
      try Data([0]).write(to: url)
      try? FileManager.default.removeItem(at: url)
      return .positive
    } catch {
      return IOSSignalClassifier.sandboxWrite(error: error)
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

extension NativeCheckStatus {
  fileprivate func result(
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
