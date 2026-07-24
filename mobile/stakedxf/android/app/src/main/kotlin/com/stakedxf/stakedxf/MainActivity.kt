package com.stakedxf.stakedxf

import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

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
                        val json = JSONObject()
                        for ((key, value) in map) {
                            json.put(key.toString(), value?.toString())
                        }
                        // Prefer numeric fields as numbers where possible
                        val out = HashMap<String, Any?>()
                        out["stakeable_count"] =
                            map["stakeable_count"]?.toString()?.toIntOrNull() ?: 0
                        out["proxy_exploded"] =
                            map["proxy_exploded"]?.toString()?.toIntOrNull() ?: 0
                        out["proxy_primitives"] =
                            map["proxy_primitives"]?.toString()?.toIntOrNull() ?: 0
                        out["ok"] = map["ok"]?.toString()?.toBoolean() ?: false
                        out["message"] = map["message"]?.toString() ?: ""
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
