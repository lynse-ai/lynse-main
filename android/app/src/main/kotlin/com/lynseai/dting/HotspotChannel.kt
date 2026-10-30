package com.lynseai.dting

import android.content.Context
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiNetworkSpecifier
import android.net.wifi.WifiNetworkSuggestion
import android.os.Handler
import android.os.Looper
import java.io.ByteArrayOutputStream
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.atomic.AtomicBoolean
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
 * 入网方式。
 *
 * ⚠️ 但**别把它当成「会弹框让用户确认」**——2026-10-23 在这台 PLQ110(Android 16) 上
 * 实测就是没弹：`addNetworkSuggestions()` 返回 SUCCESS 只代表系统**收下**了建议，
 * 既没有对话框，也不保证系统会切过去（默认网络有网、建议网络没网时尤其不切）。
 * 之前这里写「系统可以要求用户在通知里确认一次」是错的口径，害得探测台
 * 一边让人「等弹框点确认」，一边把 `未连上（当前 Johney）` 当成设备不响应。
 *
 * 会**必定弹系统确认框**的是另一条 API：`WifiNetworkSpecifier` +
 * `ConnectivityManager.requestNetwork`，SDK 的
 * `platform-driver/.../LynseAndroidWifiDriver.kt` 用的就是它。代价是那条路的流量绑在
 * 返回的 `Network` 句柄上，Dart 侧的 `Socket` 绑不了 —— 所以真要在 App 内走快传，
 * TCP 也得放在原生侧做（这正是 SDK 把 WiFi 驱动放进 platform-driver 而不是 Adapter 的原因）。
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

            /**
             * 「App 自己连设备热点，并用这条网络去连设备的 TCP」。
             *
             * 为什么不是复用上面的 connect（WifiNetworkSuggestion）：建议式入网**不弹系统确认框**、
             * 也不保证切换，实测两次都停在「未连上（当前 Johney）」，于是快传的判据永远拿不到。
             * 会弹框的是 WifiNetworkSpecifier + requestNetwork；代价是这条流量绑在回调给的
             * [Network] 句柄上，Dart 的 Socket 绑不了 —— 所以 socket 必须在原生侧开
             * （这也正是 SDK 把 WiFi 驱动放在 platform-driver 的原因）。
             *
             * 顺手把矩阵第 14.3 节那个未决问题测掉：设备在这条 socket 上到底认哪种命令写法。
             */
            "joinAndProbe" -> {
                val ssid = call.argument<String>("ssid") ?: ""
                val password = call.argument<String>("password") ?: ""
                val host = call.argument<String>("host") ?: ""
                val port = (call.argument<Number>("port") ?: 0).toInt()
                if (ssid.isEmpty() || host.isEmpty() || port <= 0) {
                    result.error("invalid_argument", "ssid/host/port 必填", null)
                    return
                }
                val cm = context.applicationContext
                    .getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                if (cm == null) {
                    result.error("no_connectivity", "拿不到 ConnectivityManager", null)
                    return
                }
                val specifier = try {
                    WifiNetworkSpecifier.Builder().setSsid(ssid).setWpa2Passphrase(password).build()
                } catch (e: Exception) {
                    result.error("specifier_failed", e.message ?: e.javaClass.simpleName, null)
                    return
                }
                val request = NetworkRequest.Builder()
                    .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                    .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                    .setNetworkSpecifier(specifier)
                    .build()
                val main = Handler(Looper.getMainLooper())
                val replied = AtomicBoolean(false)
                val holder = arrayOfNulls<ConnectivityManager.NetworkCallback>(1)
                val callback = object : ConnectivityManager.NetworkCallback() {
                    private fun replyOnce(body: () -> Unit) {
                        if (replied.compareAndSet(false, true)) {
                            holder[0]?.let { runCatching { cm.unregisterNetworkCallback(it) } }
                            main.post(body)
                        }
                    }

                    override fun onAvailable(network: Network) {
                        val out = LinkedHashMap<String, Any?>()
                        out["joined"] = true
                        out["ssid"] = ssid
                        try {
                            val socket = network.socketFactory.createSocket() as Socket
                            socket.connect(InetSocketAddress(host, port), 6000)
                            socket.soTimeout = 4000
                            val sink = ByteArrayOutputStream()
                            val buf = ByteArray(2048)
                            // 先听设备主动推什么（真机 BLE 那侧见过 *DEV#filecmd#1# 反复播报）
                            runCatching { while (sink.size() < 256) sink.write(buf, 0, socket.inputStream.read(buf)) }
                            out["greeting"] = printable(sink.toByteArray())
                            // 再逐种写法试：拿到 *DEV#opusfile# 头帧或正文字节的那种，才是这条 socket 认的命令形状
                            val trials = ArrayList<Map<String, Any?>>()
                            for (cmd in listOf(
                                "opusfile#3#1#0#0#",
                                "*APP#opusfile#2#3#1#0#0#",
                                "filect#",
                                "filecmd#1#",
                            )) {
                                val one = LinkedHashMap<String, Any?>()
                                one["cmd"] = cmd
                                try {
                                    socket.outputStream.write(cmd.toByteArray())
                                    socket.outputStream.flush()
                                    val acc = ByteArrayOutputStream()
                                    val deadline = System.currentTimeMillis() + 5000
                                    while (System.currentTimeMillis() < deadline && acc.size() < 4096) {
                                        val n = runCatching { socket.inputStream.read(buf) }.getOrDefault(-1)
                                        if (n <= 0) break
                                        acc.write(buf, 0, n)
                                    }
                                    one["bytes"] = acc.size()
                                    one["head"] = printable(acc.toByteArray())
                                } catch (e: Exception) {
                                    one["error"] = e.message ?: e.javaClass.simpleName
                                }
                                trials.add(one)
                            }
                            out["trials"] = trials
                            runCatching { socket.close() }
                        } catch (e: Exception) {
                            out["error"] = e.message ?: e.javaClass.simpleName
                        }
                        replyOnce { result.success(out) }
                    }

                    override fun onUnavailable() {
                        replyOnce {
                            result.error(
                                "unavailable",
                                "系统没有加入该热点（多半是确认框被取消，或手机拒绝加入无网热点）",
                                null
                            )
                        }
                    }
                }
                holder[0] = callback
                cm.requestNetwork(request, callback)
                main.postDelayed({
                    if (!replied.get()) {
                        replied.set(true)
                        runCatching { cm.unregisterNetworkCallback(callback) }
                        result.error("timeout", "30 s 内没有 onAvailable（确认框有没有人点？）", null)
                    }
                }, 30_000)
            }

            @Suppress("UNUSED_EXPRESSION")
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

    /** 只保留可打印 ASCII，其余换成中间点，长度截到 160 —— 别把口令/正文原样写进日志。 */
    private fun printable(bytes: ByteArray): String =
        String(bytes, Charsets.ISO_8859_1).map { if (it in '\u0020'..'\u007e') it else '\u00b7' }
            .joinToString("").take(160)

    private val suggestions = mutableListOf<WifiNetworkSuggestion>()

    companion object {
        private const val CHANNEL = "dting/hotspot"
        private const val TAG = "HotspotChannel"
    }
}
