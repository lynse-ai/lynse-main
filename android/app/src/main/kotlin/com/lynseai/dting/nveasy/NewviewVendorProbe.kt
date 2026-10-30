package com.lynseai.dting.nveasy

import android.app.Application
import android.bluetooth.BluetoothGatt
import android.util.Log
import com.nveasy.ble.NvEasyBleManager
import com.nveasy.ble.callback.NvEasyBleCallback
import com.nveasy.ble.callback.NvEasyBleConnectCallback
import com.nveasy.ble.callback.NvEasyBleFilesCallback
import com.nveasy.ble.callback.NvEasyBleScanCallback
import com.nveasy.ble.data.ErrorType
import com.nveasy.ble.data.NvEasyBleDevice
import com.nveasy.ble.data.NvEasyDownloadFile
import com.nveasy.ble.data.NvEasyFile
import com.nveasy.ble.data.NvEasyOpusFormat
import com.nveasy.ble.exception.BleException
import com.nveasy.ble.exception.FilesReceiverException
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Newview 厂商参考实现探测台（NvEasyBle v1.2.0）。
 *
 * 为什么要它：我们自己的裸协议客户端把 `*APP#version#` 这类命令原样发出去，
 * 设备一个字都不回；而厂商 AAR 在建链时会做 `appkey/sdkkey/algkey/ostype/rtc`
 * 握手，其中 sdkkey 的载荷由 `libnveasysdk.so` 的 `Auth.encrypt()` 生成，
 * 我们拿不到密钥也就无法复刻。所以「这张卡到底有哪些接口是活的」这个问题，
 * 唯一可信的裁判是厂商 SDK 本身。
 *
 * 判读规则（写在产出里，不靠记忆）：
 *  - 厂商拿到回调而我们拿不到 → 我们协议层缺动作，继续挖；
 *  - 厂商也拿不到 → 设备状态/固件问题，改协议就是白改；
 *  - 每个接口单独计时，沉默记 TIMEOUT、明确失败记 FAIL，两者不混。
 *
 * 安全边界：不可逆与工厂类接口（formatDeviceStorage / factoryMode / devpair /
 * bound / unbound / 写名称 / 写 offtime / 写 micgain / OTA / 删文件）
 * 默认**不发**，需要计划文件显式开闸。
 */
object NewviewVendorProbe {

    private const val TAG = "NVV"
    private const val QUERY_TIMEOUT_MS = 6_000L
    private const val SCAN_MS = 12_000L
    private const val WIFI_TIMEOUT_MS = 90_000L

    private data class Hit(val name: String, val detail: String)

    private val mgr: NvEasyBleManager get() = NvEasyBleManager.getInstance()
    private val inbox = Channel<Hit>(Channel.UNLIMITED)

    private var scope: CoroutineScope? = null
    private var job: Job? = null
    private var device: NvEasyBleDevice? = null
    private var dir: File? = null
    private var reportFile: File? = null
    private var streamFile: FileOutputStream? = null
    private var streamBytes = 0L
    private var streamFrames = 0
    private var downloadBytes = 0L
    private var running = false
    private val verdicts = ArrayList<String>()
    private var lastFileList: List<NvEasyFile> = emptyList()

    val isRunning: Boolean get() = running

    // ───────────────────────── 回调面 ─────────────────────────
    //
    // 每个回调都走 hit()：既唤醒当前步骤，也无条件落盘一行，
    // 于是「设备主动上报」（incharge/switch/mem 这类不用我们发命令的）同样被记录。

    private fun hit(h: Hit) {
        line("  ← ${h.name} ${h.detail}")
        inbox.trySend(h)
    }

    /** 丢弃上一条命令遗留的命中，避免拿旧回包冒充新结果 */
    private fun drain() {
        while (true) {
            val r = inbox.tryReceive()
            if (!r.isSuccess) break
        }
    }

    private suspend fun awaitHit(timeoutMs: Long, vararg prefixes: String): Hit? =
        withTimeoutOrNull(timeoutMs) {
            while (true) {
                val h = inbox.receive()
                if (prefixes.isEmpty() || prefixes.any { p -> h.name.startsWith(p) }) return@withTimeoutOrNull h
            }
            @Suppress("UNREACHABLE_CODE") null
        }

