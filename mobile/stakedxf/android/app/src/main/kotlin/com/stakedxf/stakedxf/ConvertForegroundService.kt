package com.stakedxf.stakedxf

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * Keeps the process alive (wake lock + foreground notification) while
 * DWG→DXF conversion / Civil 3D recovery runs. Heavy work is owned by
 * [MainActivity]'s convert executor; this service is the Android keep-alive.
 */
class ConvertForegroundService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopProtecting()
                return START_NOT_STICKY
            }
            ACTION_UPDATE -> {
                val percent = intent.getIntExtra(EXTRA_PERCENT, -1)
                val message = intent.getStringExtra(EXTRA_MESSAGE) ?: "Converting…"
                updateNotification(message, percent)
                return START_STICKY
            }
            else -> {
                val message = intent?.getStringExtra(EXTRA_MESSAGE) ?: "Converting drawing…"
                startProtecting(message)
                return START_STICKY
            }
        }
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }

    private fun startProtecting(message: String) {
        ensureChannel()
        acquireWakeLock()
        val notification = buildNotification(message, percent = -1)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        active.set(true)
    }

    private fun stopProtecting() {
        active.set(false)
        releaseWakeLock()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun updateNotification(message: String, percent: Int) {
        if (!active.get()) return
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, buildNotification(message, percent))
    }

    private fun buildNotification(message: String, percent: Int): Notification {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pending = PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val title = if (percent in 0..100) {
            "Converting… $percent%"
        } else {
            "Converting drawing…"
        }
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentIntent(pending)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setPriority(NotificationCompat.PRIORITY_LOW)
        if (percent in 0..100) {
            builder.setProgress(100, percent, false)
        } else {
            builder.setProgress(0, 0, true)
        }
        return builder.build()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Drawing conversion",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps StakeDXF alive while converting large DWG files"
            setShowBadge(false)
        }
        nm.createNotificationChannel(channel)
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "StakeDXF:ConvertWakeLock",
        ).also {
            it.setReferenceCounted(false)
            it.acquire(4 * 60 * 60 * 1000L) // 4h safety cap
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {
        }
        wakeLock = null
    }

    companion object {
        const val ACTION_START = "com.stakedxf.stakedxf.CONVERT_START"
        const val ACTION_STOP = "com.stakedxf.stakedxf.CONVERT_STOP"
        const val ACTION_UPDATE = "com.stakedxf.stakedxf.CONVERT_UPDATE"
        const val EXTRA_MESSAGE = "message"
        const val EXTRA_PERCENT = "percent"
        private const val CHANNEL_ID = "stakedxf_convert"
        private const val NOTIFICATION_ID = 71001

        private val active = java.util.concurrent.atomic.AtomicBoolean(false)

        fun isActive(): Boolean = active.get()

        fun start(context: Context, message: String = "Converting drawing…") {
            val intent = Intent(context, ConvertForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_MESSAGE, message)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun update(context: Context, message: String, percent: Int) {
            if (!isActive()) return
            val intent = Intent(context, ConvertForegroundService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_MESSAGE, message)
                putExtra(EXTRA_PERCENT, percent)
            }
            context.startService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, ConvertForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }
}
