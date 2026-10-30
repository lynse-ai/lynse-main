package com.lynseai.dting

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.lynseai.dting.nveasy.NvEasyPlugin

class MainActivity : FlutterActivity() {
    private var sdkConfigChannel: SdkConfigChannel? = null
    private var permissionChannel: PermissionChannel? = null
    private var wifiStateChannel: WifiStateChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(NvEasyPlugin(application, this))
        flutterEngine.plugins.add(HotspotChannel())
        // LYNSE Hardware SDK：配置通道负责用 AppKey/热点参数组装并注册 Pigeon Host。
        // 不添加 LynseHardwarePlugin，避免它用默认配置抢先注册一份 stack。
        sdkConfigChannel = SdkConfigChannel(applicationContext, flutterEngine)
        permissionChannel = PermissionChannel(this, flutterEngine)
        wifiStateChannel = WifiStateChannel(this, flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        permissionChannel?.onRequestPermissionsResult(requestCode, grantResults)
    }
}