    private val bleCallback = object : NvEasyBleCallback() {
        override fun onBlePrepared() = hit(Hit("onBlePrepared", "服务就绪"))
        override fun onBleFailed(t: ErrorType?) = hit(Hit("onBleFailed", "$t"))
        override fun onCommandFailed(cmd: String?) = hit(Hit("onCommandFailed", "$cmd"))

        override fun onStream(data: ByteArray?, frameLen: Int, totalLen: Int) {
            streamFrames += if (frameLen > 0) totalLen / frameLen else 0
            streamBytes += totalLen
            try { streamFile?.write(data ?: ByteArray(0)) } catch (_: Exception) {}
            hit(Hit("onStream", "frame=$frameLen total=$totalLen acc=${streamBytes}B/${streamFrames}帧"))
        }

        override fun onUpdateBattery(l: Int, r: Int, house: Int) = hit(Hit("onUpdateBattery", "L=$l R=$r case=$house"))
        override fun onQueryVersion(sw: String?, hw: String?) = hit(Hit("onQueryVersion", "sw=$sw hw=$hw"))
        override fun onRecord(s: Int, m: Int, sr: Int, ch: Int, rm: Int, t: Int) =
            hit(Hit("onRecord", "status=$s mode=$m rate=$sr ch=$ch recMode=$rm time=$t"))

        override fun onRecordWithSN(s: Int, m: Int, sr: Int, ch: Int, rm: Int, t: Int, sn: Int, name: String?) =
            hit(Hit("onRecordWithSN", "status=$s mode=$m rate=$sr ch=$ch recMode=$rm time=$t sn=$sn name=$name"))

        override fun onRecordExtended(s: Int, m: Int, fmt: NvEasyOpusFormat?, rm: Int, t: Int, sn: Int, name: String?) {
            // 刚开始录时设备才把这条录音的身份报出来，后面闭环对比全靠它
            if (s == 1 && sn > 0) { recordedSn = sn; recordedName = name }
            hit(Hit("onRecordExtended", "status=$s mode=$m fmt=$fmt recMode=$rm time=$t sn=$sn name=$name"))
        }

        override fun onDeviceRecord(s: Int, m: Int, ai: Int) = hit(Hit("onDeviceRecord", "status=$s mode=$m aiMode=$ai"))
        override fun onSwitch(mode: Int) = hit(Hit("onSwitch", "mode=$mode"))
        override fun onCall(s: Int, n: String?) = hit(Hit("onCall", "status=$s number=$n"))
        override fun onEDR(s: Int, mac: String?, name: String?) = hit(Hit("onEDR", "status=$s mac=$mac name=$name"))

        override fun onReadDeviceInfo(
            role: String?, le: String?, re: String?, caseMac: String?, auth: String?, label: String?, wifi: String?
        ) = hit(Hit("onReadDeviceInfo", "role=$role L=$le R=$re case=$caseMac authSN=$auth labelSN=$label wifiMac=$wifi"))

        override fun onDeviceStorage(free: Long, total: Long) = hit(Hit("onDeviceStorage", "free=$free total=$total KB"))
        override fun onDeviceStorage(lf: Long, lt: Long, rf: Long, rt: Long) =
            hit(Hit("onDeviceStorage", "L free=$lf tot=$lt / R free=$rf tot=$rt KB"))

        override fun onFormatStorage(ok: Boolean, free: Long, total: Long) =
            hit(Hit("onFormatStorage", "ok=$ok free=$free total=$total"))

        override fun onAuthSN(auth: String?, bleMac: String?, wifiMac: String?, label: String?) =
            hit(Hit("onAuthSN", "authSN=$auth bleMac=$bleMac wifiMac=$wifiMac labelSN=$label"))

        override fun onBleName(ok: Boolean, name: String?) = hit(Hit("onBleName", "ok=$ok name=$name"))
        override fun onBluetoothName(ok: Boolean, name: String?) = hit(Hit("onBluetoothName", "ok=$ok name=$name"))
        override fun onOffTime(ok: Boolean, v: Int) = hit(Hit("onOffTime", "ok=$ok min=$v"))
        override fun onMicGain(ok: Boolean, mode: Int, m1: Int, m2: Int) =
            hit(Hit("onMicGain", "ok=$ok mode=$mode mic1=$m1 mic2=$m2"))

        override fun onChargeStatus(s: Int, l: Int, r: Int, house: Int) =
            hit(Hit("onChargeStatus", "status=$s L=$l R=$r case=$house"))

        override fun onFlashNote(s: Int, sn: Int, name: String?, fmt: NvEasyOpusFormat?) =
            hit(Hit("onFlashNote", "status=$s sn=$sn name=$name fmt=$fmt"))

        override fun onRecordMark(s: Int, sn: Int, name: String?, idx: Int, off: Int, src: Int) =
            hit(Hit("onRecordMark", "status=$s sn=$sn name=$name index=$idx offset=$off source=$src"))

        override fun onBound(ok: Boolean, bound: Boolean) = hit(Hit("onBound", "ok=$ok isBound=$bound"))
        override fun onUnbound(ok: Boolean) = hit(Hit("onUnbound", "ok=$ok"))
        override fun onPair(ok: Boolean) = hit(Hit("onPair", "ok=$ok"))
        override fun onFactory(ok: Boolean) = hit(Hit("onFactory", "ok=$ok"))
        override fun onCustom(cmd: String?, v: String?) = hit(Hit("onCustom", "cmd=$cmd value=$v"))
        override fun onEarPhoneBleStatus(lm: Boolean, ls: Boolean, rs: Boolean) =
            hit(Hit("onEarPhoneBleStatus", "leftMaster=$lm left=$ls right=$rs"))
    }

