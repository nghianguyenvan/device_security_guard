package dev.vannghia.device_security_guard

import kotlin.test.Test
import kotlin.test.assertEquals

internal class AndroidSignalClassifierTest {
    @Test
    fun javaDebuggerIsDetectedWhenProcessStatusIsUnavailable() {
        assertEquals(
            CheckValue.DETECTED,
            AndroidSignalClassifier.debugger(
                javaDebuggerDetected = true,
                processStatus = null,
            ),
        )
    }

    @Test
    fun nativeTracerIsDetectedFromProcessStatus() {
        assertEquals(
            CheckValue.DETECTED,
            AndroidSignalClassifier.debugger(
                javaDebuggerDetected = false,
                processStatus = "Name:\tapp\nTracerPid:\t42\nState:\tR",
            ),
        )
    }

    @Test
    fun zeroTracerPidIsNotDetected() {
        assertEquals(
            CheckValue.NOT_DETECTED,
            AndroidSignalClassifier.debugger(
                javaDebuggerDetected = false,
                processStatus = "Name:\tapp\nTracerPid:\t0\nState:\tR",
            ),
        )
    }

    @Test
    fun unavailableProcessStatusMakesDebuggerInconclusive() {
        assertEquals(
            CheckValue.INCONCLUSIVE,
            AndroidSignalClassifier.debugger(
                javaDebuggerDetected = false,
                processStatus = null,
            ),
        )
    }

