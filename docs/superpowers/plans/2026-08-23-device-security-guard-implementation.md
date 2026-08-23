# Kế hoạch triển khai Device Security Guard

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng Flutter plugin `device_security_guard` cho Android và iOS, trả kết quả phát hiện các dấu hiệu theo Thông tư 77 cùng policy helper, với Play Integrity và App Attest mặc định tắt.

**Architecture:** Kotlin và Swift thu thập từng tín hiệu native rồi trả payload có version qua một `MethodChannel`. Dart chuẩn hóa payload thành model ba trạng thái, gọi attestation adapter khi được bật, và đánh giá `Circular77Policy` mà không tự đóng ứng dụng.

**Tech Stack:** Flutter 3.44.8, Dart 3.12.2, Kotlin/JDK 17, Android API 23–36, Swift, Xcode 26.5/iOS 26.5 SDK, iOS deployment target 15.0, Google Play Integrity 1.6.0, Apple DeviceCheck/App Attest.

**Spec:** `docs/superpowers/specs/2026-08-23-device-security-guard-design.md`

## Global Constraints

- Package công khai là một Flutter plugin duy nhất tên `device_security_guard`.
- Android dùng `minSdk = 23`, `compileSdk = 36`; example app dùng `targetSdk = 36`.
- iOS dùng deployment target 15.0 và build bằng Xcode 26 trở lên với iOS 26 SDK.
- `enablePlayIntegrity` và `enableAppAttest` mặc định là `false`.
- Khi attestation tắt, không gọi SDK attestation và không gọi adapter mạng.
- Plugin không tự đóng ứng dụng, không ghi raw token/assertion và không tuyên bố tuân thủ pháp lý.
- Chỉ dùng ba trạng thái cho local check: `detected`, `notDetected`, `inconclusive`.
- Chỉ dùng ba trạng thái attestation: `trusted`, `untrusted`, `inconclusive`.
- Tín hiệu không áp dụng trên nền tảng không xuất hiện trong kết quả.
- Mọi detector phía client là best-effort; tài liệu phải nói rõ giới hạn này.
- Không thêm dependency thương mại hoặc SDK RASP.

## Cấu trúc file

- `lib/device_security_guard.dart`: public exports và facade `DeviceSecurityGuard`.
- `lib/src/models.dart`: enum và immutable result model.
- `lib/src/circular_77_policy.dart`: policy thuần Dart.
- `lib/src/security_options.dart`: options và validation.
- `lib/src/attestation.dart`: adapter/client contract.
- `lib/src/device_security_guard_platform.dart`: platform interface dùng cho test injection.
- `lib/src/method_channel_device_security_guard.dart`: channel schema, parser và native client calls.
- `android/src/main/kotlin/dev/vannghia/device_security_guard/AndroidSignalClassifier.kt`: hàm phân loại Kotlin thuần.
- `android/src/main/kotlin/dev/vannghia/device_security_guard/AndroidSecurityDetector.kt`: thu thập môi trường Android.
- `android/src/main/kotlin/dev/vannghia/device_security_guard/PlayIntegrityClient.kt`: tạo Standard Integrity token.
- `android/src/main/kotlin/dev/vannghia/device_security_guard/DeviceSecurityGuardPlugin.kt`: đăng ký channel và điều phối method.
- `ios/Classes/IOSSignalClassifier.swift`: hàm phân loại Swift thuần.
- `ios/Classes/IOSSecurityDetector.swift`: thu thập môi trường iOS.
- `ios/Classes/AppAttestClient.swift`: wrapper `DCAppAttestService`.
- `ios/Classes/DeviceSecurityGuardPlugin.swift`: đăng ký channel và điều phối method.
- `test/`: Dart unit và method-channel contract tests.
- `android/src/test/`: Kotlin classifier tests.
- `ios/Tests/`: Swift classifier tests qua CocoaPods test spec.
- `example/`: ứng dụng minh họa local assessment và host-side decision.
- `doc/circular-77-coverage-vi.md`: ma trận bao phủ quy định.
- `README.md`, `CHANGELOG.md`, `LICENSE`, `SECURITY.md`: tài liệu phát hành.

---

### Task 1: Scaffold plugin, model và Circular 77 policy

**Files:**
- Create: `.gitignore`
- Create: `pubspec.yaml`
- Create: `analysis_options.yaml`
- Create: `lib/device_security_guard.dart`
- Create: `lib/src/models.dart`
- Create: `lib/src/circular_77_policy.dart`
- Create: `test/models_test.dart`
- Create: `test/circular_77_policy_test.dart`
- Create: các file template Android, iOS và `example/` do `flutter create` sinh ra

**Interfaces:**
- Produces: `SecuritySignal`, `CheckStatus`, `SignalResult`, `SecurityPlatform`, `AttestationProvider`, `AttestationStatus`, `AttestationAssessment`, `SecurityAssessment`, `RecommendedAction`, `PolicyDecision`, `Circular77Policy.evaluate(SecurityAssessment, {bool failClosed = false})`.

- [ ] **Step 1: Scaffold Flutter plugin trong repository hiện tại**

Run:

```bash
flutter create --template=plugin --platforms=android,ios --org dev.vannghia .
```

Sau khi scaffold, đặt trong `pubspec.yaml`:

```yaml
name: device_security_guard
description: Flutter security signals and policy helpers for rooted, jailbroken, hooked, debugged, emulated, repackaged, and unlocked devices.
version: 0.1.0
environment:
  sdk: ^3.12.0
  flutter: ">=3.44.0"
```

- [ ] **Step 2: Viết test thất bại cho model ba trạng thái và policy**

Create `test/circular_77_policy_test.dart`:

```dart
import 'package:device_security_guard/device_security_guard.dart';
import 'package:flutter_test/flutter_test.dart';

SecurityAssessment assessment({
  required Map<SecuritySignal, SignalResult> signals,
  List<AttestationAssessment> attestations = const [],
}) => SecurityAssessment(
  platform: SecurityPlatform.android,
  operatingSystemVersion: '16',
  assessedAt: DateTime.utc(2026, 8, 23),
  signals: signals,
  attestations: attestations,
);

void main() {
  test('detected signal recommends block', () {
    final result = assessment(signals: {
      SecuritySignal.root: const SignalResult(
        signal: SecuritySignal.root,
        status: CheckStatus.detected,
        reasonCode: 'root_artifact',
      ),
    });

    expect(Circular77Policy.evaluate(result).action, RecommendedAction.block);
  });

  test('inconclusive recommends indeterminate or block when fail-closed', () {
    final result = assessment(signals: {
      SecuritySignal.repackaging: const SignalResult(
        signal: SecuritySignal.repackaging,
        status: CheckStatus.inconclusive,
        reasonCode: 'expected_identity_missing',
      ),
    });

    expect(
      Circular77Policy.evaluate(result).action,
      RecommendedAction.indeterminate,
    );
    expect(
      Circular77Policy.evaluate(result, failClosed: true).action,
      RecommendedAction.block,
    );
  });

  test('all checks clean and enabled attestation trusted recommends allow', () {
    final result = assessment(
      signals: {
        SecuritySignal.root: const SignalResult(
          signal: SecuritySignal.root,
          status: CheckStatus.notDetected,
          reasonCode: 'no_root_indicator',
        ),
      },
      attestations: const [
        AttestationAssessment(
          provider: AttestationProvider.playIntegrity,
          status: AttestationStatus.trusted,
          reasonCode: 'backend_verified',
        ),
      ],
    );

    expect(Circular77Policy.evaluate(result).action, RecommendedAction.allow);
  });
}
```

Create `test/models_test.dart` để kiểm tra immutable collections:

```dart
import 'package:device_security_guard/device_security_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assessment copies signal map', () {
    final source = <SecuritySignal, SignalResult>{};
    final value = SecurityAssessment(
      platform: SecurityPlatform.iOS,
      operatingSystemVersion: '26.5',
      assessedAt: DateTime.utc(2026),
      signals: source,
    );
    source[SecuritySignal.jailbreak] = const SignalResult(
      signal: SecuritySignal.jailbreak,
      status: CheckStatus.detected,
      reasonCode: 'jailbreak_artifact',
    );

    expect(value.signals, isEmpty);
  });
}
```

- [ ] **Step 3: Chạy test để xác nhận thất bại**

Run:

```bash
flutter test test/models_test.dart test/circular_77_policy_test.dart
```

Expected: FAIL vì các public type chưa tồn tại.

- [ ] **Step 4: Implement model và policy tối thiểu**

Create `lib/src/models.dart` với đúng public API:

```dart
import 'dart:collection';

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

enum CheckStatus { detected, notDetected, inconclusive }
enum SecurityPlatform { android, iOS }
enum AttestationProvider { playIntegrity, appAttest }
enum AttestationStatus { trusted, untrusted, inconclusive }
enum RecommendedAction { allow, block, indeterminate }

final class SignalResult {
  const SignalResult({
    required this.signal,
    required this.status,
    required this.reasonCode,
  });
  final SecuritySignal signal;
  final CheckStatus status;
  final String reasonCode;
}

final class AttestationAssessment {
  const AttestationAssessment({
    required this.provider,
    required this.status,
    required this.reasonCode,
  });
  final AttestationProvider provider;
  final AttestationStatus status;
  final String reasonCode;
}

final class SecurityAssessment {
  SecurityAssessment({
    required this.platform,
    required this.operatingSystemVersion,
    required this.assessedAt,
    required Map<SecuritySignal, SignalResult> signals,
    List<AttestationAssessment> attestations = const [],
  }) : signals = UnmodifiableMapView(Map.of(signals)),
       attestations = List.unmodifiable(attestations);
  final SecurityPlatform platform;
  final String operatingSystemVersion;
  final DateTime assessedAt;
  final Map<SecuritySignal, SignalResult> signals;
  final List<AttestationAssessment> attestations;

  SecurityAssessment withAttestations(List<AttestationAssessment> values) =>
      SecurityAssessment(
        platform: platform,
        operatingSystemVersion: operatingSystemVersion,
        assessedAt: assessedAt,
        signals: signals,
        attestations: values,
      );
}

final class PolicyDecision {
  const PolicyDecision({required this.action, required this.reasonCodes});
  final RecommendedAction action;
  final List<String> reasonCodes;
}
```

Create `lib/src/circular_77_policy.dart`:

```dart
import 'models.dart';

abstract final class Circular77Policy {
  static PolicyDecision evaluate(
    SecurityAssessment assessment, {
    bool failClosed = false,
  }) {
    final blocked = assessment.signals.values
            .where((result) => result.status == CheckStatus.detected)
            .map((result) => result.reasonCode)
            .toList() +
        assessment.attestations
            .where((result) => result.status == AttestationStatus.untrusted)
            .map((result) => result.reasonCode)
            .toList();
    if (blocked.isNotEmpty) {
      return PolicyDecision(
        action: RecommendedAction.block,
        reasonCodes: List.unmodifiable(blocked),
      );
    }

    final inconclusive = assessment.signals.values
            .where((result) => result.status == CheckStatus.inconclusive)
            .map((result) => result.reasonCode)
            .toList() +
        assessment.attestations
            .where((result) => result.status == AttestationStatus.inconclusive)
            .map((result) => result.reasonCode)
            .toList();
    if (inconclusive.isNotEmpty) {
      return PolicyDecision(
        action: failClosed
            ? RecommendedAction.block
            : RecommendedAction.indeterminate,
        reasonCodes: List.unmodifiable(inconclusive),
      );
    }

    return const PolicyDecision(
      action: RecommendedAction.allow,
      reasonCodes: [],
    );
  }
}
```

