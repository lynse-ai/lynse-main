package com.lynseai.dting

import android.content.Context
import android.util.Log
import com.lynse.hardware.bridge.LynseHardwareBridgeRegistration
import com.lynse.hardware.catalog.LynseVendorCatalog
import com.lynse.hardware.catalog.LynseVendorRuntimeConfig
import com.lynse.hardware.catalog.LynseXyrixWifiConfig
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * App 自己的 SDK 配置入口。
 *
 * 厂商凭据（NewView AppKey、Xyrix 热点 SSID/口令）**不走 Pigeon**：
 * Pigeon 是给业务用的公共契约，凭据一旦进去就会出现在生成的 Dart/Swift/Kotlin
 * 类型和任何桥接日志里。这里用单独的 MethodChannel 把值直接交给 native stack，
 * 日志只留“收到了/长度”，不打印值。
 *
 * 必须在 `LynseHardware.initialize()` 之前调用 `configure`：它会用配置组装
 * `LynseVendorCatalog.stack`，并手工注册 Pigeon Host。
 */
class SdkConfigChannel(
    private val context: Context,
    private val engine: FlutterEngine,
) {
    private val channel = MethodChannel(
        engine.dartExecutor.binaryMessenger,
        "dting/hardware_sdk_config",
    )
    private var registration: LynseHardwareBridgeRegistration? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "configure" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    val appKey = (args["newViewAppKey"] as? String).orEmpty()
                    // 本轮没有厂商握手 Provider：无论上层传什么，都不伪造鉴权。
                    val requestedAuth = args["newViewRequiresAuthentication"] as? Boolean ?: false
                    val newViewWifiVerified = args["newViewWifiVerified"] as? Boolean ?: false
                    val xyrixWifiVerified = args["xyrixWifiVerified"] as? Boolean ?: false
                    val xyrixSsid = (args["xyrixWifiSsid"] as? String).orEmpty()
                    val xyrixPassword = (args["xyrixWifiPassword"] as? String).orEmpty()
                    val xyrixHost = (args["xyrixWifiHost"] as? String).orEmpty()
                    val xyrixPort = (args["xyrixWifiPort"] as? Number)?.toInt() ?: 0
                    val downloadDirectory = (args["downloadDirectory"] as? String).orEmpty()

                    val stack = LynseVendorCatalog.stack(
                        context = context,
                        // 见上：Provider 未实现，强制走已真机验通的免握手子集。
                        newViewAuthenticationProvider = null,
                        newViewRequiresAuthentication = false,
                        runtimeConfig = LynseVendorRuntimeConfig(
                            newViewWifiTransferVerified = newViewWifiVerified,
                            // 热点名由 SDK 按「AP_ + 当前卡 SN」现推，SSID 可以留空；
                            // 只要给了口令就认为 WiFi 快传配置齐全。
                            xyrixWifi = if (xyrixSsid.isNotEmpty() || xyrixPassword.isNotEmpty()) {
                                LynseXyrixWifiConfig(
                                    ssid = xyrixSsid,
                                    password = xyrixPassword,
                                    host = xyrixHost.ifEmpty { "192.168.1.80" },
                                    port = if (xyrixPort > 0) xyrixPort else 5000,
                                    verified = xyrixWifiVerified,
                                )
                            } else null,
                            destinationDirectory = downloadDirectory
                                .takeIf { it.isNotEmpty() }
                                ?.let(::File),
                        ),
                    )
                    registration = LynseHardwareBridgeRegistration(
                        binaryMessenger = engine.dartExecutor.binaryMessenger,
                        core = stack.core,
                        discovery = stack.discovery,
                    )
                    Log.i(
                        TAG,
                        "SDK configured: authRequested=$requestedAuth appKeyLen=${appKey.length} " +
                            "nvWifi=$newViewWifiVerified xyrixWifi=$xyrixWifiVerified " +
                            "ssidLen=${xyrixSsid.length} passLen=${xyrixPassword.length} " +
                            "hostSet=${xyrixHost.isNotEmpty()} port=$xyrixPort " +
                            "dir=${downloadDirectory.isNotEmpty()}",
                    )
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private companion object {
        const val TAG = "LynseHwConfig"
    }
}
