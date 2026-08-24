package dev.vannghia.device_security_guard

import android.content.Context
import org.mockito.Mockito.mock
import kotlin.test.Test
import kotlin.test.assertEquals

internal class AndroidSecurityDetectorTest {
    @Test
    fun unconfiguredCertificateCheckDoesNotReadSigningCertificates() {
        var certificateReads = 0
        val detector =
            AndroidSecurityDetector(
                context = mock(Context::class.java),
                signingCertificatesProvider = {
                    certificateReads += 1
                    setOf("AABB")
                },
            )

        val result = detector.repackaging(emptySet()).toMap()

        assertEquals(
            mapOf(
                "status" to "inconclusive",
                "reasonCode" to "signing_certificate_unconfigured",
            ),
            result,
        )
        assertEquals(0, certificateReads)
    }

    @Test
    fun configuredCertificateCheckReportsUnavailableActualCertificate() {
        val detector =
            AndroidSecurityDetector(
                context = mock(Context::class.java),
                signingCertificatesProvider = { emptySet() },
            )

        val result = detector.repackaging(setOf("AABB")).toMap()

        assertEquals(
            mapOf(
                "status" to "inconclusive",
                "reasonCode" to "signing_certificate_unavailable",
            ),
            result,
        )
    }

    @Test
    fun configuredCertificateCheckNormalizesExpectedCertificate() {
        val detector =
            AndroidSecurityDetector(
                context = mock(Context::class.java),
                signingCertificatesProvider = { setOf("AABB") },
            )

        val result = detector.repackaging(setOf("aa:bb")).toMap()

        assertEquals(
            mapOf(
                "status" to "notDetected",
                "reasonCode" to "signing_certificate_match",
            ),
            result,
        )
    }

    @Test
    fun assessmentAlwaysContainsEveryAndroidSignal() {
        val detector = AndroidSecurityDetector(context = mock(Context::class.java))

        val result = detector.assess(emptySet())

        assertEquals(
            setOf(
                "debugger",
                "emulator",
                "adbEnabled",
                "hooking",
                "repackaging",
                "root",
                "bootloaderUnlocked",
            ),
            result.keys,
        )
    }
}
