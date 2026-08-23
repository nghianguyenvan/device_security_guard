package dev.vannghia.device_security_guard

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Debug
import android.provider.Settings
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.TimeUnit

internal class AndroidSecurityDetector(private val context: Context) {
    fun assess(expectedCertificates: Set<String>): Map<String, Map<String, String>> =
        linkedMapOf(
            "debugger" to safely(::debugger),
            "emulator" to safely(::emulator),
            "adbEnabled" to safely(::adbEnabled),
            "hooking" to safely(::hooking),
            "repackaging" to safely { repackaging(expectedCertificates) },
            "root" to safely(::root),
            "bootloaderUnlocked" to safely(::bootloader),
        )

    private fun debugger(): SignalResult =
        if (Debug.isDebuggerConnected() || Debug.waitingForDebugger()) {
            SignalResult(CheckValue.DETECTED, "debugger_attached")
        } else {
            SignalResult(CheckValue.NOT_DETECTED, "debugger_not_detected")
        }

    private fun emulator(): SignalResult {
        val value =
            AndroidSignalClassifier.emulator(
                BuildSnapshot(
                    fingerprint = Build.FINGERPRINT.orEmpty(),
                    model = Build.MODEL.orEmpty(),
                    manufacturer = Build.MANUFACTURER.orEmpty(),
                    brand = Build.BRAND.orEmpty(),
                    device = Build.DEVICE.orEmpty(),
                    product = Build.PRODUCT.orEmpty(),
                    hardware = Build.HARDWARE.orEmpty(),
                ),
                qemu = systemProperty("ro.kernel.qemu"),
            )
        return value.result("emulator_detected", "emulator_not_detected", "emulator_inconclusive")
    }

    private fun adbEnabled(): SignalResult {
        val enabled =
            Settings.Global.getInt(
                context.contentResolver,
                Settings.Global.ADB_ENABLED,
                0,
            ) == 1
        return if (enabled) {
            SignalResult(CheckValue.DETECTED, "adb_enabled")
        } else {
            SignalResult(CheckValue.NOT_DETECTED, "adb_disabled")
        }
    }

    private fun hooking(): SignalResult {
        val mapsFile = File("/proc/self/maps")
        val maps =
            mapsFile.takeIf(File::canRead)?.let { file ->
                runCatching(file::readText).getOrNull()
            }
        val loadedFrameworks =
            listOf(
                "de.robv.android.xposed.XposedBridge",
                "com.saurik.substrate.MS$2",
            ).filter { className ->
                runCatching { Class.forName(className) }.isSuccess
            }
        val value = AndroidSignalClassifier.hooking(maps, loadedFrameworks.toSet())
        return value.result(
            "hook_framework_detected",
            "hook_framework_not_detected",
            "process_maps_unavailable",
        )
    }

    private fun repackaging(expectedCertificates: Set<String>): SignalResult {
        val actual = signingCertificates()
        val expected = expectedCertificates.map(::normalizeCertificate).toSet()
        val value = AndroidSignalClassifier.repackaging(actual, expected)
        return value.result(
            "signing_certificate_mismatch",
            "signing_certificate_match",
            "signing_certificate_unconfigured",
        )
    }

    private fun root(): SignalResult {
        val artifacts =
            listOf(
                "/system/app/Superuser.apk",
                "/system/bin/su",
                "/system/xbin/su",
                "/sbin/su",
                "/data/local/bin/su",
                "/data/local/xbin/su",
                "/data/adb/magisk",
            ).filterTo(mutableSetOf()) { File(it).exists() }
        val value =
            AndroidSignalClassifier.root(
                buildTags = Build.TAGS,
                existingArtifacts = artifacts,
                debuggable = systemProperty("ro.debuggable"),
                secure = systemProperty("ro.secure"),
            )
        return value.result("root_indicator_detected", "root_indicator_not_detected")
    }

    private fun bootloader(): SignalResult {
        val value =
            AndroidSignalClassifier.bootloader(
                verifiedBootState = systemProperty("ro.boot.verifiedbootstate"),
                flashLocked = systemProperty("ro.boot.flash.locked"),
                vbmetaDeviceState = systemProperty("ro.boot.vbmeta.device_state"),
            )
        return value.result(
            "bootloader_unlocked",
            "bootloader_locked",
            "bootloader_state_unavailable",
        )
    }

    @Suppress("DEPRECATION")
    private fun signingCertificates(): Set<String> {
        val packageInfo =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES,
                )
            } else {
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.GET_SIGNATURES,
                )
            }
        val signatures =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val signingInfo = packageInfo.signingInfo ?: return emptySet()
                if (signingInfo.hasMultipleSigners()) {
                    signingInfo.apkContentsSigners
                } else {
                    signingInfo.signingCertificateHistory
                }
            } else {
                packageInfo.signatures
            }
        return signatures
            .orEmpty()
            .mapTo(mutableSetOf()) { signature ->
                normalizeCertificate(
                    MessageDigest.getInstance("SHA-256")
                        .digest(signature.toByteArray())
                        .joinToString("") { byte -> "%02X".format(byte) },
                )
            }
    }

    private fun systemProperty(name: String): String? =
        runCatching {
            val process =
                ProcessBuilder("/system/bin/getprop", name)
                .redirectErrorStream(true)
                .start()
            if (!process.waitFor(500, TimeUnit.MILLISECONDS)) {
                process.destroyForcibly()
                return@runCatching null
            }
            process.inputStream
                .bufferedReader()
                .use { it.readLine()?.trim()?.takeIf(String::isNotEmpty) }
        }.getOrNull()

    private fun safely(block: () -> SignalResult): Map<String, String> =
        runCatching(block)
            .getOrElse { SignalResult(CheckValue.INCONCLUSIVE, "detector_error") }
            .toMap()

    private fun normalizeCertificate(value: String): String =
        value.filter(Char::isLetterOrDigit).uppercase()
}

private data class SignalResult(val status: CheckValue, val reasonCode: String) {
    fun toMap(): Map<String, String> =
        mapOf("status" to status.wireValue, "reasonCode" to reasonCode)
}

private fun CheckValue.result(
    detectedReason: String,
    notDetectedReason: String,
    inconclusiveReason: String = "detector_inconclusive",
): SignalResult =
    when (this) {
        CheckValue.DETECTED -> SignalResult(this, detectedReason)
        CheckValue.NOT_DETECTED -> SignalResult(this, notDetectedReason)
        CheckValue.INCONCLUSIVE -> SignalResult(this, inconclusiveReason)
    }
