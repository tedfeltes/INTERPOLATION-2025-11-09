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
                when (call.method) {
                    "recoverLinework" -> {
                        val input = call.argument<String>("input")
                        val output = call.argument<String>("output")
                        if (input.isNullOrBlank() || output.isNullOrBlank()) {
                            result.error("bad_args", "input/output required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(callLinework("recover_linework", input, output))
                        } catch (e: Exception) {
                            result.error("recover_failed", e.message, null)
                        }
                    }
                    "listLayers" -> {
                        val input = call.argument<String>("input")
                        if (input.isNullOrBlank()) {
                            result.error("bad_args", "input required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val py = Python.getInstance()
                            val module = py.getModule("linework")
                            val recovered = module.callAttr("list_layers", input)
                            result.success(pyMapToFlutter(recovered.asMap()))
                        } catch (e: Exception) {
                            result.error("list_failed", e.message, null)
                        }
                    }
                    "filterLayers" -> {
                        val input = call.argument<String>("input")
                        val output = call.argument<String>("output")
                        val layersJson = call.argument<String>("layers_json")
                        if (input.isNullOrBlank() || output.isNullOrBlank() || layersJson.isNullOrBlank()) {
                            result.error("bad_args", "input/output/layers_json required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val py = Python.getInstance()
                            val module = py.getModule("linework")
                            val recovered = module.callAttr(
                                "filter_layers",
                                input,
                                output,
                                layersJson,
                            )
                            result.success(pyMapToFlutter(recovered.asMap()))
                        } catch (e: Exception) {
                            result.error("filter_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun callLinework(fn: String, input: String, output: String): HashMap<String, Any?> {
        val py = Python.getInstance()
        val module = py.getModule("linework")
        val recovered = module.callAttr(fn, input, output)
        return pyMapToFlutter(recovered.asMap())
    }

    private fun pyMapToFlutter(map: Map<*, *>): HashMap<String, Any?> {
        fun lookup(key: String): String? =
            map.entries.firstOrNull { it.key.toString() == key }
                ?.value?.toString()

        return hashMapOf(
            "stakeable_count" to (lookup("stakeable_count")?.toIntOrNull() ?: 0),
            "proxy_exploded" to (lookup("proxy_exploded")?.toIntOrNull() ?: 0),
            "proxy_primitives" to (lookup("proxy_primitives")?.toIntOrNull() ?: 0),
            "ok" to (lookup("ok")?.toBoolean() ?: false),
            "message" to (lookup("message") ?: ""),
            "layers_json" to (lookup("layers_json") ?: "[]"),
            "empty_layers_removed" to (lookup("empty_layers_removed")?.toIntOrNull() ?: 0),
        )
    }
}