    private val filesCallback = object : NvEasyBleFilesCallback {
        override fun onFilesList(list: MutableList<NvEasyFile>?) {
            lastFileList = list ?: emptyList()
            val brief = lastFileList.take(6).joinToString(" ; ") {
                "sn=${it.sn} ${it.name} ${it.size}B scene=${it.scene} fmt=${it.opusFormat} marks=${it.recordMarks?.size ?: 0}"
            }
            hit(Hit("onFilesList", "n=${lastFileList.size} [$brief]"))
        }

        override fun onFileStream(ble: Boolean, sn: Int, total: Int, current: Int, data: ByteArray?) {
            downloadBytes += (data?.size ?: 0)
            // 必须落盘：光在内存里数长度，就只能证明「收够了字节数」，
            // 证不了「收到的内容和卡上存的是同一份」。哈希对比才是那条硬判据。
            try {
                if (current == 1) {
                    line("  下载开始 sn=$sn packets=$total → ${downloadPath(sn)}")
                    downloadOut = FileOutputStream(downloadPath(sn))
                }
                data?.let { downloadOut?.write(it) }
                if (current == total) {
                    downloadOut?.flush(); downloadOut?.close(); downloadOut = null
                    hit(Hit("onFileStreamDONE", "sn=$sn bytes=$downloadBytes ble=$ble sha=${sha256(downloadPath(sn))}"))
                } else if (current % 25 == 0) {
                    hit(Hit("onFileStream", "sn=$sn $current/$total acc=$downloadBytes"))
                }
            } catch (e: Exception) {
                line("  下载落盘异常 ${e.javaClass.simpleName}: ${e.message}")
            }
        }

        override fun onWifiStatus(st: NvEasyBleFilesCallback.WifiStatus?) = hit(Hit("onWifiStatus", "$st"))

        override fun onWifiOpened(
            ip: String?, port: Int, cip: String?, cport: Int, ssid: String?, pwd: String?
        ) = hit(Hit("onWifiOpened", "server=$ip:$port client=$cip:$cport ssid=$ssid pwd=$pwd"))

        override fun onFinished(list: MutableList<NvEasyFile>?) =
            hit(Hit("onFinished", "n=${list?.size ?: -1} bytes=$downloadBytes"))

        override fun onDeleteFile(ok: Boolean, sn: Int, name: String?) =
            hit(Hit("onDeleteFile", "ok=$ok sn=$sn name=$name"))

        override fun onException(e: FilesReceiverException?) =
            hit(Hit("onException", "${e?.javaClass?.simpleName} type=${e?.getType()} ${e?.getDescription()}"))
    }

    private var downloadOut: FileOutputStream? = null
    private fun downloadPath(sn: Int) = File(dir, "vendor_dl_sn$sn.opus").absolutePath

    /**
     * 本轮实时采音的身份。闭环对比**必须按 sn 认文件**：
     * 上一版按「文件长度相同」配对，结果两轮扫档的录音时长一样（探测台每步 sleep 固定），
     * 于是拿「上一轮的录音」和「这一轮的采音」比，报出一个**假的 FAIL**。
     */
    private var recordedSn = 0
    private var recordedName: String? = null
    private var rtPath: String? = null

