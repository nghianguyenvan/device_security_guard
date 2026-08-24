# iOS Detector And Pub Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve the package's detector-only scope while making iOS probe failures inconclusive, strengthening tests, and preparing version 0.1.1 for pub.dev.

**Architecture:** Keep the existing Flutter MethodChannel and native detector/classifier split. Model the iOS outside-sandbox write as a three-state probe, feed it into the existing jailbreak classifier, and leave enforcement to the host application. Treat README, version metadata, changelog, and release gates as one publication deliverable.

**Tech Stack:** Flutter 3.44, Dart 3.12, Swift 5, XCTest, CocoaPods, Gradle.

**Spec:** `README.md` (public package contract) plus the global constraints below.

## Global Constraints

- The package detects and reports; it does not close the app or show notifications.
- Signing certificate and App ID Prefix configuration remain optional.
- Missing data and unexpected detector errors return `inconclusive`, never `detected` or a false clean result.
- No new runtime dependency, permission, network service, or public API is added.
- README content must be professional, complete for integration, concise, and free of repeated guidance.
- Prepare version `0.1.1`; do not run the irreversible `dart pub publish` command.

---

### Task 1: Preserve uncertainty in the iOS jailbreak write probe

**Files:**
- Modify: `ios/device_security_guard/Sources/device_security_guard/IOSSignalClassifier.swift`
- Modify: `ios/device_security_guard/Sources/device_security_guard/IOSSecurityDetector.swift`
- Test: `example/ios/RunnerTests/RunnerTests.swift`

**Interfaces:**
- Consumes: the existing jailbreak artifact set and outside-sandbox write attempt.
- Produces: `IOSProbeResult` and `IOSSignalClassifier.jailbreak(existingArtifacts:outsideSandboxWrite:)`.

- [ ] **Step 1: Write failing XCTest cases**

Add cases proving an unexpected write error maps to `.inconclusive`, permission denial maps to `.notDetected`, and a successful write maps to `.detected`.

- [ ] **Step 2: Run the focused XCTest target and verify RED**

Run: `xcodebuild test -workspace example/ios/Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.4' -only-testing:RunnerTests`

Expected: compilation/test failure because the three-state probe API does not exist yet.

- [ ] **Step 3: Implement the minimal three-state probe**

Add `IOSProbeResult`, classify sandbox permission errors separately from unexpected errors, and make jailbreak classification preserve `.inconclusive` unless an artifact or successful outside-sandbox write proves detection.

- [ ] **Step 4: Run the focused XCTest target and verify GREEN**

Expected: all `RunnerTests` pass.

### Task 2: Complete the iOS detector contract tests

**Files:**
- Modify: `example/ios/RunnerTests/RunnerTests.swift`
- Modify: `example/integration_test/plugin_integration_test.dart`

**Interfaces:**
- Consumes: the existing five iOS signal keys and native reason/status payload.
- Produces: regression coverage for hook, identity, jailbreak, optional configuration, and simulator results.

- [ ] **Step 1: Add focused classifier and detector tests**

Cover clean and injected hook inputs, prefix match/mismatch/unavailable/unconfigured behavior, exact signal keys, jailbreak artifact/write outcomes, and the guarantee that an unconfigured prefix does not invoke the Keychain reader.

- [ ] **Step 2: Strengthen the Flutter integration assertion**

On iOS Simulator, assert `emulator=detected`, `repackaging=inconclusive`, and `jailbreak=inconclusive` in addition to the exact signal set.

- [ ] **Step 3: Run XCTest and Flutter integration tests**

Expected: native tests and the end-to-end MethodChannel test pass on iOS Simulator.

### Task 3: Prepare the pub.dev package page and release metadata

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `pubspec.yaml`
- Modify: `ios/device_security_guard.podspec`
- Modify: `doc/publishing-vi.md` only if release instructions contain stale version-specific guidance.

**Interfaces:**
- Consumes: the public Dart API and verified platform behavior.
- Produces: concise integration documentation and consistent `0.1.1` release metadata.

- [ ] **Step 1: Rewrite README around user decisions**

Keep only scope, supported signals/platforms, installation, minimal usage, optional signing identity configuration, status semantics, limitations, and project links.

- [ ] **Step 2: Align release metadata**

Set `pubspec.yaml` and podspec to `0.1.1`, replace `Unreleased` with a dated `0.1.1` changelog entry, and remove stale first-release instructions.

### Task 4: Run publication gates and stop before publishing

**Files:**
- Verify only; no product changes unless a gate exposes an in-scope defect.

**Interfaces:**
- Consumes: the complete release candidate.
- Produces: a verified dry-run archive and a short list of any external/manual publication steps.

- [ ] **Step 1: Run formatting, analysis, Dart tests, and documentation generation**

- [ ] **Step 2: Run Android unit/lint/release gates**

- [ ] **Step 3: Run iOS XCTest, integration, simulator build, and pod lint gates**

- [ ] **Step 4: Run `dart pub publish --dry-run` and inspect the archive**

- [ ] **Step 5: Confirm `git diff --check`, version consistency, and final working-tree scope**

- [ ] **Step 6: Stop without publishing, tagging, committing, or pushing**
