package dev.vannghia.device_security_guard

internal enum class CheckValue(val wireValue: String) {
    DETECTED("detected"),
    NOT_DETECTED("notDetected"),
    INCONCLUSIVE("inconclusive"),
}

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
    private val hookMarkers =
        setOf("frida", "xposed", "edxposed", "lsposed", "substrate", "libhooker")

    fun emulator(build: BuildSnapshot, qemu: String?): CheckValue {
        val fields =
            listOf(
                build.fingerprint,
                build.model,
                build.manufacturer,
                build.brand,
                build.device,
                build.product,
                build.hardware,
            ).map(String::lowercase)

        val detected =
            qemu == "1" ||
                fields.any { value ->
                    value.contains("generic") ||
                        value.contains("sdk_gphone") ||
                        value.contains("emulator") ||
                        value.contains("android sdk built for") ||
                        value.contains("genymotion") ||
                        value.contains("goldfish") ||
                        value.contains("ranchu") ||
                        value.contains("vbox")
                }
        return if (detected) CheckValue.DETECTED else CheckValue.NOT_DETECTED
    }

    fun hooking(
        processMaps: String?,
        loadedFrameworks: Set<String> = emptySet(),
    ): CheckValue {
        val normalized =
            listOfNotNull(processMaps)
                .plus(loadedFrameworks)
                .joinToString()
                .lowercase()
        return if (hookMarkers.any(normalized::contains)) {
            CheckValue.DETECTED
        } else if (processMaps == null) {
            CheckValue.INCONCLUSIVE
        } else {
            CheckValue.NOT_DETECTED
        }
    }

    fun root(
        buildTags: String?,
        existingArtifacts: Set<String>,
        debuggable: String?,
        secure: String?,
    ): CheckValue {
        val detected =
            buildTags?.contains("test-keys", ignoreCase = true) == true ||
                existingArtifacts.isNotEmpty() ||
                debuggable == "1" ||
                secure == "0"
        return if (detected) CheckValue.DETECTED else CheckValue.NOT_DETECTED
    }

    fun bootloader(
        verifiedBootState: String?,
        flashLocked: String?,
        vbmetaDeviceState: String?,
    ): CheckValue {
        val values =
            listOfNotNull(verifiedBootState, flashLocked, vbmetaDeviceState)
                .map { it.trim().lowercase() }

        if (values.any { it in setOf("orange", "red", "unlocked", "0") }) {
            return CheckValue.DETECTED
        }
        if (values.isEmpty()) return CheckValue.INCONCLUSIVE

        val recognized = values.all { it in setOf("green", "locked", "1") }
        return if (recognized) CheckValue.NOT_DETECTED else CheckValue.INCONCLUSIVE
    }

    fun repackaging(
        actualCertificates: Set<String>,
        expectedCertificates: Set<String>,
    ): CheckValue {
        if (actualCertificates.isEmpty() || expectedCertificates.isEmpty()) {
            return CheckValue.INCONCLUSIVE
        }
        return if (actualCertificates.any(expectedCertificates::contains)) {
            CheckValue.NOT_DETECTED
        } else {
            CheckValue.DETECTED
        }
    }
}