    @Test
    fun malformedTracerPidMakesDebuggerInconclusive() {
        assertEquals(
            CheckValue.INCONCLUSIVE,
            AndroidSignalClassifier.debugger(
                javaDebuggerDetected = false,
                processStatus = "Name:\tapp\nTracerPid:\tunknown",
            ),
        )
    }

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
                qemu = SystemPropertyRead.Value("1"),
            ),
        )
    }

    @Test
    fun physicalBuildIsNotDetectedAsEmulator() {
        assertEquals(
            CheckValue.NOT_DETECTED,
            AndroidSignalClassifier.emulator(
                BuildSnapshot(
                    fingerprint = "google/husky/husky:16/release-keys",
                    model = "Pixel 8 Pro",
                    manufacturer = "Google",
                    brand = "google",
                    device = "husky",
                    product = "husky",
                    hardware = "tensor",
                ),
                qemu = SystemPropertyRead.Value("0"),
            ),
        )
    }

    @Test
    fun singleGenericFieldDoesNotMarkPhysicalDeviceAsEmulator() {
        assertEquals(
            CheckValue.NOT_DETECTED,
            AndroidSignalClassifier.emulator(
                BuildSnapshot(
                    fingerprint = "vendor/device/device:16/release-keys",
                    model = "Generic Phone",
                    manufacturer = "Vendor",
                    brand = "vendor",
                    device = "device",
                    product = "product",
                    hardware = "hardware",
                ),
                qemu = SystemPropertyRead.Value("0"),
            ),
        )
    }

    @Test
    fun multipleGenericBuildFieldsAreDetectedAsEmulator() {
        assertEquals(
            CheckValue.DETECTED,
            AndroidSignalClassifier.emulator(
                BuildSnapshot(
                    fingerprint = "generic/device/device:16/release-keys",
                    model = "Phone",
                    manufacturer = "Vendor",
                    brand = "generic",
                    device = "device",
                    product = "product",
                    hardware = "hardware",
                ),
                qemu = SystemPropertyRead.Value("0"),
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
    fun modernRuntimeHookMarkerIsDetected() {
        assertEquals(
            CheckValue.DETECTED,
            AndroidSignalClassifier.hooking(
                "/data/adb/riru/lib/arm64/libriru.so",
            ),
        )
    }

    @Test
    fun unavailableProcessMapsAreInconclusive() {
        assertEquals(
            CheckValue.INCONCLUSIVE,
            AndroidSignalClassifier.hooking(processMaps = null),
        )
    }

    @Test
    fun loadedHookFrameworkIsDetectedWhenProcessMapsAreUnavailable() {
        assertEquals(
            CheckValue.DETECTED,
            AndroidSignalClassifier.hooking(
                processMaps = null,
                loadedFrameworks = setOf("de.robv.android.xposed.XposedBridge"),
            ),
        )
    }

    @Test
    fun cleanProcessMapsAreNotDetectedAsHooking() {
        assertEquals(
            CheckValue.NOT_DETECTED,
            AndroidSignalClassifier.hooking(
                "/system/lib64/libandroid_runtime.so\n/system/lib64/libc.so",
            ),
        )
    }

    @Test
    fun rootArtifactIsDetected() {
        assertEquals(
            CheckValue.DETECTED,
            AndroidSignalClassifier.root(
                buildTags = "release-keys",
                existingArtifacts = setOf("su"),
                debuggable = SystemPropertyRead.Value("0"),
                secure = SystemPropertyRead.Value("1"),
            ),
        )
    }

    @Test
    fun modernRootArtifactsAreDetected() {
        listOf(
            "/data/adb/magisk",
            "/data/adb/ksu",
            "/data/adb/ap",
            "/debug_ramdisk/.magisk",
        ).forEach { presentPath ->
            val artifacts =
                AndroidSignalClassifier.existingRootArtifacts { path -> path == presentPath }

            assertEquals(
                CheckValue.DETECTED,
                AndroidSignalClassifier.root(
                    buildTags = "release-keys",
                    existingArtifacts = artifacts,
                    debuggable = SystemPropertyRead.Value("0"),
                    secure = SystemPropertyRead.Value("1"),
                ),
                presentPath,
            )
        }
    }

    @Test
    fun cleanReleasePropertiesAreNotDetectedAsRoot() {
        assertEquals(
            CheckValue.NOT_DETECTED,
            AndroidSignalClassifier.root(
                buildTags = "release-keys",
                existingArtifacts = emptySet(),
                debuggable = SystemPropertyRead.Value("0"),
                secure = SystemPropertyRead.Value("1"),
            ),
        )
    }

    @Test
    fun independentRootIndicatorsAreDetected() {
        val cases =
            listOf(
                Triple("test-keys", SystemPropertyRead.Value("0"), SystemPropertyRead.Value("1")),
                Triple("release-keys", SystemPropertyRead.Value("1"), SystemPropertyRead.Value("1")),
                Triple("release-keys", SystemPropertyRead.Value("0"), SystemPropertyRead.Value("0")),
            )

        cases.forEach { (tags, debuggable, secure) ->
            assertEquals(
                CheckValue.DETECTED,
                AndroidSignalClassifier.root(tags, emptySet(), debuggable, secure),
                "tags=$tags debuggable=$debuggable secure=$secure",
            )
        }
    }

    @Test
    fun unlockedVerifiedBootIsDetected() {
        assertEquals(
            CheckValue.DETECTED,
            AndroidSignalClassifier.bootloader(
                verifiedBootState = SystemPropertyRead.Value("orange"),
                flashLocked = SystemPropertyRead.Value("0"),
                vbmetaDeviceState = SystemPropertyRead.Value("unlocked"),
            ),
        )
    }

    @Test
    fun unavailableBootPropertiesAreInconclusive() {
        assertEquals(
            CheckValue.INCONCLUSIVE,
            AndroidSignalClassifier.bootloader(
                SystemPropertyRead.Missing,
                SystemPropertyRead.Missing,
                SystemPropertyRead.Missing,
            ),
        )
    }

    @Test
    fun flashLockAloneIsInsufficientToDeclareBootloaderLocked() {
        assertEquals(
            CheckValue.INCONCLUSIVE,
            AndroidSignalClassifier.bootloader(
                verifiedBootState = SystemPropertyRead.Missing,
                flashLocked = SystemPropertyRead.Value("1"),
                vbmetaDeviceState = SystemPropertyRead.Missing,
            ),
        )
    }

    @Test
    fun verifiedGreenIsSufficientToDeclareBootloaderLocked() {
        assertEquals(
            CheckValue.NOT_DETECTED,
            AndroidSignalClassifier.bootloader(
                verifiedBootState = SystemPropertyRead.Value(" GREEN "),
                flashLocked = SystemPropertyRead.Missing,
                vbmetaDeviceState = SystemPropertyRead.Missing,
            ),
        )
    }

    @Test
    fun eachUnlockPropertyIsDetectedIndependently() {
        val cases =
            listOf(
                Triple("orange", null, null),
                Triple(null, "0", null),
                Triple(null, null, "unlocked"),
            )

        cases.forEach { (verifiedBoot, flashLock, vbmetaState) ->
            assertEquals(
                CheckValue.DETECTED,
                AndroidSignalClassifier.bootloader(
                    verifiedBoot?.let(SystemPropertyRead::Value) ?: SystemPropertyRead.Missing,
                    flashLock?.let(SystemPropertyRead::Value) ?: SystemPropertyRead.Missing,
                    vbmetaState?.let(SystemPropertyRead::Value) ?: SystemPropertyRead.Missing,
                ),
                "verifiedBoot=$verifiedBoot flashLock=$flashLock vbmetaState=$vbmetaState",
            )
        }
    }

    @Test
    fun unknownVerifiedBootStateIsInconclusive() {
        assertEquals(
            CheckValue.INCONCLUSIVE,
            AndroidSignalClassifier.bootloader(
                verifiedBootState = SystemPropertyRead.Value("yellow"),
                flashLocked = SystemPropertyRead.Value("1"),
                vbmetaDeviceState = SystemPropertyRead.Value("locked"),
            ),
        )
    }

    @Test
    fun bootPropertyReadErrorIsInconclusive() {
        assertEquals(
            CheckValue.INCONCLUSIVE,
            AndroidSignalClassifier.bootloader(
                SystemPropertyRead.Value("green"),
                SystemPropertyRead.Error,
                SystemPropertyRead.Value("locked"),
            ),
        )
    }

    @Test
    fun propertyReadErrorMakesEmulatorInconclusiveWithoutOtherIndicator() {
        assertEquals(
            CheckValue.INCONCLUSIVE,
            AndroidSignalClassifier.emulator(
                BuildSnapshot(
                    fingerprint = "google/husky/husky:16/release-keys",
                    model = "Pixel 8 Pro",
                    manufacturer = "Google",
                    brand = "google",
                    device = "husky",
                    product = "husky",
                    hardware = "tensor",
                ),
                qemu = SystemPropertyRead.Error,
            ),
        )
    }

    @Test
    fun propertyReadErrorMakesRootInconclusiveWithoutOtherIndicator() {
        assertEquals(
            CheckValue.INCONCLUSIVE,
            AndroidSignalClassifier.root(
                buildTags = "release-keys",
                existingArtifacts = emptySet(),
                debuggable = SystemPropertyRead.Error,
                secure = SystemPropertyRead.Missing,
            ),
        )
    }

    @Test
    fun missingSecurityPropertyMakesRootInconclusiveWithoutOtherIndicator() {
        assertEquals(
            CheckValue.INCONCLUSIVE,
            AndroidSignalClassifier.root(
                buildTags = "release-keys",
                existingArtifacts = emptySet(),
                debuggable = SystemPropertyRead.Missing,
                secure = SystemPropertyRead.Value("1"),
            ),
        )
    }

    @Test
    fun expectedCertificateMatchIsNotRepackaged() {
        assertEquals(
            CheckValue.NOT_DETECTED,
            AndroidSignalClassifier.repackaging(
                actualCertificates = setOf("AABB"),
                expectedCertificates = setOf("AABB"),
            ),
        )
    }

    @Test
    fun missingExpectedCertificateIsInconclusive() {
        assertEquals(
            CheckValue.INCONCLUSIVE,
            AndroidSignalClassifier.repackaging(
                actualCertificates = setOf("AABB"),
                expectedCertificates = emptySet(),
            ),
        )
    }

    @Test
    fun missingActualCertificateIsInconclusive() {
        assertEquals(
            CheckValue.INCONCLUSIVE,
            AndroidSignalClassifier.repackaging(
                actualCertificates = emptySet(),
                expectedCertificates = setOf("AABB"),
            ),
        )
    }

    @Test
    fun certificateMismatchIsDetectedAsRepackaging() {
        assertEquals(
            CheckValue.DETECTED,
            AndroidSignalClassifier.repackaging(
                actualCertificates = setOf("AABB"),
                expectedCertificates = setOf("CCDD"),
            ),
        )
    }
}
