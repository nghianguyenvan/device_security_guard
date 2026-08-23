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
        "expectedIosApplicationIdentifierPrefixes": [],
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

  func testMatchingApplicationIdentifierPrefixIsNotRepackaged() {
    XCTAssertEqual(
      IOSSignalClassifier.repackaging(
        actualApplicationIdentifierPrefix: "OLDPREFIX1",
        expectedApplicationIdentifierPrefixes: ["OLDPREFIX1"]
      ),
      .notDetected
    )
  }

  func testMissingApplicationIdentifierPrefixIsInconclusive() {
    XCTAssertEqual(
      IOSSignalClassifier.repackaging(
        actualApplicationIdentifierPrefix: nil,
        expectedApplicationIdentifierPrefixes: ["OLDPREFIX1"]
      ),
      .inconclusive
    )
  }

  func testDetectorUsesRuntimeApplicationIdentifierPrefixReader() {
    let match = IOSSecurityDetector(applicationIdentifierPrefixReader: { "OLDPREFIX1" })
      .assess(expectedApplicationIdentifierPrefixes: ["OLDPREFIX1"])["repackaging"]
    let mismatch = IOSSecurityDetector(applicationIdentifierPrefixReader: { "NEWPREFIX2" })
      .assess(expectedApplicationIdentifierPrefixes: ["OLDPREFIX1"])["repackaging"]
    let unavailable = IOSSecurityDetector(applicationIdentifierPrefixReader: { nil })
      .assess(expectedApplicationIdentifierPrefixes: ["OLDPREFIX1"])["repackaging"]

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