Export model và policy từ `lib/device_security_guard.dart`.

- [ ] **Step 5: Chạy test, format và analyze**

Run:

```bash
dart format lib test
flutter test test/models_test.dart test/circular_77_policy_test.dart
flutter analyze
```

Expected: toàn bộ PASS, analyze không có issue.

- [ ] **Step 6: Commit task**

```bash
git add .gitignore pubspec.yaml analysis_options.yaml lib test android ios example
git commit -m "feat: add security assessment models and policy"
```

---

### Task 2: Options, platform channel parser và attestation adapter contract

**Files:**
- Create: `lib/src/security_options.dart`
- Create: `lib/src/attestation.dart`
- Create: `lib/src/device_security_guard_platform.dart`
- Create: `lib/src/method_channel_device_security_guard.dart`
- Modify: `lib/device_security_guard.dart`
- Create: `test/security_options_test.dart`
- Create: `test/method_channel_device_security_guard_test.dart`
- Create: `test/device_security_guard_test.dart`

**Interfaces:**
- Consumes: model và policy từ Task 1.
- Produces: `SecurityOptions`, `AttestationAdapter.assess`, `AttestationClient`, `DeviceSecurityGuardPlatform`, `MethodChannelDeviceSecurityGuard`, `DeviceSecurityGuard.assess`.

- [ ] **Step 1: Viết test thất bại cho default options và adapter opt-in**

Create `test/device_security_guard_test.dart`:

```dart
import 'package:device_security_guard/device_security_guard.dart';
import 'package:flutter_test/flutter_test.dart';

final class FakePlatform extends DeviceSecurityGuardPlatform {
  var nativeAssessCalls = 0;
  @override
  Future<SecurityAssessment> assessLocal(SecurityOptions options) async {
    nativeAssessCalls++;
    return SecurityAssessment(
      platform: SecurityPlatform.android,
      operatingSystemVersion: '16',
      assessedAt: DateTime.utc(2026),
      signals: {
        for (final signal in DeviceSecurityGuardPlatform.androidSignals)
          signal: SignalResult(
            signal: signal,
            status: CheckStatus.notDetected,
            reasonCode: 'not_detected',
          ),
      },
    );
  }
}

final class RecordingAdapter implements AttestationAdapter {
  final calls = <AttestationProvider>[];
  @override
  Future<AttestationAssessment> assess(
    AttestationProvider provider,
    AttestationClient client,
  ) async {
    calls.add(provider);
    return AttestationAssessment(
      provider: provider,
      status: AttestationStatus.trusted,
      reasonCode: 'backend_verified',
    );
  }
}

void main() {
  late FakePlatform platform;
  setUp(() {
    platform = FakePlatform();
    DeviceSecurityGuardPlatform.instance = platform;
  });

  test('attestation is disabled by default', () async {
    final result = await DeviceSecurityGuard.assess();
    expect(result.attestations, isEmpty);
    expect(platform.nativeAssessCalls, 1);
  });

  test('Android invokes only enabled Play Integrity adapter', () async {
    final adapter = RecordingAdapter();
    final result = await DeviceSecurityGuard.assess(
      options: SecurityOptions(
        enablePlayIntegrity: true,
        enableAppAttest: true,
        attestationAdapter: adapter,
      ),
    );
    expect(adapter.calls, [AttestationProvider.playIntegrity]);
    expect(result.attestations.single.status, AttestationStatus.trusted);
  });
}
```

- [ ] **Step 2: Viết channel contract test cho payload thiếu tín hiệu**

Create `test/method_channel_device_security_guard_test.dart` và mock channel `dev.vannghia/device_security_guard` trả payload Android chỉ có `debugger`. Assert parser tự thêm sáu tín hiệu Android còn thiếu với `CheckStatus.inconclusive` và `reasonCode == 'missing_signal'`.

Payload mock chính xác:

```dart
const payload = <String, Object?>{
  'schemaVersion': 1,
  'platform': 'android',
  'operatingSystemVersion': '16',
  'assessedAtEpochMs': 1787443200000,
  'signals': <String, Object?>{
    'debugger': <String, Object?>{
      'status': 'notDetected',
      'reasonCode': 'debugger_not_attached',
    },
  },
};
```

- [ ] **Step 3: Chạy test để xác nhận thất bại**

Run:

```bash
flutter test test/security_options_test.dart test/method_channel_device_security_guard_test.dart test/device_security_guard_test.dart
```

Expected: FAIL vì options, platform interface và facade chưa tồn tại.

- [ ] **Step 4: Implement contract tối thiểu**

Create `lib/src/attestation.dart`:

```dart
import 'dart:typed_data';
import 'models.dart';

abstract interface class AttestationAdapter {
  Future<AttestationAssessment> assess(
    AttestationProvider provider,
    AttestationClient client,
  );
}

abstract interface class AttestationClient {
  Future<String> requestPlayIntegrityToken({
    required int cloudProjectNumber,
    required String requestHash,
  });
  Future<bool> isAppAttestSupported();
  Future<String> generateAppAttestKey();
  Future<Uint8List> attestAppAttestKey({
    required String keyId,
    required Uint8List clientDataHash,
  });
  Future<Uint8List> generateAppAttestAssertion({
    required String keyId,
    required Uint8List clientDataHash,
  });
}
```

Create `SecurityOptions` với defaults `false`, sets cho certificate/team ID và validation tối thiểu:

```dart
final class SecurityOptions {
  SecurityOptions({
    this.enablePlayIntegrity = false,
    this.enableAppAttest = false,
    Set<String> expectedAndroidCertificateSha256 = const {},
    Set<String> expectedIosTeamIdentifiers = const {},
    this.attestationAdapter,
  }) : expectedAndroidCertificateSha256 = Set.unmodifiable(
         expectedAndroidCertificateSha256,
       ),
       expectedIosTeamIdentifiers = Set.unmodifiable(
         expectedIosTeamIdentifiers,
       );
  final bool enablePlayIntegrity;
  final bool enableAppAttest;
  final Set<String> expectedAndroidCertificateSha256;
  final Set<String> expectedIosTeamIdentifiers;
  final AttestationAdapter? attestationAdapter;

  void validate() {
    if ((enablePlayIntegrity || enableAppAttest) && attestationAdapter == null) {
      throw ArgumentError('An AttestationAdapter is required when attestation is enabled.');
    }
  }
}
```

Create `DeviceSecurityGuardPlatform` với hai constant sets:

```dart
static const androidSignals = {
  SecuritySignal.debugger,
  SecuritySignal.emulator,
  SecuritySignal.adbEnabled,
  SecuritySignal.hooking,
  SecuritySignal.repackaging,
  SecuritySignal.root,
  SecuritySignal.bootloaderUnlocked,
};
static const iosSignals = {
  SecuritySignal.debugger,
  SecuritySignal.emulator,
  SecuritySignal.hooking,
  SecuritySignal.repackaging,
  SecuritySignal.jailbreak,
};
```

`DeviceSecurityGuardPlatform` implement mặc định năm method `AttestationClient` bằng `UnsupportedError`; fake platform chỉ cần override method đang được test. `instance` mặc định là `MethodChannelDeviceSecurityGuard` và có setter phục vụ test theo pattern của Flutter plugin template.

`MethodChannelDeviceSecurityGuard` dùng channel `dev.vannghia/device_security_guard`, method `assess`, schema version `1`, truyền hai list `expectedAndroidCertificateSha256` và `expectedIosTeamIdentifiers`. Parser từ chối schema/platform/status không biết bằng `PlatformException(code: 'invalid_payload')`; mỗi tín hiệu bắt buộc bị thiếu được thêm dưới dạng `inconclusive/missing_signal`.

Facade gọi adapter chỉ theo platform thực tế:

```dart
abstract final class DeviceSecurityGuard {
  static Future<SecurityAssessment> assess({
    SecurityOptions? options,
  }) async {
    options ??= SecurityOptions();
    options.validate();
    final platform = DeviceSecurityGuardPlatform.instance;
    final local = await platform.assessLocal(options);
    final provider = switch (local.platform) {
      SecurityPlatform.android when options.enablePlayIntegrity =>
        AttestationProvider.playIntegrity,
      SecurityPlatform.iOS when options.enableAppAttest =>
        AttestationProvider.appAttest,
      _ => null,
    };
    if (provider == null) return local;
    final AttestationAssessment attestation;
    try {
      final value = await options.attestationAdapter!.assess(provider, platform);
      attestation = value.provider == provider
          ? value
          : AttestationAssessment(
              provider: provider,
              status: AttestationStatus.inconclusive,
              reasonCode: 'adapter_provider_mismatch',
            );
    } catch (_) {
      attestation = AttestationAssessment(
        provider: provider,
        status: AttestationStatus.inconclusive,
        reasonCode: 'attestation_error',
      );
    }
    return local.withAttestations([attestation]);
  }
}
```

- [ ] **Step 5: Chạy test, format và analyze**

```bash
dart format lib test
flutter test test/security_options_test.dart test/method_channel_device_security_guard_test.dart test/device_security_guard_test.dart
flutter analyze
```

Expected: PASS và không có analyzer issue.

- [ ] **Step 6: Commit task**

```bash
git add lib test
git commit -m "feat: add platform and attestation contracts"
```

---

### Task 3: Android local security detectors

**Files:**
- Modify: `android/build.gradle`
- Modify: `android/src/main/AndroidManifest.xml`
- Create: `android/src/main/kotlin/dev/vannghia/device_security_guard/AndroidSignalClassifier.kt`
- Create: `android/src/main/kotlin/dev/vannghia/device_security_guard/AndroidSecurityDetector.kt`
- Modify: `android/src/main/kotlin/dev/vannghia/device_security_guard/DeviceSecurityGuardPlugin.kt`
- Create: `android/src/test/kotlin/dev/vannghia/device_security_guard/AndroidSignalClassifierTest.kt`

**Interfaces:**
- Consumes: channel method `assess` và schema version `1` từ Task 2.
- Produces: Android results cho `debugger`, `emulator`, `adbEnabled`, `hooking`, `repackaging`, `root`, `bootloaderUnlocked`.

- [ ] **Step 1: Đặt Android build floor và test dependency**

Trong `android/build.gradle`, đặt namespace `dev.vannghia.device_security_guard`, `compileSdk = 36`, `minSdk = 23`, Java/Kotlin target 17 và:

```gradle
dependencies {
    testImplementation 'junit:junit:4.13.2'
}
```

- [ ] **Step 2: Viết Kotlin test thất bại cho classifier**

Create `AndroidSignalClassifierTest.kt`:

