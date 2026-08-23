# Device Security Guard Design

## Purpose

`device_security_guard` is a Flutter plugin for Android and iOS that detects mobile runtime and device security risks relevant to Circular 77/2025/TT-NHNN. The plugin returns structured evidence and a policy recommendation. It never terminates the host application or claims that the host application is legally compliant.

Version 1 covers the signs listed by the amended Clause 4 of Article 8 of Circular 50/2024/TT-NHNN:

- attached or active debuggers;
- emulators, simulators, and virtual devices;
- Android Debug Bridge (ADB);
- runtime hooking or external code injection;
- application tampering or repackaging;
- rooted or jailbroken devices; and
- an unlocked Android bootloader.

Google Play Integrity and Apple App Attest are optional sources of stronger, server-verified evidence. Both are disabled by default.

## Supported Platforms

### Android

- Minimum SDK: API 23.
- Compile SDK: API 36.
- The example application targets API 36.
- The host application remains responsible for selecting a Google Play-compliant target SDK.
- Native implementation language: Kotlin.

### iOS

- Deployment target: iOS 15.0.
- Builds and CI use Xcode 26 or later with the iOS 26 SDK where available.
- Native implementation language: Swift.

The first release supports Android and iOS only.

## Architecture

The package uses a layered architecture:

1. Native detectors collect small, independent platform signals.
2. A platform-channel boundary converts native payloads into stable Dart models.
3. A Dart assessment service runs checks and optionally invokes attestation.
4. `Circular77Policy` converts the assessment into a recommended action.

The public package is a single Flutter plugin in version 1. It is not split into federated packages. Detector implementations remain isolated internally so a future split does not require changing the public Dart API.

## Public API

The primary entry point is asynchronous:

```dart
final assessment = await DeviceSecurityGuard.assess(
  options: const SecurityOptions(
    enablePlayIntegrity: false,
    enableAppAttest: false,
  ),
);

final decision = Circular77Policy.evaluate(assessment);
```

`SecurityOptions` includes:

- `enablePlayIntegrity`, defaulting to `false`;
- `enableAppAttest`, defaulting to `false`;
- expected Android signing-certificate SHA-256 digests;
- expected iOS Team identifiers;
- an optional `AttestationAdapter`; and
- policy-independent detector options that can only reduce optional checks, not silently turn a failed check into a safe result.

Enabling an attestation provider without its required adapter or configuration produces a configuration error in the attestation result. It never produces a trusted verdict.

## Security Model

### Signals

```dart
enum SecuritySignal {
  debugger,
  emulator,
  adbEnabled,
  hooking,
  repackaging,
  root,
  jailbreak,
  bootloaderUnlocked,
}
```

Play Integrity and App Attest are not security signals. They are attestation providers and are represented separately.

### Signal status

```dart
enum CheckStatus {
  detected,
  notDetected,
  unknown,
  unsupported,
  notApplicable,
  error,
}
```

- `detected`: evidence indicates the risk is present.
- `notDetected`: the check completed without detecting the risk.
- `unknown`: there was not enough evidence to decide.
- `unsupported`: the signal applies to this platform, but this OS/device cannot perform the check.
- `notApplicable`: the signal does not apply to the platform, such as ADB on iOS or jailbreak on Android.
- `error`: the detector failed unexpectedly.

`notApplicable` is neutral during policy evaluation. `unknown`, `unsupported`, and `error` must never be treated as evidence of safety.

### Assessment

`SecurityAssessment` contains:

- platform and operating-system metadata;
- assessment timestamp;
- one `SignalResult` for every `SecuritySignal`;
- zero or more `AttestationAssessment` values; and
- sanitized diagnostic reason codes.

Evidence returned to Dart uses stable reason codes. It does not expose unnecessary filesystem paths, tokens, secrets, raw certificates, or other data that would aid bypass attempts or leak user information.

### Attestation

Attestation status is separate from local signal status:

```dart
enum AttestationStatus {
  trusted,
  untrusted,
  unknown,
  disabled,
  unsupported,
  error,
}
```

An `AttestationAssessment` identifies the provider and contains the normalized status and reason codes. A trusted result is accepted only after the host backend has verified the provider artifact, request binding, freshness, expected application identity, and required verdict fields.

The package provides client-side primitives for requesting a Play Integrity token and for the App Attest key, attestation, and assertion lifecycle. The host application's `AttestationAdapter` owns challenge acquisition, backend communication, and conversion of the server response into a normalized attestation result. The package does not contain service-account credentials, Apple server secrets, or a production backend.

No attestation SDK request or network callback occurs unless its provider is explicitly enabled.

## Policy

```dart
enum RecommendedAction {
  allow,
  block,
  indeterminate,
}
```

The default `Circular77Policy` behaves as follows:

