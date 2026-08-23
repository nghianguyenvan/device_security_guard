import Flutter
import UIKit

public class DeviceSecurityGuardPlugin: NSObject, FlutterPlugin {
  private let detector = IOSSecurityDetector()
  private let appAttestClient = AppAttestClient()

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
    case "isAppAttestSupported":
      result(appAttestClient.isSupported)
    case "generateAppAttestKey":
      appAttestClient.generateKey(result: result)
    case "attestAppAttestKey":
      guard let values = appAttestArguments(call) else {
        result(invalidArgumentsError())
        return
      }
      appAttestClient.attestKey(
        keyId: values.keyId,
        clientDataHash: values.clientDataHash,
        result: result
      )
    case "generateAppAttestAssertion":
      guard let values = appAttestArguments(call) else {
        result(invalidArgumentsError())
        return
      }
      appAttestClient.generateAssertion(
        keyId: values.keyId,
        clientDataHash: values.clientDataHash,
        result: result
      )
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func appAttestArguments(
    _ call: FlutterMethodCall
  ) -> (keyId: String, clientDataHash: Data)? {
    guard let arguments = call.arguments as? [String: Any],
          let keyId = arguments["keyId"] as? String,
          !keyId.isEmpty,
          let typedData = arguments["clientDataHash"] as? FlutterStandardTypedData,
          !typedData.data.isEmpty else {
      return nil
    }
    return (keyId, typedData.data)
  }

  private func invalidArgumentsError() -> FlutterError {
    return FlutterError(
      code: "invalid_arguments",
      message: "App Attest key identifier and client data hash are required",
      details: nil
    )
  }
}
