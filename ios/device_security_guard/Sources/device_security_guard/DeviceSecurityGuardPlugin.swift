import Flutter
import UIKit

public class DeviceSecurityGuardPlugin: NSObject, FlutterPlugin {
  private let detector = IOSSecurityDetector()
  private let detectorQueue = DispatchQueue(
    label: "dev.vannghia.device_security_guard.detector",
    qos: .userInitiated
  )

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "dev.vannghia/device_security_guard",
      binaryMessenger: registrar.messenger()
    )
    let instance = DeviceSecurityGuardPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "assess":
      let arguments = call.arguments as? [String: Any]
      let expectedApplicationIdentifierPrefixes = Set(
        arguments?["expectedIosApplicationIdentifierPrefixes"] as? [String] ?? []
      )
      let operatingSystemVersion = UIDevice.current.systemVersion
      let assessedAtEpochMs = Int64(Date().timeIntervalSince1970 * 1000)
      detectorQueue.async {
        let payload: [String: Any] = [
          "schemaVersion": 1,
          "platform": "ios",
          "operatingSystemVersion": operatingSystemVersion,
          "assessedAtEpochMs": assessedAtEpochMs,
          "signals": self.detector.assess(
            expectedApplicationIdentifierPrefixes: expectedApplicationIdentifierPrefixes
          ),
        ]
        DispatchQueue.main.async { result(payload) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
