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
        setOf(
            "frida",
            "xposed",
            "edxposed",
            "lsposed",
            "substrate",
            "libhooker",
            "zygisk",
            "riru",
            "sandhook",
            "yahfa",
            "libdobby",
        )
    private val rootArtifactPaths =
        setOf(
            "/system/app/Superuser.apk",
            "/system/bin/su",
            "/system/xbin/su",
            "/system/bin/.ext/.su",
            "/system/xbin/daemonsu",
            "/sbin/su",
            "/su/bin/su",
            "/data/local/bin/su",
            "/data/local/xbin/su",
            "/data/adb/magisk",
            "/data/adb/ksu",
            "/data/adb/ap",
            "/sbin/.magisk",
            "/debug_ramdisk/.magisk",
        )

    fun debugger(javaDebuggerDetected: Boolean, processStatus: String?): CheckValue {
        if (javaDebuggerDetected) return CheckValue.DETECTED

        val tracerPid =
            processStatus
                ?.lineSequence()
                ?.firstOrNull { it.startsWith("TracerPid:") }
                ?.substringAfter(':')
                ?.trim()
                ?.toIntOrNull()
                ?: return CheckValue.INCONCLUSIVE
        return if (tracerPid > 0) CheckValue.DETECTED else CheckValue.NOT_DETECTED
    }

    fun emulator(build: BuildSnapshot, qemu: SystemPropertyRead): CheckValue {
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

        val strongMarkerDetected =
            fields.any { value ->
                value.contains("sdk_gphone") ||
                    value.contains("emulator") ||
                    value.contains("android sdk built for") ||
                    value.contains("genymotion") ||
                    value.contains("goldfish") ||
                    value.contains("ranchu") ||
                    value.contains("vbox")
            }
        val multipleGenericMarkers = fields.count { it.contains("generic") } >= 2
        val detected = qemu.valueOrNull() == "1" || strongMarkerDetected || multipleGenericMarkers
        return when {
            detected -> CheckValue.DETECTED
            qemu == SystemPropertyRead.Error -> CheckValue.INCONCLUSIVE
            else -> CheckValue.NOT_DETECTED
        }
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

    fun existingRootArtifacts(pathExists: (String) -> Boolean): Set<String> =
        rootArtifactPaths.filterTo(linkedSetOf(), pathExists)

    fun root(
        buildTags: String?,
        existingArtifacts: Set<String>,
        debuggable: SystemPropertyRead,
        secure: SystemPropertyRead,
    ): CheckValue {
        val detected =
            buildTags?.contains("test-keys", ignoreCase = true) == true ||
                existingArtifacts.isNotEmpty() ||
                debuggable.valueOrNull() == "1" ||
                secure.valueOrNull() == "0"
        return when {
            detected -> CheckValue.DETECTED
            debuggable !is SystemPropertyRead.Value || secure !is SystemPropertyRead.Value ->
                CheckValue.INCONCLUSIVE
            debuggable.value != "0" || secure.value != "1" -> CheckValue.INCONCLUSIVE
            else -> CheckValue.NOT_DETECTED
        }
    }

    fun bootloader(
        verifiedBootState: SystemPropertyRead,
        flashLocked: SystemPropertyRead,
        vbmetaDeviceState: SystemPropertyRead,
    ): CheckValue {
        val properties = listOf(verifiedBootState, flashLocked, vbmetaDeviceState)
        val verifiedBoot = verifiedBootState.normalizedValueOrNull()
        val flashLock = flashLocked.normalizedValueOrNull()
        val vbmetaState = vbmetaDeviceState.normalizedValueOrNull()

        if (verifiedBoot in setOf("orange", "red") ||
            flashLock == "0" ||
            vbmetaState == "unlocked"
        ) {
            return CheckValue.DETECTED
        }
        if (properties.any { it == SystemPropertyRead.Error }) {
            return CheckValue.INCONCLUSIVE
        }
        if (verifiedBoot != null && verifiedBoot != "green") return CheckValue.INCONCLUSIVE
        if (flashLock != null && flashLock != "1") return CheckValue.INCONCLUSIVE
        if (vbmetaState != null && vbmetaState != "locked") return CheckValue.INCONCLUSIVE

        return if (verifiedBoot == "green" || vbmetaState == "locked") {
            CheckValue.NOT_DETECTED
        } else {
            CheckValue.INCONCLUSIVE
        }
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

private fun SystemPropertyRead.valueOrNull(): String? =
    (this as? SystemPropertyRead.Value)?.value

private fun SystemPropertyRead.normalizedValueOrNull(): String? =
    valueOrNull()?.trim()?.lowercase()