    private fun sha256(path: String): String {
        return try {
            val md = java.security.MessageDigest.getInstance("SHA-256")
            File(path).inputStream().use { ins ->
                val buf = ByteArray(8192)
                while (true) { val n = ins.read(buf); if (n <= 0) break; md.update(buf, 0, n) }
            }
            md.digest().joinToString("") { "%02x".format(it) }
        } catch (e: Exception) {
            "算不出(${e.javaClass.simpleName})"
        }
    }

    /**
     * 闭环判据：**只有下载的就是本轮刚采音那一条**（sn 必须等于 [recordedSn]）才算数。
     * 上一版按「文件长度相同」配对，而两轮扫档的录音时长一样（探测台每步 sleep 固定秒数），
     * 于是拿「上一轮的录音」和「这一轮的采音」互比，报出一个**假 FAIL**——
     * 判据必须认身份（sn），不能认尺寸。
     */
    private fun crossCheckDownloaded(sn: Int, expectedBytes: Long) {
        val dl = File(downloadPath(sn))
        if (!dl.exists()) { verdict("下载落盘长度", "SKIP", "没有落盘文件"); return }
        verdict(
            "下载落盘长度", if (dl.length() == expectedBytes) "OK" else "FAIL",
            "sn=$sn 回调计数=$expectedBytes 落盘=${dl.length()} sha256=${sha256(dl.absolutePath).take(16)}…"
        )
        val rt = rtPath?.let { File(it) }
        if (sn != recordedSn || rt == null || !rt.exists()) {
            verdict(
                "实时流↔下载闭环", "SKIP",
                "下载的不是本轮采音那一条（下载 sn=$sn / 本轮采音 sn=$recordedSn / rt=${rt?.name ?: "无"}）"
            )
            return
        }
        if (sha256(rt.absolutePath) == sha256(dl.absolutePath)) {
            verdict("实时流↔下载闭环", "OK", "${rt.name} 与 ${dl.name} ${dl.length()}B 逐字节相同")
        } else {
            val a = rt.readBytes(); val b = dl.readBytes()
            val n = minOf(a.size, b.size)
            var at = -1; var count = 0
            for (i in 0 until n) if (a[i] != b[i]) { if (at < 0) at = i; count++ }
            verdict(
                "实时流↔下载闭环", "FAIL",
                "同一条录音（sn=$sn ${recordedName ?: ""}）两条通路字节不同：比较 ${n}B、首个差异偏移 $at、差异 $count 个字节"
            )
        }
    }

    // ───────────────────────── 驱动 ─────────────────────────

    fun start(
        app: Application,
        nameHint: String?,
        appKey: String?,
        includeRecord: Boolean,
        includeWifi: Boolean,
        includeDelete: Boolean,
        macHint: String? = null,
        advHex: String? = null
    ): String {
        if (running) return "already running"
        running = true
        downloadBytes = 0; streamBytes = 0; streamFrames = 0
        verdicts.clear(); lastFileList = emptyList()
        drain()
        dir = app.getExternalFilesDir(null) ?: app.filesDir
        reportFile = File(dir, "newview_vendor_report.txt")
        reportFile?.appendText("\n===== 厂商 AAR 扫档 ${ts()} name=$nameHint appkey=${if (appKey.isNullOrEmpty()) "无" else "len" + appKey.length} rec=$includeRecord wifi=$includeWifi del=$includeDelete =====\n")
        // v1.2.0 的 init 必须带 appKey；缺 key 的握手会被设备侧拒掉。
        mgr.init(app, appKey ?: "")
        line("SDK ${NvEasyBleManager.getVersion()} · init(appKey=${if (appKey.isNullOrEmpty()) "空" else "已配"})")
        val s = CoroutineScope(Dispatchers.Main)
        scope = s
        job = s.launch { runAll(nameHint, includeRecord, includeWifi, includeDelete, macHint, advHex) }
        return "started"
    }

    private suspend fun runAll(
        nameHint: String?, rec: Boolean, wifi: Boolean, del: Boolean,
        macHint: String?, advHex: String?
    ) {
        try {
            val dev = scanAndConnect(nameHint, macHint, advHex) ?: run {
                verdict("扫描+连接", "FAIL", "厂商扫描器未见目标（射频/电源/被别的手机占用）"); return
            }
            device = dev
            mgr.setFilesCallback(dev, filesCallback)
            abilities(dev)
            infoRound()
            if (rec) recordingRound()
            filesRound(del)
            if (wifi) wifiRound()
        } catch (e: Exception) {
            line("异常 ${e.javaClass.simpleName}: ${e.message}")
        } finally {
            try { streamFile?.close() } catch (_: Exception) {}
            streamFile = null
            summary()
            running = false
            scope?.cancel(); scope = null
        }
    }