```kotlin
package dev.vannghia.device_security_guard

import org.junit.Assert.assertEquals
import org.junit.Test

class AndroidSignalClassifierTest {
    @Test
    fun emulatorRequiresOneStrongIndicator() {
        assertEquals(
            CheckValue.DETECTED,
            AndroidSignalClassifier.emulator(
                BuildSnapshot(
                    fingerprint = "google/sdk_gphone64_arm64/emu64a:16/test-keys",
                    model = "sdk_gphone64_arm64",
                    manufacturer = "Google",
                    brand = "google",
                    device = "emu64a",
                    product = "sdk_gphone64_arm64",
                    hardware = "ranchu",
                ),
                qemu = "1",
            ),
        )
    }

    @Test
    fun hookNamesAreCaseInsensitive() {
        assertEquals(
            CheckValue.DETECTED,
            AndroidSignalClassifier.hooking("/data/local/tmp/FRIDA-agent.so"),
        )
    }

    @Test
    fun unlockedVerifiedBootIsDetected() {
        assertEquals(
            CheckValue.DETECTED,
            AndroidSignalClassifier.bootloader(
                verifiedBootState = "orange",
                flashLocked = "0",
                vbmetaDeviceState = "unlocked",
            ),
        )
    }
}
```

- [ ] **Step 3: Chạy Android unit test để xác nhận thất bại**

```bash
cd example/android
./gradlew :device_security_guard:testDebugUnitTest
```

Expected: FAIL vì classifier chưa tồn tại.

- [ ] **Step 4: Implement Kotlin classifier thuần**

Create `AndroidSignalClassifier.kt` với:

```kotlin
internal enum class CheckValue { DETECTED, NOT_DETECTED, INCONCLUSIVE }

internal data class BuildSnapshot(
    val fingerprint: String,
    val model: String,
    val manufacturer: String,
    val brand: String,
    val device: String,
    val product: String,
    val hardware: String,
)

internal object AndroidSignalClassifier {
    private val hookNames = listOf(
        "frida", "xposed", "substrate", "edxposed", "lsposed", "libhooker",
    )

    fun emulator(build: BuildSnapshot, qemu: String?): CheckValue {
        val values = listOf(
            build.fingerprint, build.model, build.manufacturer,
            build.brand, build.device, build.product, build.hardware,
        ).map(String::lowercase)
        val detected = qemu == "1" || values.any { value ->
            listOf("generic", "unknown", "emulator", "google_sdk", "sdk_gphone", "genymotion", "ranchu", "goldfish", "vbox").any(value::contains)
        }
        return if (detected) CheckValue.DETECTED else CheckValue.NOT_DETECTED
    }

    fun hooking(processMaps: String): CheckValue =
        if (hookNames.any(processMaps.lowercase()::contains)) CheckValue.DETECTED
        else CheckValue.NOT_DETECTED

    fun bootloader(
        verifiedBootState: String?,
        flashLocked: String?,
        vbmetaDeviceState: String?,
    ): CheckValue {
        val values = listOfNotNull(
            verifiedBootState?.lowercase(),
            flashLocked?.lowercase(),
            vbmetaDeviceState?.lowercase(),
        )
        if (values.any { it in setOf("orange", "red", "0", "unlocked") }) {
            return CheckValue.DETECTED
        }
        if (values.any { it in setOf("green", "1", "locked") }) {
            return CheckValue.NOT_DETECTED
        }
        return CheckValue.INCONCLUSIVE
    }
}
```

- [ ] **Step 5: Implement Android environment collection**

`AndroidSecurityDetector` thực hiện các phép kiểm tra sau và trả map `{status, reasonCode}`:

- debugger: `Debug.isDebuggerConnected()` hoặc `Debug.waitingForDebugger()`;
- emulator: `BuildSnapshot` và `/system/bin/getprop ro.kernel.qemu`;
- ADB: `Settings.Global.getInt(contentResolver, Settings.Global.ADB_ENABLED, 0)`;
- hooking: nội dung `/proc/self/maps` và `Class.forName` cho Xposed/Substrate;
- repackaging: `PackageManager.GET_SIGNING_CERTIFICATES`, SHA-256 uppercase hex, so với danh sách từ Dart; danh sách mong đợi rỗng trả `inconclusive/expected_identity_missing`;
- root: `Build.TAGS` chứa `test-keys`, hoặc tồn tại một trong `/system/bin/su`, `/system/xbin/su`, `/sbin/su`, `/data/adb/magisk`, `/system/app/Superuser.apk`;
- bootloader: đọc `ro.boot.verifiedbootstate`, `ro.boot.flash.locked`, `ro.boot.vbmeta.device_state` bằng `/system/bin/getprop` rồi dùng classifier.

Mỗi detector được bọc `runCatching`; exception trả `inconclusive/detector_error`. Không trả path thô trong payload.

Helper dùng chung trong detector:

```kotlin
private inline fun safeSignal(block: () -> SignalPayload): SignalPayload =
    runCatching(block).getOrElse {
        SignalPayload(CheckValue.INCONCLUSIVE, "detector_error")
    }

private fun property(name: String): String? =
    runCatching {
        ProcessBuilder("/system/bin/getprop", name)
            .start().inputStream.bufferedReader().use { it.readLine()?.trim() }
    }.getOrNull()?.takeIf(String::isNotEmpty)
```

- [ ] **Step 6: Wire method `assess` trong Android plugin**

`DeviceSecurityGuardPlugin` đọc `expectedAndroidCertificateSha256`, gọi detector và trả:

```kotlin
mapOf(
    "schemaVersion" to 1,
    "platform" to "android",
    "operatingSystemVersion" to Build.VERSION.RELEASE,
    "assessedAtEpochMs" to System.currentTimeMillis(),
    "signals" to detector.assess(expectedCertificates),
)
```

- [ ] **Step 7: Chạy Kotlin test và Android build**

```bash
cd example/android
./gradlew :device_security_guard:testDebugUnitTest
cd ../..
flutter build apk --debug
```

Expected: test PASS, APK build thành công với target/compile API 36.

- [ ] **Step 8: Commit task**

