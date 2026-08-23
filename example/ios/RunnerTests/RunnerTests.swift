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

  func testFridaImageIsClassifiedAsHooking() {
    XCTAssertEqual(
      IOSSignalClassifier.hooking(
        loadedImages: ["/usr/lib/FridaGadget.dylib"],
        environment: [:]
      ),
      .detected
    )
  }

  func testMatchingTeamIdentifierIsNotRepackaged() {
    XCTAssertEqual(
      IOSSignalClassifier.repackaging(
        actualTeamIdentifier: "TEAM123456",
        expectedTeamIdentifiers: ["TEAM123456"]
      ),
      .notDetected
    )
  }

  func testMissingTeamIdentifierIsInconclusive() {
    XCTAssertEqual(
      IOSSignalClassifier.repackaging(
        actualTeamIdentifier: nil,
        expectedTeamIdentifiers: ["TEAM123456"]
      ),
      .inconclusive
    )
  }

  func testDetectorUsesRuntimeTeamIdentifierReader() {
    let match = IOSSecurityDetector(teamIdentifierReader: { "TEAM123456" })
      .assess(expectedTeamIdentifiers: ["TEAM123456"])["repackaging"]
    let mismatch = IOSSecurityDetector(teamIdentifierReader: { "OTHER12345" })
      .assess(expectedTeamIdentifiers: ["TEAM123456"])["repackaging"]
    let unavailable = IOSSecurityDetector(teamIdentifierReader: { nil })
      .assess(expectedTeamIdentifiers: ["TEAM123456"])["repackaging"]

    XCTAssertEqual(match?["status"], "notDetected")
    XCTAssertEqual(mismatch?["status"], "detected")
    XCTAssertEqual(unavailable?["status"], "inconclusive")
  }

  func testJailbreakArtifactIsDetected() {
    XCTAssertEqual(
      IOSSignalClassifier.jailbreak(
        existingArtifacts: ["/Applications/Cydia.app"],
        canWriteOutsideSandbox: false
      ),
      .detected
    )
  }
}
