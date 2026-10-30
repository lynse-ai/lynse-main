package com.lynseai.dting

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * 录音卡传输链路的前台服务。
 *
 * 存在的理由：录音卡文件传输（BLE 通知流 / 设备热点 TCP 直传）动辄几分钟到
 * 几十分钟，而 App 一旦退到后台就可能被系统回收——届时断点虽然还在磁盘上，
 * 用户看到的却是「传输莫名停住」。前台服务 + PartialWakeLock 把进程和 CPU
 * 一起保住，让传输能跑完。
 *
 * 类型选择 connectedDevice + dataSync：前者对应蓝牙/WiFi 直连设备，后者对应
 * 文件同步，两者都是 Android 14 要求显式声明的子类型。不申请 microphone——
 * 本 App 的采集在卡片上完成，手机侧不录音。
 */
class TransferForegroundService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val label = intent?.getStringExtra(EXTRA_LABEL) ?: DEFAULT_LABEL
        startWithNotification(label)
        acquireWakeLock()
        // 进程被杀后不自动重启：链路与 GATT/socket 都已随进程消失，
        // 重启一个没有传输的前台服务只会留下悬空的常驻通知。
        // 下一次传输由 Dart 侧重新 start()。
        return START_NOT_STICKY
    }

    private fun startWithNotification(label: String) {
        createChannelIfNeeded()
        val notification = buildNotification(label)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        // LOW：不发声、不弹横幅，只在状态栏留一条进度提示
        val channel = NotificationChannel(
            CHANNEL_ID,
            "录音卡传输",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "录音卡文件传输进行中的进度提示"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(label: String): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        builder
            .setContentTitle("录音卡传输中")
            .setContentText(label)
            // Flutter 模板应用没有自带图标资源，沿用应用图标
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_PROGRESS)
        // 不静音的必要性已由 CHANNEL_ID 的 IMPORTANCE_LOW 承担：
        // setSilent() 是 API 31 才有的方法，minSdk 26 上直接调用会编译失败/崩溃
        // setForegroundServiceBehavior 是 API 29 才有的方法，minSdk 26 上
        // 无条件调用会在 8.x/9.x 真机抛 NoSuchMethodError
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        return builder.build()
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val manager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = manager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKE_LOCK_TAG).apply {
            setReferenceCounted(false)
            // 12 小时上限：宁可超时释放，也不要因为某条路径漏调 stop() 而永久耗电
            acquire(12 * 60 * 60 * 1000L)
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // 用户从最近任务划掉 App = 明确不再需要这条链路
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL_ID = "lynse_card_transfer"
        private const val NOTIFICATION_ID = 0x1C07
        private const val WAKE_LOCK_TAG = "lynse::card_transfer"
        private const val EXTRA_LABEL = "label"
        private const val DEFAULT_LABEL = "正在与录音卡同步文件"

        fun start(context: Context, label: String) {
            val intent = Intent(context, TransferForegroundService::class.java)
                .putExtra(EXTRA_LABEL, label)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                // 后台启动前台服务会被 Android 12+ 拒绝（ForegroundServiceStartNotAllowed）。
                // 保活失败不应让传输本身报错——传输照常进行，只是可能受省电策略影响。
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, TransferForegroundService::class.java))
        }
    }
}