```bash
git add android example/android
git commit -m "feat(android): add local security detectors"
```

---

### Task 4: Android Play Integrity client opt-in

**Files:**
- Modify: `android/build.gradle`
- Create: `android/src/main/kotlin/dev/vannghia/device_security_guard/PlayIntegrityClient.kt`
- Modify: `android/src/main/kotlin/dev/vannghia/device_security_guard/DeviceSecurityGuardPlugin.kt`
- Modify: `test/method_channel_device_security_guard_test.dart`

**Interfaces:**
- Consumes: `AttestationClient.requestPlayIntegrityToken` từ Task 2.
- Produces: channel method `requestPlayIntegrityToken` trả encrypted Standard Integrity token.

- [ ] **Step 1: Viết Dart channel test thất bại**

Mock method `requestPlayIntegrityToken` và assert arguments chính xác:

```dart
expect(call.method, 'requestPlayIntegrityToken');
expect(call.arguments, {
  'cloudProjectNumber': 123456789,
  'requestHash': 'sha256-base64url',
});
```

Assert method trả token `encrypted-token` và default `DeviceSecurityGuard.assess()` không gọi method này.

- [ ] **Step 2: Chạy test để xác nhận thất bại**

```bash
flutter test test/method_channel_device_security_guard_test.dart
```

Expected: FAIL vì method chưa được wire.

- [ ] **Step 3: Thêm Play Integrity dependency và client**

Trong `android/build.gradle`:

```gradle
dependencies {
    implementation 'com.google.android.play:integrity:1.6.0'
    testImplementation 'junit:junit:4.13.2'
}
```

`PlayIntegrityClient` dùng `IntegrityManagerFactory.createStandard(context)`, cache `StandardIntegrityTokenProvider` theo `cloudProjectNumber`, gọi `prepareIntegrityToken`, sau đó:

```kotlin
provider.request(
    StandardIntegrityTokenRequest.builder()
        .setRequestHash(requestHash)
        .build(),
).addOnSuccessListener { token -> result.success(token.token()) }
 .addOnFailureListener { error ->
     result.error("play_integrity_error", error.javaClass.simpleName, null)
 }
```

Không log token hoặc exception message từ Google.

- [ ] **Step 4: Wire channel method và Dart client**

Android plugin validate `cloudProjectNumber > 0` và `requestHash.isNotBlank()`, nếu sai trả `invalid_arguments`. Dart `MethodChannelDeviceSecurityGuard.requestPlayIntegrityToken` gọi đúng method và chỉ được gọi bởi host adapter.

```kotlin
"requestPlayIntegrityToken" -> {
    val project = call.argument<Number>("cloudProjectNumber")?.toLong()
    val hash = call.argument<String>("requestHash")
    if (project == null || project <= 0 || hash.isNullOrBlank()) {
        result.error("invalid_arguments", "cloudProjectNumber and requestHash are required", null)
    } else {
        playIntegrityClient.request(project, hash, result)
    }
}
```

- [ ] **Step 5: Chạy test và Android build**

```bash
dart format lib test
flutter test test/method_channel_device_security_guard_test.dart test/device_security_guard_test.dart
flutter build apk --debug
```

Expected: PASS; build resolve Play Integrity 1.6.0 thành công.

- [ ] **Step 6: Commit task**

```bash
git add android lib test
git commit -m "feat(android): add opt-in Play Integrity client"
```

---

### Task 5: iOS local security detectors

**Files:**
- Modify: `ios/device_security_guard.podspec`
- Create: `ios/Classes/IOSSignalClassifier.swift`
- Create: `ios/Classes/IOSSecurityDetector.swift`
- Modify: `ios/Classes/DeviceSecurityGuardPlugin.swift`
- Create: `ios/Tests/IOSSignalClassifierTests.swift`

**Interfaces:**
- Consumes: channel method `assess` và schema version `1` từ Task 2.
- Produces: iOS results cho `debugger`, `emulator`, `hooking`, `repackaging`, `jailbreak`.

- [ ] **Step 1: Đặt deployment target và CocoaPods test spec**

Trong podspec:

```ruby
s.platform = :ios, '15.0'
s.swift_version = '5.0'
s.frameworks = 'Security', 'DeviceCheck'
s.test_spec 'Tests' do |test_spec|
  test_spec.source_files = 'Tests/**/*.swift'
end
```

- [ ] **Step 2: Viết Swift classifier test thất bại**

Create `ios/Tests/IOSSignalClassifierTests.swift`:

```swift
import XCTest
@testable import device_security_guard

final class IOSSignalClassifierTests: XCTestCase {
    func testFridaImageIsDetected() {
        XCTAssertEqual(
            IOSSignalClassifier.hooking(images: ["/usr/lib/FridaGadget.dylib"], dyldInsertLibraries: nil),
            .detected
        )
    }

    func testExpectedTeamIdentifierMatches() {
        XCTAssertEqual(
            IOSSignalClassifier.repackaging(actualTeamIdentifier: "TEAM123", expected: ["TEAM123"]),
            .notDetected
        )
    }

    func testMissingExpectedTeamIdentifierIsInconclusive() {
        XCTAssertEqual(
            IOSSignalClassifier.repackaging(actualTeamIdentifier: "TEAM123", expected: []),
            .inconclusive
        )
    }
}
```

- [ ] **Step 3: Implement Swift classifier tối thiểu**

Create `IOSSignalClassifier.swift`:

```swift
import Foundation

enum IOSCheckValue: String {
    case detected
    case notDetected
    case inconclusive
}

enum IOSSignalClassifier {
    private static let hookNames = [
        "frida", "substrate", "substitute", "libhooker", "ellekit", "cycript", "sslkillswitch"
    ]

    static func hooking(images: [String], dyldInsertLibraries: String?) -> IOSCheckValue {
        let values = images + [dyldInsertLibraries].compactMap { $0 }
        return values.map { $0.lowercased() }.contains { value in
            hookNames.contains { value.contains($0) }
        } ? .detected : .notDetected
    }

    static func repackaging(actualTeamIdentifier: String?, expected: Set<String>) -> IOSCheckValue {
        guard !expected.isEmpty, let actualTeamIdentifier else { return .inconclusive }
        return expected.contains(actualTeamIdentifier) ? .notDetected : .detected
    }
}
```

- [ ] **Step 4: Implement iOS environment collection**

`IOSSecurityDetector` thực hiện:

- debugger: `sysctl` với `KERN_PROC_PID`, kiểm tra `P_TRACED`;
- emulator: `#if targetEnvironment(simulator)`;
- hooking: `_dyld_image_count`, `_dyld_get_image_name`, biến môi trường `DYLD_INSERT_LIBRARIES`;
- repackaging: đọc Keychain access group bằng Security framework công khai để suy ra Team ID của bản ký đang chạy, so với expected Team IDs; expected rỗng trả `inconclusive/expected_identity_missing`;
- jailbreak: kiểm tra các artifact `/Applications/Cydia.app`, `/Library/MobileSubstrate/MobileSubstrate.dylib`, `/bin/bash`, `/usr/sbin/sshd`, `/var/jb`, và thử tạo/xóa file tên ngẫu nhiên dưới `/private` để phát hiện vượt sandbox.

Không trả đường dẫn cụ thể qua channel. Lỗi detector trả `inconclusive/detector_error`.

Debugger helper dùng API Darwin trực tiếp:

```swift
private func isDebuggerAttached() -> Bool? {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var mib = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return nil }
    return (info.kp_proc.p_flag & P_TRACED) != 0
}
```

- [ ] **Step 5: Wire iOS method `assess`**

Plugin đọc `expectedIosTeamIdentifiers`, gọi detector và trả schema giống Android với `platform = "ios"`. Kết quả chỉ chứa năm tín hiệu iOS.

```swift
result([
    "schemaVersion": 1,
    "platform": "ios",
    "operatingSystemVersion": UIDevice.current.systemVersion,
    "assessedAtEpochMs": Int64(Date().timeIntervalSince1970 * 1000),
    "signals": detector.assess(expectedTeamIdentifiers: expectedTeams),
])
```

- [ ] **Step 6: Chạy Swift tests và iOS simulator build**

```bash
cd example/ios
pod install
xcodebuild test \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO
cd ../..
flutter build ios --simulator
```

Expected: classifier tests PASS và iOS build thành công với deployment target 15.0.

- [ ] **Step 7: Commit task**

```bash
git add ios example/ios
git commit -m "feat(ios): add local security detectors"
```

---

### Task 6: iOS App Attest client opt-in

**Files:**
- Create: `ios/Classes/AppAttestClient.swift`
- Modify: `ios/Classes/DeviceSecurityGuardPlugin.swift`
- Modify: `lib/src/method_channel_device_security_guard.dart`
- Modify: `test/method_channel_device_security_guard_test.dart`

**Interfaces:**
- Consumes: App Attest methods trong `AttestationClient` từ Task 2.
- Produces: `isAppAttestSupported`, `generateAppAttestKey`, `attestAppAttestKey`, `generateAppAttestAssertion` qua channel.

- [ ] **Step 1: Viết Dart channel tests thất bại**

Kiểm tra bốn method và payload base64:

```dart
expect(await client.isAppAttestSupported(), isTrue);
expect(await client.generateAppAttestKey(), 'key-id');
expect(
  await client.attestAppAttestKey(
    keyId: 'key-id',
    clientDataHash: Uint8List.fromList([1, 2, 3]),
  ),
  Uint8List.fromList([4, 5, 6]),
);
```

Mock channel nhận `clientDataHash = 'AQID'` và trả `artifact = 'BAUG'`.

- [ ] **Step 2: Chạy test để xác nhận thất bại**

```bash
flutter test test/method_channel_device_security_guard_test.dart
```

Expected: FAIL vì App Attest methods chưa được implement.

- [ ] **Step 3: Implement `AppAttestClient` bằng DeviceCheck**

Wrapper dùng `DCAppAttestService.shared`, trả `isSupported`, và ánh xạ callback:

```swift
service.generateKey { keyId, error in
    guard error == nil, let keyId else {
        result(FlutterError(code: "app_attest_error", message: error.map { String(describing: type(of: $0)) }, details: nil))
        return
    }
    result(keyId)
}
```

`attestKey(_:clientDataHash:)` và `generateAssertion(_:clientDataHash:)` trả dictionary `{"artifact": data.base64EncodedString()}`. Không ghi log `keyId`, hash hoặc artifact.

- [ ] **Step 4: Wire Swift channel và Dart base64 conversion**

Swift từ chối key rỗng và base64 sai bằng `invalid_arguments`. Dart dùng `base64Encode`/`base64Decode`; artifact thiếu hoặc sai type ném `PlatformException(code: 'invalid_payload')`.

```dart
final response = await methodChannel.invokeMapMethod<String, Object?>(
  'attestAppAttestKey',
  {'keyId': keyId, 'clientDataHash': base64Encode(clientDataHash)},
);
final artifact = response?['artifact'];
if (artifact is! String) {
  throw PlatformException(code: 'invalid_payload');
}
return base64Decode(artifact);
```

- [ ] **Step 5: Chạy Dart tests và iOS build**

```bash
dart format lib test
flutter test test/method_channel_device_security_guard_test.dart test/device_security_guard_test.dart
flutter build ios --simulator
```

