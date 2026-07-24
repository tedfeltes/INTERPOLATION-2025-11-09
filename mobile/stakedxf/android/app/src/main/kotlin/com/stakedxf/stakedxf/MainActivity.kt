package com.stakedxf.stakedxf

import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.stakedxf/linework"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "recoverLinework") {
                    val input = call.argument<String>("input")
                    val output = call.argument<String>("output")
                    if (input.isNullOrBlank() || output.isNullOrBlank()) {
                        result.error("bad_args", "input/output required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val py = Python.getInstance()
                        val module = py.getModule("linework")
                        val recovered = module.callAttr("recover_linework", input, output)
                        val map = recovered.asMap()

                        fun lookup(key: String): String? =
                            map.entries.firstOrNull { it.key.toString() == key }
                                ?.value?.toString()

                        val out = hashMapOf<String, Any?>(
                            "stakeable_count" to (lookup("stakeable_count")?.toIntOrNull() ?: 0),
                            "proxy_exploded" to (lookup("proxy_exploded")?.toIntOrNull() ?: 0),
                            "proxy_primitives" to (lookup("proxy_primitives")?.toIntOrNull() ?: 0),
                            "ok" to (lookup("ok")?.toBoolean() ?: false),
                            "message" to (lookup("message") ?: ""),
                        )
                        result.success(out)
                    } catch (e: Exception) {
                        result.error("recover_failed", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
