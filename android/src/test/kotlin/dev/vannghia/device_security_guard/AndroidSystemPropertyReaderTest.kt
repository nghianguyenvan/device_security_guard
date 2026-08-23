package dev.vannghia.device_security_guard

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

internal class AndroidSystemPropertyReaderTest {
    @Test
    fun successfulProcessReturnsValue() {
        val process = FakePropertyProcess(exitCode = 0, output = "green")
        val reader = reader(process)

        assertEquals(SystemPropertyRead.Value("green"), reader.read("ro.boot.verifiedbootstate"))
    }

    @Test
    fun emptySuccessfulProcessReturnsMissing() {
        val reader = reader(FakePropertyProcess(exitCode = 0, output = "  "))

        assertEquals(SystemPropertyRead.Missing, reader.read("ro.not.present"))
    }

    @Test
    fun nonZeroProcessReturnsError() {
        val reader = reader(FakePropertyProcess(exitCode = 1, output = null))

        assertEquals(SystemPropertyRead.Error, reader.read("ro.failure"))
    }

    @Test
    fun processStartFailureReturnsError() {
        val reader = AndroidSystemPropertyReader(
            processStarter = PropertyProcessStarter { error("cannot start") },
        )

        assertEquals(SystemPropertyRead.Error, reader.read("ro.failure"))
    }

    @Test
    fun timeoutDestroysProcessAndReturnsError() {
        val process = FakePropertyProcess(exitCode = null, output = null)
        val times = ArrayDeque(listOf(0L, 600_000_000L))
        val reader = AndroidSystemPropertyReader(
            processStarter = PropertyProcessStarter { process },
            nowNanos = { times.removeFirst() },
            sleeper = {},
        )

        assertEquals(SystemPropertyRead.Error, reader.read("ro.timeout"))
        assertTrue(process.destroyed)
    }

    private fun reader(process: FakePropertyProcess) =
        AndroidSystemPropertyReader(
            processStarter = PropertyProcessStarter { process },
            nowNanos = { 0L },
            sleeper = {},
        )
}

private class FakePropertyProcess(
    private val exitCode: Int?,
    private val output: String?,
) : PropertyProcess {
    var destroyed = false

    override fun exitCodeOrNull(): Int? = exitCode

    override fun readLine(): String? = output

    override fun destroy() {
        destroyed = true
    }
}
