import Flutter
import UIKit
import XCTest

@testable import device_security_guard

class RunnerTests: XCTestCase {
  func testAssessmentReturnsVersionedPayload() {
    let plugin = DeviceSecurityGuardPlugin()
    let call = FlutterMethodCall(
      methodName: "assess",
      arguments: [
        "expectedAndroidCertificateSha256": [],
        "expectedIosTeamIdentifiers": [],
      ]
    )

    let resultExpectation = expectation(description: "result block must be called")
    plugin.handle(call) { result in
      guard let payload = result as? [String: Any] else {
        XCTFail("Assessment payload has the wrong type")
        resultExpectation.fulfill()
        return
      }
      XCTAssertEqual(payload["schemaVersion"] as? Int, 1)
      XCTAssertEqual(payload["platform"] as? String, "ios")
      XCTAssertNotNil(payload["signals"] as? [String: Any])
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }
}
