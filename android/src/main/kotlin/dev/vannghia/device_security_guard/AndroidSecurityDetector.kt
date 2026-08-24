package dev.vannghia.device_security_guard

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Debug
import android.provider.Settings
import java.io.File
import java.security.MessageDigest

internal class AndroidSecurityDetector(
    private val context: Context,
    private val propertyReader: AndroidSystemPropertyReader = AndroidSystemPropertyReader(),
    private val signingCertificatesProvider: (() -> Set<String>)? = null,
) {
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

    private fun debugger(): SignalResult {
        val processStatus =
            File("/proc/self/status").takeIf(File::canRead)?.let { file ->
                runCatching(file::readText).getOrNull()
            }
        return AndroidSignalClassifier.debugger(
            javaDebuggerDetected = Debug.isDebuggerConnected() || Debug.waitingForDebugger(),
            processStatus = processStatus,
        ).result(
            "debugger_attached",
            "debugger_not_detected",
            "process_status_unavailable",
        )
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
                qemu = propertyReader.read("ro.kernel.qemu"),
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
                "org.lsposed.lspd.nativebridge.NativeAPI",
                "com.swift.sandhook.SandHook",
                "lab.galaxy.yahfa.HookMain",
            ).filter { className ->
                runCatching { Class.forName(className, false, context.classLoader) }.isSuccess
            }
        val value = AndroidSignalClassifier.hooking(maps, loadedFrameworks.toSet())
        return value.result(
            "hook_framework_detected",
            "hook_framework_not_detected",
            "process_maps_unavailable",
        )
    }

    internal fun repackaging(expectedCertificates: Set<String>): SignalResult {
        val expected = expectedCertificates.map(::normalizeCertificate).toSet()
        if (expected.isEmpty()) {
            return SignalResult(CheckValue.INCONCLUSIVE, "signing_certificate_unconfigured")
        }

        val actual = signingCertificatesProvider?.invoke() ?: signingCertificates()
        if (actual.isEmpty()) {
            return SignalResult(CheckValue.INCONCLUSIVE, "signing_certificate_unavailable")
        }
        val value = AndroidSignalClassifier.repackaging(actual, expected)
        return value.result(
            "signing_certificate_mismatch",
            "signing_certificate_match",
            "signing_certificate_unconfigured",
        )
    }

    private fun root(): SignalResult {
        val artifacts = AndroidSignalClassifier.existingRootArtifacts { File(it).exists() }
        val value =
            AndroidSignalClassifier.root(
                buildTags = Build.TAGS,
                existingArtifacts = artifacts,
                debuggable = propertyReader.read("ro.debuggable"),
                secure = propertyReader.read("ro.secure"),
            )
        return value.result("root_indicator_detected", "root_indicator_not_detected")
    }

    private fun bootloader(): SignalResult {
        val value =
            AndroidSignalClassifier.bootloader(
                verifiedBootState = propertyReader.read("ro.boot.verifiedbootstate"),
                flashLocked = propertyReader.read("ro.boot.flash.locked"),
                vbmetaDeviceState = propertyReader.read("ro.boot.vbmeta.device_state"),
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

    private fun safely(block: () -> SignalResult): Map<String, String> =
        runCatching(block)
            .getOrElse { SignalResult(CheckValue.INCONCLUSIVE, "detector_error") }
            .toMap()

    private fun normalizeCertificate(value: String): String =
        value.filter(Char::isLetterOrDigit).uppercase()
}

internal data class SignalResult(val status: CheckValue, val reasonCode: String) {
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
