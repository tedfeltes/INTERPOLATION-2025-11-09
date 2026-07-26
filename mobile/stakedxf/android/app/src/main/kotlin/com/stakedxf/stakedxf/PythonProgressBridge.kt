package com.stakedxf.stakedxf

/**
 * Plain (non-inner) bridge so Chaquopy can call [on_progress] from Python
 * without holding a hard Activity reference beyond the convert worker.
 */
class PythonProgressBridge(
    private val onProgress: (stage: String, percent: Int, message: String) -> Unit,
) {
    @Suppress("unused")
    fun on_progress(stage: String, percent: Int, message: String) {
        onProgress(stage, percent, message)
    }
}
