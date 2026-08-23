import Foundation

@main
enum IOSSignalClassifierTestMain {
  static func main() {
    expect(
      IOSSignalClassifier.hooking(
        loadedImages: ["/usr/lib/FridaGadget.dylib"],
        environment: [:]
      ) == .detected,
      "Frida image must be detected"
    )
    expect(
      IOSSignalClassifier.repackaging(
        actualTeamIdentifier: "TEAM123",
        expectedTeamIdentifiers: ["TEAM123"]
      ) == .notDetected,
      "Matching Team ID must not be marked as repackaged"
    )
    expect(
      IOSSignalClassifier.repackaging(
        actualTeamIdentifier: nil,
        expectedTeamIdentifiers: ["TEAM123"]
      ) == .inconclusive,
      "Unavailable Team ID must be inconclusive"
    )
    expect(
      IOSSignalClassifier.jailbreak(
        existingArtifacts: ["/Applications/Cydia.app"],
        canWriteOutsideSandbox: false
      ) == .detected,
      "A jailbreak artifact must be detected"
    )
  }

  private static func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String
  ) {
    guard condition() else {
      FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
      exit(1)
    }
  }
}
