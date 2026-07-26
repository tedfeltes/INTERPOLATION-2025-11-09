package com.stakedxf.stakedxf

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.atomic.AtomicReference

/**
 * Bridges conversion progress / completion events from background workers
 * (and the foreground service) to a Flutter [EventChannel].
 */
object ConvertProgressBus {
    private val main = Handler(Looper.getMainLooper())
    private val sink = AtomicReference<EventChannel.EventSink?>(null)

    fun attach(events: EventChannel.EventSink?) {
        sink.set(events)
    }

    fun emit(stage: String, percent: Int, message: String) {
        val payload = hashMapOf<String, Any>(
            "type" to "progress",
            "stage" to stage,
            "percent" to percent.coerceIn(0, 100),
            "message" to message,
        )
        main.post {
            try {
                sink.get()?.success(payload)
            } catch (_: Exception) {
            }
        }
    }

    fun emitResult(result: Map<String, Any?>) {
        val payload = HashMap<String, Any?>(result)
        payload["type"] = "result"
        main.post {
            try {
                sink.get()?.success(payload)
            } catch (_: Exception) {
            }
        }
    }

    fun emitError(code: String, message: String?) {
        val payload = hashMapOf<String, Any>(
            "type" to "error",
            "code" to code,
            "message" to (message ?: "Conversion failed"),
        )
        main.post {
            try {
                sink.get()?.success(payload)
            } catch (_: Exception) {
            }
        }
    }
}
