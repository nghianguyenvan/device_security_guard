package dev.vannghia.device_security_guard

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** DeviceSecurityGuardPlugin */
class DeviceSecurityGuardPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var detector: AndroidSecurityDetector? = null
    private var playIntegrityClient: PlayIntegrityClient? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        detector = AndroidSecurityDetector(flutterPluginBinding.applicationContext)
        playIntegrityClient = PlayIntegrityClient(flutterPluginBinding.applicationContext)
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
                val signals = detector?.assess(expectedCertificates)
                if (signals == null) {
                    result.error("not_attached", "Plugin is not attached to an engine", null)
                    return
                }
                result.success(
                    mapOf(
                        "schemaVersion" to 1,
                        "platform" to "android",
                        "operatingSystemVersion" to android.os.Build.VERSION.RELEASE,
                        "assessedAtEpochMs" to System.currentTimeMillis(),
                        "signals" to signals,
                    ),
                )
            }
            "requestPlayIntegrityToken" -> requestPlayIntegrityToken(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        detector = null
        playIntegrityClient = null
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
            onFailure = { error ->
                result.error("play_integrity_error", error.localizedMessage, null)
            },
        )
    }
}
