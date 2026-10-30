package com.lynseai.dting

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 快传引导用的小通道：判断手机是否已经在「设备热点」上、打开系统 WLAN 面板。
 *
 * 为什么不在 Dart 侧判断：`WifiInfo.getSSID()` 在 ColorOS 上被 uid 级 appop
 * 钉住（读出来恒为 `<unknown ssid>`），只能靠原生侧的“当前 WiFi 没有互联网校验”
 * 这个不需要权限的特征来判断——卡的热点正是这种，家里的 WiFi 有 VALIDATED。
 */
class WifiStateChannel(
    private val activity: Activity,
    engine: FlutterEngine,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(
        engine.dartExecutor.binaryMessenger,
        "dting/wifi_state",
    )

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isOnDeviceAccessPoint" -> result.success(isLikelyAccessPoint(activity))
            "currentSsid" -> result.success(currentSsid(activity))
            "openWifiPanel" -> {
                val intent = Intent(Settings.ACTION_WIFI_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                runCatching { activity.startActivity(intent) }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun isLikelyAccessPoint(context: Context): Boolean {
        val manager = context.getSystemService(ConnectivityManager::class.java) ?: return false
        val active = manager.activeNetwork ?: return false
        val caps = manager.getNetworkCapabilities(active) ?: return false
        return caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) &&
            !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }

    private fun currentSsid(context: Context): String? {
        val manager = context.getSystemService(WifiManager::class.java) ?: return null
        val info = runCatching { manager.connectionInfo }.getOrNull() ?: return null
        return info.ssid?.trim('"')
    }
}
