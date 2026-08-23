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

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        detector = AndroidSecurityDetector(flutterPluginBinding.applicationContext)
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
                        "signals" to signals,
                    ),
                )
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        detector = null
    }
}
