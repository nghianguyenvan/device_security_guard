import Flutter
import UIKit

public class DeviceSecurityGuardPlugin: NSObject, FlutterPlugin {
  private let detector = IOSSecurityDetector()

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
      let expectedTeamIdentifiers = Set(
        arguments?["expectedIosTeamIdentifiers"] as? [String] ?? []
      )
      result([
        "schemaVersion": 1,
        "platform": "ios",
        "operatingSystemVersion": UIDevice.current.systemVersion,
        "assessedAtEpochMs": Int64(Date().timeIntervalSince1970 * 1000),
        "signals": detector.assess(
          expectedTeamIdentifiers: expectedTeamIdentifiers
        ),
      ])
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
