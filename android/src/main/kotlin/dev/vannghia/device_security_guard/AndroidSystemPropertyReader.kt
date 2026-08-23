package dev.vannghia.device_security_guard

internal sealed interface SystemPropertyRead {
    data class Value(val value: String) : SystemPropertyRead

    data object Missing : SystemPropertyRead

    data object Error : SystemPropertyRead
}

internal fun interface PropertyProcessStarter {
    fun start(command: List<String>): PropertyProcess
}

internal interface PropertyProcess {
    fun exitCodeOrNull(): Int?

    fun readLine(): String?

    fun destroy()
}

internal class AndroidSystemPropertyReader(
    private val processStarter: PropertyProcessStarter =
        PropertyProcessStarter { command ->
            RuntimePropertyProcess(
                ProcessBuilder(command).redirectErrorStream(true).start(),
            )
        },
    private val timeoutMillis: Long = 500,
    private val nowNanos: () -> Long = System::nanoTime,
    private val sleeper: (Long) -> Unit = Thread::sleep,
) {
    fun read(name: String): SystemPropertyRead =
        try {
            readProcess(name)
        } catch (_: Exception) {
            SystemPropertyRead.Error
        }

    private fun readProcess(name: String): SystemPropertyRead {
        val process = processStarter.start(listOf("/system/bin/getprop", name))
        val deadline = nowNanos() + timeoutMillis * NANOS_PER_MILLISECOND
        while (true) {
            val exitCode = process.exitCodeOrNull()
            if (exitCode != null) {
                if (exitCode != 0) return SystemPropertyRead.Error
                val value = process.readLine()?.trim().orEmpty()
                return if (value.isEmpty()) {
                    SystemPropertyRead.Missing
                } else {
                    SystemPropertyRead.Value(value)
                }
            }
            if (nowNanos() >= deadline) {
                process.destroy()
                return SystemPropertyRead.Error
            }
            sleeper(POLL_INTERVAL_MILLIS)
        }
    }

    private companion object {
        const val POLL_INTERVAL_MILLIS = 10L
        const val NANOS_PER_MILLISECOND = 1_000_000L
    }
}

private class RuntimePropertyProcess(private val process: Process) : PropertyProcess {
    override fun exitCodeOrNull(): Int? =
        try {
            process.exitValue()
        } catch (_: IllegalThreadStateException) {
            null
        }

    override fun readLine(): String? =
        process.inputStream.bufferedReader().use { it.readLine() }

    override fun destroy() {
        process.destroy()
    }
}