    private suspend fun scanAndConnect(
        nameHint: String?, macHint: String?, advHex: String?
    ): NvEasyBleDevice? {
        val found = ArrayList<NvEasyBleDevice>()
        val cb = object : NvEasyBleScanCallback {
            override fun onScanStarted(ok: Boolean) = hit(Hit("onScanStarted", "ok=$ok"))
            override fun onScanning(d: NvEasyBleDevice?) {
                d ?: return
                found.add(d)
                line("  扫到 ${d.getLocalName()} ${d.getMac()} idMark=${d.getIdMark()} proto=${d.getProtocolVersion()}")
            }
            override fun onScanFinished(list: MutableList<NvEasyBleDevice>?) =
                hit(Hit("onScanFinished", "n=${list?.size ?: -1}"))
        }
        drain()
        mgr.scan(SCAN_MS.toInt(), cb)
        delay(SCAN_MS + 1_500)
        mgr.stopScan()
        var target = found.firstOrNull { nameHint != null && it.getLocalName()?.contains(nameHint, true) == true }
            ?: found.firstOrNull { !it.getIdMark().isNullOrEmpty() }
            ?: found.firstOrNull()
        if (target == null && !macHint.isNullOrEmpty()) {
            // 厂商扫描器 0 台是**预期的**，别急着判「设备不在」：这块卡的 idMark 是
            // "ilynse"、广播里不带 NvEasy 字面标记（L1 实测 payload 以 "L1NV" 结尾），
            // 厂商自己的过滤把它挡在外面。兜底走公开 API
            // checkDevice(mac, localName, manufactureData)——拿裸客户端已经抓到的
            // 广播原文自己造一个 NvEasyBleDevice 句柄，再把连接交给厂商 SDK。
            line("厂商扫描器 0 台 → 改用 checkDevice($macHint) 兜底")
            target = try {
                val bytes = advHex?.replace(" ", "")?.chunked(2)?.map { it.toInt(16).toByte() }?.toByteArray()
                    ?: ByteArray(0)
                mgr.checkDevice(macHint, nameHint ?: "", bytes)
            } catch (e: Exception) {
                line("checkDevice 抛 ${e.javaClass.simpleName}: ${e.message}")
                null
            }
        }
        verdict(
            "发现设备句柄", if (target != null) "OK" else "FAIL",
            "厂商扫描器 ${found.size} 台 + checkDevice 兜底"
        )
        target ?: return null
        line("选中 ${target.getLocalName()} ${target.getMac()}")

        var success: NvEasyBleDevice? = null
        val connCb = object : NvEasyBleConnectCallback {
            override fun onStartConnect(d: NvEasyBleDevice?) = hit(Hit("onStartConnect", "${d?.getLocalName()}"))
            override fun onConnectFail(d: NvEasyBleDevice?, e: BleException?) =
                hit(Hit("onConnectFail", "code=${e?.getCode()} ${e?.getDescription()}"))

            override fun onConnectSuccess(d: NvEasyBleDevice?, g: BluetoothGatt?, st: Int) {
                success = d; hit(Hit("onConnectSuccess", "status=$st proto=${d?.getProtocolVersion()}"))
            }

            override fun onDisConnected(active: Boolean, d: NvEasyBleDevice?, g: BluetoothGatt?, st: Int) =
                hit(Hit("onDisConnected", "active=$active status=$st"))
        }
        drain()
        mgr.connect(target, connCb, bleCallback)
        val ok = awaitHit(25_000, "onConnectSuccess")
        if (ok == null) {
            val fail = awaitHit(1, "onConnectFail")
            verdict("GATT 连接", "FAIL", fail?.detail ?: "25s 无 onConnectSuccess")
            return null
        }
        verdict("GATT 连接", "OK", ok.detail)
        line("等 onBlePrepared（服务发现 + notify + MTU + 鉴权握手）")
        val prepared = awaitHit(25_000, "onBlePrepared")
        verdict(
            "鉴权链路(onBlePrepared)", if (prepared != null) "OK" else "FAIL",
            if (prepared != null) "厂商握手完成、可以下命令" else "25s 内没就绪——鉴权没过去"
        )
        return success ?: target
    }

