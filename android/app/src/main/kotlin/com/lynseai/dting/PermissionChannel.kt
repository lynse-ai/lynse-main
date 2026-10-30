package com.lynseai.dting

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 有限的系统权限请求通道。
 *
 * SDK 的 Android platform driver 只做 gate 检查（缺权限就抛 permissionDenied），
 * 不负责弹系统框；旧路径里这个动作是 flutter_blue_plus / 厂商 AAR 顺手做的。
 * 切到 SDK 后由这个通道在扫描/入网前显式请求。
 */
class PermissionChannel(
    private val activity: Activity,
    engine: FlutterEngine,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(
        engine.dartExecutor.binaryMessenger,
        "dting/permissions",
    )
    private var pending: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val permissions = when (call.method) {
            "requestBluetooth" -> bluetoothPermissions()
            "requestWifi" -> wifiPermissions()
            else -> {
                result.notImplemented()
                return
            }
        }
        val missing = permissions.filter {
            ContextCompat.checkSelfPermission(activity, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            result.success(true)
            return
        }
        if (pending != null) {
            result.error("permission_busy", "Another permission request is in flight.", null)
            return
        }
        pending = result
        ActivityCompat.requestPermissions(activity, missing.toTypedArray(), REQUEST_CODE)
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pending ?: return true
        pending = null
        result.success(grantResults.isNotEmpty() && grantResults.all {
            it == PackageManager.PERMISSION_GRANTED
        })
        return true
    }

    private fun bluetoothPermissions(): List<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            listOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            listOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }

    private fun wifiPermissions(): List<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ 只要这一条（前提：清单里不能带 neverForLocation，
            // 否则系统会隐去 SSID）。不要再顺手要 ACCESS_FINE_LOCATION：
            // ColorOS 会把它在 uid 级 appop 里置成 ignore，`pm grant` 都改不动，
            // 于是「缺一条就整句失败」，WiFi 快传永远进不去。
            listOf(Manifest.permission.NEARBY_WIFI_DEVICES)
        } else {
            listOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }

    private companion object {
        const val REQUEST_CODE = 0x61
    }
}
