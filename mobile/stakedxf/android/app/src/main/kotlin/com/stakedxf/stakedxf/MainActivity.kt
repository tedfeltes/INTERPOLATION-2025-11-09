package com.stakedxf.stakedxf

import com.chaquo.python.PyObject
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "com.stakedxf/linework"
    private val progressChannelName = "com.stakedxf/convert_progress"
    private val worker = Executors.newSingleThreadExecutor { r ->
        Thread(r, "stakedxf-convert").apply { isDaemon = true }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, progressChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    ConvertProgressBus.attach(events)
                }

                override fun onCancel(arguments: Any?) {
                    ConvertProgressBus.attach(null)
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startConvertGuard" -> {
                        val message = call.argument<String>("message") ?: "Converting drawing…"
                        try {
                            ConvertForegroundService.start(applicationContext, message)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("fgs_start_failed", e.message, null)
                        }
                    }
                    "updateConvertGuard" -> {
                        val message = call.argument<String>("message") ?: "Converting…"
                        val percent = call.argument<Int>("percent") ?: -1
                        ConvertForegroundService.update(applicationContext, message, percent)
                        ConvertProgressBus.emit(
                            call.argument<String>("stage") ?: "convert",
                            percent,
                            message,
                        )
                        result.success(true)
                    }
                    "stopConvertGuard" -> {
                        try {
                            ConvertForegroundService.stop(applicationContext)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("fgs_stop_failed", e.message, null)
                        }
                    }
                    "recoverLinework" -> {
                        val input = call.argument<String>("input")
                        val output = call.argument<String>("output")
                        if (input.isNullOrBlank() || output.isNullOrBlank()) {
                            result.error("bad_args", "input/output required", null)
                            return@setMethodCallHandler
                        }
                        worker.execute {
                            try {
                                val recovered = callRecover(input, output)
                                runOnUiThread { result.success(recovered) }
                            } catch (e: Exception) {
                                // Soft-fail: never surface PlatformException(recover_failed)
                                // for Python AttributeError — Flutter shows the message instead.
                                ConvertProgressBus.emitError("recover_failed", e.message)
                                val soft = hashMapOf<String, Any?>(
                                    "stakeable_count" to 0,
                                    "proxy_exploded" to 0,
                                    "proxy_primitives" to 0,
                                    "ok" to false,
                                    "message" to "Recovery failed: ${e.message ?: e.javaClass.simpleName}",
                                    "layers_json" to "[]",
                                    "empty_layers_removed" to 0,
                                )
                                runOnUiThread { result.success(soft) }
                            }
                        }
                    }
                    "listLayers" -> {
                        val input = call.argument<String>("input")
                        if (input.isNullOrBlank()) {
                            result.error("bad_args", "input required", null)
                            return@setMethodCallHandler
                        }
                        worker.execute {
                            try {
                                ensurePython()
                                val module = Python.getInstance().getModule("linework")
                                val recovered = module.callAttr("list_layers", input)
                                val map = pyMapToFlutter(recovered.asMap())
                                runOnUiThread { result.success(map) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("list_failed", e.message, null)
                                }
                            }
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
                        worker.execute {
                            try {
                                ensurePython()
                                val module = Python.getInstance().getModule("linework")
                                val recovered = module.callAttr(
                                    "filter_layers",
                                    input,
                                    output,
                                    layersJson,
                                )
                                val map = pyMapToFlutter(recovered.asMap())
                                runOnUiThread { result.success(map) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("filter_failed", e.message, null)
                                }
                            }
                        }
                    }
                    "combineBaseDrawings" -> {
                        val inputsJson = call.argument<String>("inputs_json")
                        val output = call.argument<String>("output")
                        if (inputsJson.isNullOrBlank() || output.isNullOrBlank()) {
                            result.error("bad_args", "inputs_json/output required", null)
                            return@setMethodCallHandler
                        }
                        worker.execute {
                            try {
                                val combined = callCombineBase(inputsJson, output)
                                runOnUiThread { result.success(combined) }
                            } catch (e: Exception) {
                                ConvertProgressBus.emitError("combine_failed", e.message)
                                val soft = hashMapOf<String, Any?>(
                                    "stakeable_count" to 0,
                                    "proxy_exploded" to 0,
                                    "proxy_primitives" to 0,
                                    "ok" to false,
                                    "message" to "Base combine failed: ${e.message ?: e.javaClass.simpleName}",
                                    "error" to (e.message ?: e.javaClass.simpleName),
                                    "layers_json" to "[]",
                                    "empty_layers_removed" to 0,
                                    "source_count" to 0,
                                    "sources_merged" to 0,
                                )
                                runOnUiThread { result.success(soft) }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun ensurePython() {
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
        }
    }

    private fun callRecover(input: String, output: String): HashMap<String, Any?> {
        ensurePython()
        ConvertProgressBus.emit("recover", 35, "Recovering Civil 3D linework…")
        ConvertForegroundService.update(
            applicationContext,
            "Recovering Civil 3D linework…",
            35,
        )
        val py = Python.getInstance()
        val module = py.getModule("linework")
        val bridge = PythonProgressBridge { stage, percent, message ->
            ConvertProgressBus.emit(stage, percent, message)
            ConvertForegroundService.update(applicationContext, message, percent)
        }
        val recovered: PyObject = module.callAttr(
            "recover_linework",
            input,
            output,
            bridge,
        )
        val map = pyMapToFlutter(recovered.asMap())
        ConvertProgressBus.emit("recover", 95, "Writing Trimble DXF…")
        return map
    }

    private fun callCombineBase(inputsJson: String, output: String): HashMap<String, Any?> {
        ensurePython()
        ConvertProgressBus.emit("merge", 10, "Building base drawing…")
        ConvertForegroundService.update(
            applicationContext,
            "Building base drawing…",
            10,
        )
        val py = Python.getInstance()
        val module = py.getModule("linework")
        val bridge = PythonProgressBridge { stage, percent, message ->
            ConvertProgressBus.emit(stage, percent, message)
            ConvertForegroundService.update(applicationContext, message, percent)
        }
        val recovered: PyObject = module.callAttr(
            "combine_base_drawings",
            inputsJson,
            output,
            bridge,
        )
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
            "error" to (lookup("error") ?: ""),
            "layers_json" to (lookup("layers_json") ?: "[]"),
            "empty_layers_removed" to (lookup("empty_layers_removed")?.toIntOrNull() ?: 0),
            "source_count" to (lookup("source_count")?.toIntOrNull() ?: 0),
            "sources_merged" to (lookup("sources_merged")?.toIntOrNull() ?: 0),
            "sources_skipped" to (lookup("sources_skipped")?.toIntOrNull() ?: 0),
            "sources_json" to (lookup("sources_json") ?: "[]"),
        )
    }
}