    private fun abilities(dev: NvEasyBleDevice) {
        val table = listOf(
            17 to "RECORD_PAUSE_RESUME", 18 to "RECORD_MARK", 19 to "FLASH_NOTE", 20 to "NETWORK",
            21 to "CHILD_PARENT", 22 to "WIFI_V2", 23 to "BUDS_1V1", 24 to "MEDIA_RECORD",
            25 to "RTC", 26 to "BLUETOOTH", 27 to "MEETING_NC", 28 to "CALL_RECORD",
            29 to "MEETING_RECORD", 30 to "WIFI", 31 to "STORAGE"
        )
        val has = table.filter { try { dev.hasAbility(it.first) } catch (e: Exception) { false } }
        verdict(
            "能力位/身份", "OK",
            "proto=${dev.getProtocolVersion()} idMark=${dev.getIdMark()} sku=${dev.getSKU()} " +
                "name=${dev.getLocalName()} type=${dev.getDeviceType()} abilities=[" +
                has.joinToString(",") { it.second } + "]"
        )
    }

    private suspend fun query(label: String, issue: () -> Unit, vararg cbNames: String) {
        drain()
        issue()
        val h = awaitHit(QUERY_TIMEOUT_MS, *cbNames)
        verdict(label, if (h != null) "OK" else "TIMEOUT", h?.let { "${it.name} ${it.detail}" } ?: "无回包")
    }

    private suspend fun infoRound() {
        val d = device ?: return
        line("── 设备信息档 ──")
        query("queryVersion", { mgr.queryVersion(d) }, "onQueryVersion")
        query("queryBattery", { mgr.queryBattery(d) }, "onUpdateBattery")
        query("queryDeviceStorage", { mgr.queryDeviceStorage(d) }, "onDeviceStorage")
        query("queryAuthSN", { mgr.queryAuthSN(d) }, "onAuthSN")
        query("readDeviceInfo", { mgr.readDeviceInfo(d) }, "onReadDeviceInfo")
        query("querySwitch", { mgr.querySwitch(d) }, "onSwitch")
        query("queryEdr", { mgr.queryEdr(d) }, "onEDR")
        query("queryCall", { mgr.queryCall(d) }, "onCall")
        query("queryChargeStatus", { mgr.queryChargeStatus(d) }, "onChargeStatus")
        query("queryBleName", { mgr.queryBleName(d) }, "onBleName")
        query("queryBluetoothName", { mgr.queryBluetoothName(d) }, "onBluetoothName")
        query("queryOffTime", { mgr.queryOffTime(d) }, "onOffTime")
        query("queryMicGain(会议)", { mgr.queryMicGain(d, 0) }, "onMicGain")
        query("queryMicGain(通话)", { mgr.queryMicGain(d, 1) }, "onMicGain")
        query("setActive 心跳", { mgr.setActive(d) }, "onActive", "onCommandFailed")
    }

    private suspend fun recordingRound() {
        val d = device ?: return
        line("── 录音控制档（会议模式 mode=0）──")
        val rtFile = File(dir, "vendor_rt_${stamp()}.opus")
        rtPath = rtFile.absolutePath
        streamFile = FileOutputStream(rtFile)
        query("record start(1,0)", { mgr.record(d, 1, 0) }, "onRecord", "onRecordWithSN", "onRecordExtended")
        delay(4_000)
        query("recordMark 打点", { mgr.recordMark(d) }, "onRecordMark")
        query("record pause(2,0)", { mgr.record(d, 2, 0) }, "onRecord", "onRecordExtended")
        delay(2_000)
        query("record resume(3,0)", { mgr.record(d, 3, 0) }, "onRecord", "onRecordExtended")
        delay(3_000)
        query("flashNote start", { mgr.flashNote(d, 1) }, "onFlashNote")
        query("flashNote stop", { mgr.flashNote(d, 0) }, "onFlashNote")
        query("record stop(0,0)", { mgr.record(d, 0, 0) }, "onRecord", "onRecordExtended")
        try { streamFile?.flush(); streamFile?.close() } catch (_: Exception) {}
        streamFile = null
        verdict(
            "实时流 onStream", if (streamBytes > 0) "OK" else "TIMEOUT",
            "$streamBytes B / $streamFrames 帧 → ${rtFile.absolutePath}"
        )
    }