- If any applicable Circular 77 signal is `detected`, recommend `block`.
- If enabled attestation returns `untrusted`, recommend `block`.
- If an applicable check is `unknown`, `unsupported`, or `error`, recommend `indeterminate` unless another result already requires `block`.
- If enabled attestation is missing, invalid, `unknown`, `unsupported`, or `error`, recommend `indeterminate` unless another result already requires `block`.
- If all applicable local checks are `notDetected`, all non-applicable checks are `notApplicable`, and every enabled attestation provider is `trusted`, recommend `allow`.

An optional `failClosed` policy setting converts `indeterminate` into a `block` recommendation. It does not alter the underlying assessment.

The host application decides whether and how to stop Mobile Banking functionality, terminate a process, show a reason to the customer, log telemetry, or offer remediation. These side effects are deliberately outside the plugin.

## Platform Detection

### Android

Independent Kotlin detectors cover:

- debugger attachment and debugger-wait state;
- emulator and virtual-device indicators from multiple system properties;
- ADB-enabled state;
- common runtime hook and injection indicators;
- application certificate mismatch against configured SHA-256 digests;
- common root artifacts and compromised-system indicators; and
- verified-boot and bootloader state when available.

Jailbreak is returned as `notApplicable` on Android.

### iOS

Independent Swift detectors cover:

- debugger attachment;
- simulator environment;
- suspicious loaded images and common runtime hook indicators;
- application identity mismatch against configured Team identifiers; and
- jailbreak artifacts, sandbox-boundary violations, and related indicators.

ADB, Android root, and Android bootloader signals are returned as `notApplicable` on iOS.

Each local root, jailbreak, hook, emulator, and tamper detector is defense in depth and best-effort. Client-side checks can be bypassed after sufficient application or operating-system compromise. Documentation must state this limitation and recommend server-verified attestation for higher assurance.

## Data Flow

For a local-only assessment:

1. Dart validates options.
2. Dart requests a native assessment through the platform channel.
3. Native code runs isolated detectors and returns a versioned payload.
4. Dart validates and normalizes the payload.
5. Dart produces `SecurityAssessment`.
6. The host app optionally evaluates `Circular77Policy`.

For enabled attestation:

1. The host adapter requests a single-use challenge from its backend.
2. The package's provider client binds the request to the challenge or request hash and obtains the platform artifact.
3. The adapter sends the artifact to the host backend.
4. The backend verifies it with Google or according to Apple's App Attest validation procedure, checks replay protection and expected app identity, and returns a normalized verdict.
5. The adapter supplies that verdict to the assessment service.
6. Policy evaluation combines local signals and attestation without rewriting either source.

## Error Handling

- Invalid Dart configuration fails fast with a typed configuration exception before native work begins.
- Each native detector catches its own expected failures and returns `unknown`, `unsupported`, or `error` with a stable reason code.
- One detector failure does not discard successful results from other detectors.
- Malformed or version-incompatible platform-channel payloads become typed protocol errors rather than safe results.
- Attestation timeouts, throttling, network failures, invalid backend responses, and unavailable provider services never become `trusted`.
- Raw provider tokens and assertions are not logged.

## Testing

Testing is organized by layer:

- Dart unit tests cover model serialization, exhaustive policy truth tables, option validation, adapter behavior, malformed payloads, and disabled-by-default attestation.
- Kotlin unit tests cover detector heuristics behind injectable environment wrappers.
- Swift unit tests cover detector heuristics behind injectable environment wrappers.
- Flutter platform-interface tests verify channel names, methods, payload schema, and error normalization.
- Example-app tests demonstrate local-only usage, opt-in attestation wiring, and host-side enforcement without actually terminating the test process.
- Static analysis, formatting, package validation, Android compilation, and iOS compilation run before release.

Tests do not claim that simulators can prove physical root or jailbreak coverage. A release checklist includes controlled validation on representative rooted, jailbroken, unlocked, hooked, repackaged, and clean physical devices.

## Package and Publication

The repository includes:

- public Dart API documentation;
- an example Flutter application;
- `README.md`, `CHANGELOG.md`, `LICENSE`, and `SECURITY.md`;
- a Circular 77 coverage matrix;
- integration guidance for Play Integrity and App Attest;
- privacy and threat-model notes; and
- pub.dev metadata and screenshots only where they materially aid integration.

The README states that the package assists with technical controls but does not itself certify legal or regulatory compliance. Consumers must obtain their own legal, security, penetration-testing, and operational review.

## Out of Scope for Version 1

- A production attestation backend.
- Automatic process termination or UI dialogs.
- Remote policy management or telemetry collection.
- Commercial RASP/anti-tamper integrations.
- Web, desktop, Wear OS, Android TV, Android Automotive, and Android XR support.
- A guarantee that a compromised client cannot bypass all local checks.
