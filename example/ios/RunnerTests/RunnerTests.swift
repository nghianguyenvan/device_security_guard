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

  func testDetectorReturnsEveryIOSSignal() {
    let signals = IOSSecurityDetector()
      .assess(expectedApplicationIdentifierPrefixes: [])

    XCTAssertEqual(
      Set(signals.keys),
      Set(["debugger", "emulator", "hooking", "repackaging", "jailbreak"])
    )
    XCTAssertEqual(signals["emulator"]?["status"], "detected")
    XCTAssertEqual(signals["repackaging"]?["status"], "inconclusive")
    XCTAssertEqual(signals["jailbreak"]?["status"], "inconclusive")
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

  func testCleanRuntimeIsNotClassifiedAsHooking() {
    XCTAssertEqual(
      IOSSignalClassifier.hooking(
        loadedImages: ["/System/Library/Frameworks/UIKit.framework/UIKit"],
        environment: [:]
      ),
      .notDetected
    )
  }

  func testInjectedLibraryEnvironmentIsClassifiedAsHooking() {
    XCTAssertEqual(
      IOSSignalClassifier.hooking(
        loadedImages: [],
        environment: ["DYLD_INSERT_LIBRARIES": "/tmp/ElleKit.dylib"]
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

  func testMismatchedApplicationIdentifierPrefixIsRepackaged() {
    XCTAssertEqual(
      IOSSignalClassifier.repackaging(
        actualApplicationIdentifierPrefix: "NEWPREFIX2",
        expectedApplicationIdentifierPrefixes: ["OLDPREFIX1"]
      ),
      .detected
    )
  }

  func testUnconfiguredApplicationIdentifierPrefixSkipsRuntimeReader() {
    var readerWasCalled = false
    let signal = IOSSecurityDetector(applicationIdentifierPrefixReader: {
      readerWasCalled = true
      return "OLDPREFIX1"
    })
    .assess(expectedApplicationIdentifierPrefixes: [])["repackaging"]

    XCTAssertFalse(readerWasCalled)
    XCTAssertEqual(signal?["status"], "inconclusive")
    XCTAssertEqual(signal?["reasonCode"], "application_identifier_prefix_unconfigured")
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
        outsideSandboxWrite: .negative
      ),
      .detected
    )
  }

  func testIntactSandboxIsNotClassifiedAsJailbroken() {
    XCTAssertEqual(
      IOSSignalClassifier.jailbreak(
        existingArtifacts: [],
        outsideSandboxWrite: .negative
      ),
      .notDetected
    )
  }

  func testOutsideSandboxWriteIsClassifiedAsJailbroken() {
    XCTAssertEqual(
      IOSSignalClassifier.jailbreak(
        existingArtifacts: [],
        outsideSandboxWrite: .positive
      ),
      .detected
    )
  }

  func testSuccessfulOutsideSandboxWriteIsPositive() {
    XCTAssertEqual(
      IOSSignalClassifier.sandboxWrite(error: nil),
      .positive
    )
  }

  func testSandboxPermissionDeniedIsNegative() {
    let error = NSError(
      domain: NSCocoaErrorDomain,
      code: CocoaError.fileWriteNoPermission.rawValue
    )

    XCTAssertEqual(
      IOSSignalClassifier.sandboxWrite(error: error),
      .negative
    )
  }

  func testPOSIXPermissionDeniedIsNegative() {
    let error = NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))

    XCTAssertEqual(
      IOSSignalClassifier.sandboxWrite(error: error),
      .negative
    )
  }

  func testUnexpectedSandboxWriteErrorIsInconclusive() {
    let error = NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteOutOfSpace.rawValue)

    XCTAssertEqual(
      IOSSignalClassifier.sandboxWrite(error: error),
      .inconclusive
    )
    XCTAssertEqual(
      IOSSignalClassifier.jailbreak(
        existingArtifacts: [],
        outsideSandboxWrite: .inconclusive
      ),
      .inconclusive
    )
  }
}