    /**
     * 挑下载目标：**优先本轮刚采音那一条**（按 sn 认，不按长度认）。
     *
     * 真机观测（2026-10-23 07:42 那轮）：`record stop` 之后紧接着的 `getFilesList`
     * 里**没有**刚录完的那条（列表 8 条、最大 sn=11，而本轮 stop 时设备报的是
     * sn=12 `56e3fe.raw`）——每一轮的列表都只含上一轮那条。
     * 这条对上层影响很大：「录完立刻列文件」会看不到自己的新录音，
     * 所以这里重问最多 3 次并单独记账，而不是悄悄退回挑一条旧的。
     */
    private suspend fun targetForClosedLoop(): NvEasyFile? {
        if (recordedSn <= 0) return pickDownloadTarget()
        var target = lastFileList.firstOrNull { it.sn == recordedSn }
        if (target == null) {
            verdict(
                "新录音立刻可列", "FAIL",
                "刚停的 sn=$recordedSn（$recordedName）不在紧接着的列表里" +
                    "（n=${lastFileList.size}，最大 sn=${lastFileList.maxOfOrNull { it.sn }}）"
            )
            for (i in 1..3) {
                delay(5_000)
                val d = device ?: break
                query("getFilesList 重问$i", { mgr.getFilesList(d) }, "onFilesList")
                target = lastFileList.firstOrNull { it.sn == recordedSn }
                if (target != null) {
                    verdict("新录音重问后出现", "OK", "第 $i 次重问（约 ${5 * i}s）出现了 sn=$recordedSn")
                    break
                }
            }
            if (target == null) {
                verdict("新录音重问后仍缺席", "FAIL", "15s 内 3 次重问都没有 sn=$recordedSn —— 上层不能假设「录完就能列到」")
            }
        } else {
            verdict("新录音立刻可列", "OK", "sn=$recordedSn（$recordedName）就在停止后的第一次列表里")
        }
        return target ?: pickDownloadTarget()
    }

    /** 退路：本轮没录音身份时，按长度碰运气对上 `vendor_rt_*`，再退到列表第一条。 */
    private fun pickDownloadTarget(): NvEasyFile? {
        val rtSizes = try {
            dir?.listFiles()?.filter { it.name.startsWith("vendor_rt_") }
                ?.map { it.length() }?.toSet() ?: emptySet()
        } catch (e: Exception) {
            emptySet()
        }
        return lastFileList.firstOrNull { it.size > 0 && rtSizes.contains(it.size.toLong()) }
            ?: lastFileList.firstOrNull { it.size > 0 }
    }

    private suspend fun filesRound(includeDelete: Boolean) {
        val d = device ?: return
        line("── 文件档 ──")
        query("getFilesList", { mgr.getFilesList(d) }, "onFilesList")
        val f = targetForClosedLoop()
        if (f == null) { verdict("BLE 下载", "SKIP", "列表为空或只有 0 字节文件"); return }
        val dl = NvEasyDownloadFile().apply { sn = f.sn; offset = 0 }
        downloadBytes = 0
        drain()
        mgr.downloadRecordFiles(d, arrayListOf(dl), false, false)
        val done = awaitHit(120_000, "onFileStreamDONE", "onFinished", "onException")
        verdict(
            "BLE 文件下载", if (done?.name == "onException") "FAIL" else "OK",
            "sn=${f.sn} 期望=${f.size}B 实收=${downloadBytes}B 终态=${done?.name ?: "120s 超时"}"
        )
        crossCheckDownloaded(f.sn, f.size.toLong())
        if (includeDelete) query("deleteRecordFile", { mgr.deleteRecordFile(d, f.sn, f.name) }, "onDeleteFile")
        else verdict("deleteRecordFile", "SKIP", "未开 del 闸（不可逆）")
    }

