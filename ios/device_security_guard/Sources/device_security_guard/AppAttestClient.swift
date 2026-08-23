import DeviceCheck
import Flutter
import Foundation

internal final class AppAttestClient {
  private let service = DCAppAttestService.shared

  var isSupported: Bool {
    return service.isSupported
  }

  func generateKey(result: @escaping FlutterResult) {
    guard service.isSupported else {
      result(error(code: "app_attest_unsupported", message: "App Attest is unavailable"))
      return
    }
    service.generateKey { keyId, serviceError in
      self.complete(value: keyId, error: serviceError, result: result)
    }
  }

  func attestKey(
    keyId: String,
    clientDataHash: Data,
    result: @escaping FlutterResult
  ) {
    guard service.isSupported else {
      result(error(code: "app_attest_unsupported", message: "App Attest is unavailable"))
      return
    }
    service.attestKey(keyId, clientDataHash: clientDataHash) { data, serviceError in
      self.complete(
        value: data.map(FlutterStandardTypedData.init(bytes:)),
        error: serviceError,
        result: result
      )
    }
  }

  func generateAssertion(
    keyId: String,
    clientDataHash: Data,
    result: @escaping FlutterResult
  ) {
    guard service.isSupported else {
      result(error(code: "app_attest_unsupported", message: "App Attest is unavailable"))
      return
    }
    service.generateAssertion(keyId, clientDataHash: clientDataHash) { data, serviceError in
      self.complete(
        value: data.map(FlutterStandardTypedData.init(bytes:)),
        error: serviceError,
        result: result
      )
    }
  }

  private func complete(
    value: Any?,
    error serviceError: Error?,
    result: @escaping FlutterResult
  ) {
    DispatchQueue.main.async {
      if let serviceError {
        result(
          self.error(
            code: "app_attest_error",
            message: serviceError.localizedDescription
          )
        )
      } else if let value {
        result(value)
      } else {
        result(self.error(code: "app_attest_error", message: "App Attest returned no data"))
      }
    }
  }

  private func error(code: String, message: String) -> FlutterError {
    return FlutterError(code: code, message: message, details: nil)
  }
}
