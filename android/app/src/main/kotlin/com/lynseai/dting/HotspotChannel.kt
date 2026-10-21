package com.lynseai.dting

import android.content.Context
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSuggestion
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Android 侧「手机连设备热点」通道（dting/hotspot），与 iOS 的
 * NEHotspotConfiguration 对位，供 Xyrix 音频外传快传使用。
 *
 * 为什么用 WifiNetworkSuggestion：Android 10(API 29) 起 App 侧
 * addNetwork()/WifiConfiguration 这条路被关掉，只剩「网络建议」这一种受支持的
 * 入网方式。副作用是系统可以要求用户在通知里确认一次，确认后同一 SSID 会被记住。
 *
 * 只建议、不动用户已保存的网络：绝不调用 removeAllNetworks 之类会毁掉用户
 * Wi-Fi 配置的 API。
 */
class HotspotChannel : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var appContext: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        appContext = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = appContext
        if (context == null) {
            result.error("not_attached", "插件未附着到引擎", null)
            return
        }
        val wifi = context.applicationContext
            .getSystemService(Context.WIFI_SERVICE) as? WifiManager
        if (wifi == null) {
            result.error("no_wifi_service", "无法取得 WifiManager", null)
            return
        }
        when (call.method) {
            "connect" -> {
                val ssid = call.argument<String>("ssid")
                if (ssid.isNullOrEmpty()) {
                    result.error("invalid_argument", "ssid 必填", null)
                    return
                }
                val password = call.argument<String>("password") ?: ""
                // 设备热点一般是 WPA2；口令为空按开放网络处理（不提口令字段）
                val builder = WifiNetworkSuggestion.Builder().setSsid(ssid)
                if (password.isNotEmpty()) builder.setWpa2Passphrase(password)
                val suggestion = builder.build()
                val status = try {
                    wifi.addNetworkSuggestions(listOf(suggestion))
                } catch (e: SecurityException) {
                    result.error("permission_denied", "缺少 CHANGE_WIFI_STATE: ${e.message}", null)
                    return
                } catch (e: Exception) {
                    result.error("add_failed", e.message ?: e.javaClass.simpleName, null)
                    return
                }
                Log.d(TAG, "addNetworkSuggestions ssid=$ssid status=$status")
                when (status) {
                    WifiManager.STATUS_NETWORK_SUGGESTIONS_SUCCESS,
                    // 同一 SSID 的建议已提交过：系统照常据此入网，等同成功
                    WifiManager.STATUS_NETWORK_SUGGESTIONS_ERROR_ADD_DUPLICATE -> {
                        suggestions += suggestion
                        result.success(mapOf("status" to status, "ssid" to ssid))
                    }
                    else -> result.error(
                        "add_failed",
                        "系统拒绝了热点建议（status=$status）。" +
                            "若手机通知栏出现「是否加入网络」提示，请点允许后重试",
                        mapOf("status" to status)
                    )
                }
            }
            "disconnect" -> {
                val ssid = call.argument<String>("ssid") ?: ""
                val mine = suggestions.filter { it.ssid?.trim('"') == ssid.trim('"') }
                val status = if (mine.isEmpty()) WifiManager.STATUS_NETWORK_SUGGESTIONS_SUCCESS
                else wifi.removeNetworkSuggestions(mine)
                suggestions.removeAll(mine)
                Log.d(TAG, "removeNetworkSuggestions ssid=$ssid status=$status")
                result.success(mapOf("status" to status))
            }
            // 探测/排查用：当前系统认为连着的 SSID（判断是否真的进了设备热点）
            "currentSsid" -> {
                @Suppress("DEPRECATION")
                val info = try {
                    wifi.connectionInfo
                } catch (e: SecurityException) {
                    result.error("permission_denied", "读 SSID 需要定位权限: ${e.message}", null)
                    return
                }
                // WifiInfo.getSsid() 的原样形态有两种：正常网络带首尾双引号
                // （"AP_xxx"），取不到时是 <unknown ssid>。两种包装都要剥掉，
                // 否则调用方拿它跟设备热点名比相等必然失败——2026-10-21 真机
                // 就因为这一个引号，把「手机已经在卡的 AP 上」判成了没连上。
                val raw = info?.ssid?.trim() ?: ""
                val ssid = raw.trim('"', '<', '>').trim()
                val linked = ssid.isNotEmpty() && !ssid.equals("unknown ssid", ignoreCase = true)
                result.success(mapOf("ssid" to ssid, "linked" to linked))
            }
            else -> result.notImplemented()
        }
    }

    private val suggestions = mutableListOf<WifiNetworkSuggestion>()

    companion object {
        private const val CHANNEL = "dting/hotspot"
        private const val TAG = "HotspotChannel"
    }
}