    private suspend fun wifiRound() {
        val d = device ?: return
        line("── WiFi 快传档（autoConnect=true，入网交给 SDK）──")
        drain()
        mgr.switchWifi(d, true, true)
        var connected = false
        val t0 = System.currentTimeMillis()
        while (System.currentTimeMillis() - t0 < WIFI_TIMEOUT_MS) {
            val h = awaitHit(6_000, "onWifiStatus", "onWifiOpened")
            if (h != null && h.detail.contains("CONNECTED")) { connected = true; break }
        }
        verdict("热点开启+手机入网", if (connected) "OK" else "TIMEOUT", "等 onWifiStatus==CONNECTED")
        if (!connected) {
            mgr.switchWifi(d, false, true)
            awaitHit(10_000, "onWifiStatus")
            // 第二轮改用 autoConnect=false：把「凭据是不是设备通过 BLE 报上来的」这件事
            // 单独问出来。厂商 demo 注释原文「第三个参数为 false 时，wifi 信息会在
            // onWifiOpened 回调中返回」。只要 onWifiOpened 出得来，快传的**协议**就是通的，
            // 卡住的只是系统入网那一步（App 侧权限/确认弹窗），两者要分开记账。
            line("改走 autoConnect=false：只看设备把热点凭据报不报出来")
            drain()
            mgr.switchWifi(d, true, false)
            val opened = awaitHit(30_000, "onWifiOpened")
            verdict(
                "onWifiOpened 凭据上报", if (opened != null) "OK" else "TIMEOUT",
                opened?.detail ?: "30s 内设备没有回报 SSID/密码"
            )
            if (opened != null) {
                try {
                    File(dir, "newview_ap.txt").writeText(
                        "ssid=${opened.detail.substringAfter("ssid=").substringBefore(" pwd=").trim()}\n" +
                            "pwd=${opened.detail.substringAfter("pwd=").trim()}\n" +
                            "endpoint=${opened.detail.substringAfter("server=").substringBefore(" client=").trim()}"
                    )
                } catch (_: Exception) {}
            }
            mgr.switchWifi(d, false, false)
            awaitHit(10_000, "onWifiStatus")
            verdict("WiFi 快传", "SKIP", "入网没起来，下载段未执行")
            return
        }
        val f = targetForClosedLoop()
        if (f != null) {
            downloadBytes = 0
            val dl = NvEasyDownloadFile().apply { sn = f.sn; offset = 0 }
            drain()
            mgr.downloadRecordFiles(d, arrayListOf(dl), false, true)
            val done = awaitHit(150_000, "onFileStreamDONE", "onFinished", "onException")
            verdict(
                "WiFi 快传下载", if (done?.name == "onException") "FAIL" else "OK",
                "sn=${f.sn} 期望=${f.size}B 实收=$downloadBytes B 终态=${done?.name ?: "150s 超时"}"
            )
            // 蓝牙与 WiFi 两条通道取回的同一个文件必须逐字节相同（Xyrix 那边验过这条，
            // Newview 还没——所以这里也做哈希，而不是只看长度）
            crossCheckDownloaded(f.sn, f.size.toLong())
        }
        mgr.stopDownloadFiles(d)
        mgr.switchWifi(d, false, true)
        awaitHit(15_000, "onWifiStatus")
        line("收尾顺序：stopDownloadFiles → switchWifi(false)（厂商 Demo 同款）")
    }

    // ───────────────────────── 落盘 ─────────────────────────

    private fun verdict(api: String, status: String, detail: String) {
        verdicts.add("$status|$api|$detail")
        // 只走 line()：它已经同时落盘 + Log.i。这里再 Log.i 一次会让 logcat
        // 每条判定出现两行，读证据时容易误判成「跑了两次」。
        line("[$status] $api :: $detail")
    }

    private fun summary() {
        val ok = verdicts.count { it.startsWith("OK") }
        val to = verdicts.count { it.startsWith("TIMEOUT") }
        val fl = verdicts.count { it.startsWith("FAIL") }
        val sk = verdicts.count { it.startsWith("SKIP") }
        line("===== 扫档结束 OK=$ok TIMEOUT=$to FAIL=$fl SKIP=$sk 共 ${verdicts.size} 项 =====")
    }

    private fun line(text: String) {
        try { reportFile?.appendText("${ts()} $text\n") } catch (_: Exception) {}
        Log.i(TAG, text)
    }

    private fun ts() = SimpleDateFormat("MM-dd HH:mm:ss.SSS", Locale.US).format(Date())
    private fun stamp() = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())

    fun tail(maxLines: Int = 400): String {
        val f = reportFile ?: return ""
        if (!f.exists()) return ""
        return f.readLines().takeLast(maxLines).joinToString("\n")
    }

    fun stop() {
        try { device?.let { mgr.disconnect(it) } } catch (_: Exception) {}
        scope?.cancel()
        running = false
    }
}
