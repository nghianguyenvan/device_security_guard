package dev.vannghia.device_security_guard

import kotlin.test.Test
import kotlin.test.assertEquals

internal class AndroidSignalClassifierTest {
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
                qemu = "0",
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
    fun unavailableProcessMapsAreInconclusive() {
        assertEquals(
            CheckValue.INCONCLUSIVE,
            AndroidSignalClassifier.hooking(processMaps = null),
        )
    }

    @Test
    fun rootArtifactIsDetected() {
        assertEquals(
            CheckValue.DETECTED,
            AndroidSignalClassifier.root(
                buildTags = "release-keys",
                existingArtifacts = setOf("su"),
                debuggable = "0",
                secure = "1",
            ),
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

    @Test
    fun unavailableBootPropertiesAreInconclusive() {
        assertEquals(
            CheckValue.INCONCLUSIVE,
            AndroidSignalClassifier.bootloader(null, null, null),
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
}