Expected: PASS và DeviceCheck link thành công.

- [ ] **Step 6: Commit task**

```bash
git add ios lib test
git commit -m "feat(ios): add opt-in App Attest client"
```

---

### Task 7: Example app và tài liệu phát hành

**Files:**
- Modify: `example/lib/main.dart`
- Modify: `example/android/app/build.gradle.kts`
- Modify: `example/ios/Podfile`
- Modify: `pubspec.yaml`
- Create: `README.md`
- Create: `CHANGELOG.md`
- Create: `LICENSE`
- Create: `SECURITY.md`
- Create: `doc/circular-77-coverage-vi.md`
- Create: `test/public_api_test.dart`

**Interfaces:**
- Consumes: toàn bộ API từ Tasks 1–6.
- Produces: public integration example và package metadata dùng cho pub.dev dry-run.

- [ ] **Step 1: Viết public API smoke test thất bại**

Create `test/public_api_test.dart` chỉ import public library và tạo:

```dart
const options = SecurityOptions(
  expectedAndroidCertificateSha256: {'AABBCC'},
  expectedIosTeamIdentifiers: {'TEAM123'},
);
expect(options.enablePlayIntegrity, isFalse);
expect(options.enableAppAttest, isFalse);
```

Test không import file trong `lib/src`.

- [ ] **Step 2: Tạo example app tối thiểu**

`example/lib/main.dart` có một nút “Run assessment”, gọi `DeviceSecurityGuard.assess()`, hiển thị từng signal/status/reason và `Circular77Policy.evaluate`. Example không tự thoát app và không cấu hình adapter giả làm trusted.

```dart
Future<void> runAssessment() async {
  final assessment = await DeviceSecurityGuard.assess();
  final decision = Circular77Policy.evaluate(assessment);
  if (!mounted) return;
  setState(() {
    _assessment = assessment;
    _decision = decision;
  });
}
```

Đặt Android example `targetSdk = 36`, iOS Podfile `platform :ios, '15.0'`.

- [ ] **Step 3: Viết README và tài liệu bảo mật**

README bao gồm:

- bảng Android/iOS cho tám tín hiệu;
- quick start local-only;
- ví dụ `AttestationAdapter` gọi backend nhưng dùng tên endpoint minh họa `https://bank.example/security/attest`;
- cách lấy Android signing certificate SHA-256 và iOS Team ID;
- hành vi `inconclusive`, `indeterminate`, `failClosed`;
- cảnh báo best-effort và không chứng nhận tuân thủ;
- Play Integrity/App Attest mặc định tắt và không có network call khi tắt.

`doc/circular-77-coverage-vi.md` ánh xạ từng dấu hiệu của khoản 2 Điều 5 Thông tư 77/2025/TT-NHNN sang `SecuritySignal`, nền tảng và giới hạn detector.

`SECURITY.md` yêu cầu báo cáo riêng tư, không mở public issue chứa bypass chi tiết hoặc token. `LICENSE` dùng MIT. `CHANGELOG.md` ghi release `0.1.0`.

- [ ] **Step 4: Hoàn thiện pubspec metadata không dùng URL giả**

Giữ `homepage`, `repository` và `issue_tracker` chưa khai báo vì repository chưa có remote. Khai báo:

```yaml
topics:
  - security
  - root-detection
  - jailbreak-detection
  - mobile-security
  - banking
```

Không thêm screenshot hoặc dependency chỉ để tăng pub points.

- [ ] **Step 5: Chạy test và example build**

```bash
dart format lib test example/lib
flutter test
flutter analyze
flutter build apk --debug
flutter build ios --simulator
```

Expected: PASS và hai example build thành công.

- [ ] **Step 6: Commit task**

```bash
git add README.md CHANGELOG.md LICENSE SECURITY.md doc pubspec.yaml example test/public_api_test.dart
git commit -m "docs: add integration guide and compliance matrix"
```

---

### Task 8: Release verification và pub.dev dry-run

**Files:**
- Modify: chỉ các file gây lỗi được chỉ ra trực tiếp bởi verification.
- Create: không tạo abstraction hoặc CI config mới trong task này.

**Interfaces:**
- Consumes: package hoàn chỉnh từ Tasks 1–7.
- Produces: bằng chứng build/test/package validation và working tree sạch.

- [ ] **Step 1: Chạy full Dart verification**

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Expected: exit code 0 cho cả ba lệnh.

- [ ] **Step 2: Chạy native verification**

```bash
cd example/android
./gradlew :device_security_guard:testDebugUnitTest
cd ../..
flutter build apk --debug
flutter build ios --simulator
```

Expected: Kotlin tests PASS, Android và iOS build thành công.

- [ ] **Step 3: Kiểm tra package publication**

```bash
dart pub publish --dry-run
```

Expected: không có error. Warning về URL repository bị thiếu được chấp nhận cho tới khi chủ package tạo remote thật; không thêm URL giả.

- [ ] **Step 4: Kiểm tra bảo mật và phạm vi**

```bash
rg -n 'print\(|debugPrint\(|token|assertion|secret|service.?account' lib android ios
rg -n 'exit\(|SystemNavigator\.pop|finishAffinity|abort\(' lib android ios
git diff --check
git status --short
```

Expected: không log raw token/assertion/secret; không có code tự thoát app; không có whitespace error; chỉ còn thay đổi verification đã biết.

- [ ] **Step 5: Commit sửa lỗi verification nếu có**

Nếu Step 1–4 buộc phải sửa file, chạy lại đúng lệnh đã thất bại rồi commit các sửa đổi đã kiểm chứng:

```bash
git add -A
git commit -m "chore: prepare package release"
```

Nếu không có thay đổi, không tạo empty commit.
