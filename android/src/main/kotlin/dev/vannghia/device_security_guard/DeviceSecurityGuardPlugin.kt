package dev.vannghia.device_security_guard

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** DeviceSecurityGuardPlugin */
class DeviceSecurityGuardPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var detector: AndroidSecurityDetector? = null
    private var playIntegrityClient: PlayIntegrityClient? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var detectorExecutor: ExecutorService? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        detector = AndroidSecurityDetector(flutterPluginBinding.applicationContext)
        playIntegrityClient = PlayIntegrityClient(flutterPluginBinding.applicationContext)
        detectorExecutor = Executors.newSingleThreadExecutor()
        channel =
            MethodChannel(
                flutterPluginBinding.binaryMessenger,
                "dev.vannghia/device_security_guard",
            )
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "assess" -> {
                val expectedCertificates =
                    call.argument<List<String>>("expectedAndroidCertificateSha256")
                        ?.toSet()
                        .orEmpty()
                val localDetector = detector
                val executor = detectorExecutor
                if (localDetector == null || executor == null) {
                    result.error("not_attached", "Plugin is not attached to an engine", null)
                    return
                }
                executor.execute {
                    val signals = localDetector.assess(expectedCertificates)
                    val payload =
                        mapOf(
                            "schemaVersion" to 1,
                            "platform" to "android",
                            "operatingSystemVersion" to android.os.Build.VERSION.RELEASE,
                            "assessedAtEpochMs" to System.currentTimeMillis(),
                            "signals" to signals,
                        )
                    mainHandler.post { result.success(payload) }
                }
            }
            "requestPlayIntegrityToken" -> requestPlayIntegrityToken(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        detector = null
        playIntegrityClient = null
        detectorExecutor?.shutdownNow()
        detectorExecutor = null
    }

    private fun requestPlayIntegrityToken(call: MethodCall, result: Result) {
        val cloudProjectNumber = call.argument<Number>("cloudProjectNumber")?.toLong()
        val requestHash = call.argument<String>("requestHash")
        val client = playIntegrityClient
        if (cloudProjectNumber == null || cloudProjectNumber <= 0 || requestHash.isNullOrBlank()) {
            result.error("invalid_arguments", "Cloud project number and request hash are required", null)
            return
        }
        if (client == null) {
            result.error("not_attached", "Plugin is not attached to an engine", null)
            return
        }
        client.requestToken(
            cloudProjectNumber = cloudProjectNumber,
            requestHash = requestHash,
            onSuccess = result::success,
            onFailure = { _ ->
                result.error("play_integrity_error", "Play Integrity request failed", null)
            },
        )
    }
}
