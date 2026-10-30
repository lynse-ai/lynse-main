# Changelog

## Unreleased（2026-10-24：命令改成队列发送——一条有应答再发下一条）

- **新增 `CommandLane`**（`lib/core/hardware/command_lane.dart`）：同一时刻只允许一条命令
  在飞，后来的按 FIFO 排队；一条抛错/超时不会卡死队列；车道自身不设超时（放行下一条的前提
  是前一条真的结束，否则又会压到卡上），进车道的动作必须自带超时。用 Zone 标记动作内部，
  嵌套调用在 debug 下当场 assert，避免自锁。
- 接入两处真正往卡上写命令的地方：
  - `NeviewAdapter`：`queryDeviceInfo`/`startRecord`/`pauseRecord`/`resumeRecord`/
    `stopRecord`/`addMark`/`listFiles`/`downloadFile`/`cancelDownload`/`upgradeFirmware`
    全部走车道；`listFiles` 的槽位覆盖「发出 `getFileList` → 收到 `didReceiveFiles`」整段。
  - `NewviewRawClient`（探测台裸协议）：`exchangeRaw` 排队，`_waiters` 正常最多一条。
- **修掉仲裁器的重入漏洞**：`ResourceArbiter.acquire` 原来是 `held != null && held != resource`，
  同资源重入直接放行——两次并发 `fileTransfer`（下载中再点导入/刷新）会双双通过。
  现在只要有人持有就拒；`refreshFiles` 遇到占用静默跳过（幂等刷新不该弹错）。
- **传输期间真正持有锁**：`downloadDeviceFile` 原先拿到 `fileTransfer` 就放，等于没锁；
  现在持有到这条传输收尾（`transferring` 之后的终态 / `FileImportedEvent` / 错误事件，
  10 分钟兜底），否则下一次导入会压在同一条流上。
- 测试：`test/command_lane_test.dart` 5 项（FIFO、并发上限 1、失败不卡队、排队深度、
  同资源重入必须抛 resourceBusy）；`flutter test` 全套 117 项通过。
- ⚠️ 只在 Dart 侧验证。SDK 侧本来就有队列（Kotlin `LynseProtocolRuntime` 是 FIFO 队列，
  Swift 是 slot 互斥、**不保证 FIFO**），这次没改 SDK。

## Unreleased（2026-10-23 第二十轮：蓝牙收尾——第五条只读查询 `authsn`、日志脱敏补漏，以及两处界面文案）

- `*APP#authsn#` 在 PLQ110 / Android 16 上裸发**有回包**，6 段（序列号段按规矩打码）：
  `*DEV#authsn#***(len=24)#E53CF5D3D190#6825DD87E4A9#LYNSENOTE0719091#`。
  判据表加 `'authsn': 6`，它因此从 `forbiddenCommands` 移进 `readOnlyCommands`——
  厂商自己每次连接都调 `queryAuthSN`，这是**读**，不写机器也不下发密钥；
  风险只在「回包落日志」，见下条。双端（Kotlin `parseAuthSn` + Swift `parseAuthSn`）
  已移植并有单测；SDK 侧刻意**不发 Diagnostic、不回答 pending 的 `ReadDeviceInfo`**。
- ⚠️ **热点凭据此前是会进日志的**：`shapeVerdict` 把段列表用 `|` 拼进判据文本，
  而 `redact` 的正则只认带 `#` 的整帧，分隔符一换就盖不住；`redact` 的名单里也根本没有
  `wifi`，于是 SSID 与口令跟着判据一起落到探测台日志与 logcat。
  现在按段位打码（`sensitiveFieldIndexes` / `maskedFields` / `redactHotspotFrame`，
  两种分隔符都盖、9 段与旧 8 段两种形状都盖），探测台里 `AP=${ssid}` 的三处文案改成只留长度，
  `_join` 的「已连上 xxx」也不再印名字（它还可能读到用户自己家的 Wi-Fi）。
  新增两条用例把这件事钉住：判据文本不得含序列号/SSID/口令，且非敏感帧（`cbtname`）照印。
  `test/newview_protocol_mirror_test.dart` 18 项全过。
- 蓝牙这一轮的其他结论：`cmicgain` / `epblestat` / `netinfo` / `netstate` / `call` / `serquery`
  裸发**无回包**；`edr` 那次「有回包」是假的——拆开是 `mem`/`switch`/`cblename` 三条主动上报
  被合并进同一条 notify（矩阵 11.1 那条规律），按 `edr` 记账就是假账。
- 两处界面：传输条此前一律渲染成「0 KB / 0 KB · 37%」——百分比是真的，字节是编出来的
  （Neview 的 `didUpdateDownloadFileProgress` 只给包号，`receivedBytes/totalBytes` 恒为 null）。
  现在拿不到字节就说「第 x/y 包」，不猜每包多大；只有真给字节的那条通路（Xyrix）才说 KB。
  程序名统一为**灵斯记**：Android 启动器标签（原「谛听记」）与 `MaterialApp.title`（原 Lynse），
  iOS 侧 `CFBundleDisplayName` 本来就是灵斯记；bundle id 与工程名不动，免得破坏升级安装。

## Unreleased（2026-10-23 第十九轮：卡片充上电重跑，WiFi 凭据结论翻转，文件面接进 SDK）

- **上一轮「WiFi 拿不到凭据」是错的**（那几轮卡片在掉电）。裸协议 `*APP#wifi#1#` 真机回的是
  **9 段**：`*DEV#wifi#<开关回显>#<服务器IP>#<端口>#<客户端IP>#<客户端端口>#<SSID>#<密码>#`；
  关的时候回 `*DEV#switch#0#`。SDK 侧按 8 段硬解会当场抛，不抛也会把端口当 SSID——
  `newview_protocol.dart` 的段数判据已改 9，`test/newview_protocol_mirror_test.dart`
  把「真机 9 段 = PASS」和「旧 8 段假设 = MISMATCH」两条都钉住（16 项全过）。
  **SSID/密码不进仓库、不进日志**，测试向量用打码同形值。
- 探测台读计划的一个 bug 顺手修掉：`opusfile=1` 这个 token 只有 10 个字符，
  代码按 `substring(11)` 取尾，直接 `RangeError` 让**整份计划读失败**、探测根本没起跑
  （本轮第一次尝试就是撞这个；上一轮「0 候选/全沉默」的原因仍是卡片没电，两回事）。
- 文件面（列表分页 + 逐页 CRC-32 + 下载帧 + 标准 CRC-32）本轮从「厂商二进制里的缺口」
  变成已取证并移植进 `lynse-hardware-sdk`；细节与判据见
  `lynse-hardware-sdk/docs/newview-interface-matrix.md` 第 12 节。
  App 侧生产路径仍走厂商 AAR（`getFilesList`/`downloadRecordFiles`），不受影响。

## Unreleased（2026-10-23 第十八轮：把调试出来的结论接回生产通道，并撤掉三个空头承诺）

- **`pauseRecord` / `resumeRecord` 之前是假的**：插件只 `result.success("pauseRecord!")`，
  一次都没碰厂商 SDK。真机已验通 `record(dev,2/3,mode)` → `onRecordExtended status=2|3`，
  现在真的下发，并且**能力位 17 不在位时不发命令**（发了只会让上层干等超时）。
- 新接通：`addMark`（`recordMark`，真机回 `status=0 index=1 offset=4110ms source=1`）、
  `cancelDownload`（`stopDownloadFiles`；厂商口径：它**不**顺带关 WiFi，快传收尾仍要走
  `switchWifi(false)` 的固定顺序）、`deleteFile`（`deleteRecordFile(sn,name)`）。
- **AppKey 终于真的传进 SDK**：`startConnect` 增加 `appKey` 形参并在连接前补一次
  `init(app, key)`。此前 `NeviewAdapter.connect` 收到 `authKey` 后直接丢弃，
  而 v1.2.0 缺 key 时设备对任何命令都沉默 —— 设置页填的钥匙一直没生效。
- **撤掉三个未验证的能力声明**（它们会让 UI 摆出能用其实不能用的按钮）：
  `wifiTransfer`（三轮真机不通）、`firmwareUpgrade`（无固件包、从未验证、刷坏变砖）、
  `deleteFile`（通道通了但不可逆且未验证，`deleteFile()` 现在明确抛
  「故意不开放」而不是假装支持）。同时**新增** `addMark` 声明（已实测 + 通道已通）。
  `liveAudio` 仍不声明：设备侧已验通，但 `BleDeviceAdapter` 契约没有取流方法，
  声明了上层也拿不到 —— 等契约补上音频帧通道再开。
- **「新录音延迟可见」收进适配器**：`NeviewAdapter.listFiles()` 现在在停止后 20 s 内、
  且条数没有增长时自动重问（每次间隔 5 s、最多 3 次），调用方不必知道这个坑；
  平时一次列表不多花一秒。`stopRecord()` 记下停止时刻作为触发条件。
  之前它表现为「录完立刻刷新，新录音凭空消失」。
- 验证：`flutter analyze` 干净（只剩两处既有 info）、`flutter build apk --debug` 通过、
  全量 `flutter test` **110 条全绿**。
- L3 探测台再补两类形状待跑：分页把「页号在前」和「每页条数在前」都试
  （上一轮四档全是 `0#20` 这类，若第一个参数是页大小，沉默就不能当判负），
  下载按 AAR 字节码的两支（`opusfile#2#…` 与五参数 `opusfile#…`）各试两个 sn，
  且每档前先发 `getlist` 建立会话。卡已入睡（08:03 起 0 候选），计划文件保持 armed。
- 观测：卡电量从 30% 掉到 20%，且每轮扫档都会持续推流 ~20 s × 多次 ——
  反复扫档会明显耗电，这也可能是它几次「扫不到」的原因之一。

## Unreleased（2026-10-23 第十七轮：真机再扫 38 项，文件内容级闭环验通）

- 卡回来了，跑了第三轮厂商 AAR 全接口扫档（`OK=26 / TIMEOUT=9 / FAIL=1 / SKIP=2`），
  逐项复现上一轮，并补上**内容级**判据：本轮实时采音 `vendor_rt_…​.opus`（70,480 B）
  与从卡上下载回来的同一条录音 `vendor_dl_sn13.opus` **SHA-256 逐字节相同**。
  之前的「实收==期望」只证明长度，这条才证明 `audio.live → 设备存储 → transfer.file` 是同一份数据。
- 探测台的两处自身缺陷一并修掉：下载字节**必须落盘**才算验过内容；
  闭环对比**必须按 sn 认文件**——上一版按长度配对，两轮录音时长一样（每步 sleep 固定秒数），
  于是拿两条不同录音互比，报出 97.91% 字节差的**假 FAIL**。判据认身份，不认尺寸。
- **两条真机行为值得记**：
  1. `record stop` 之后紧接着的 `getFilesList` **不含刚录完那条**
     （列表最大 sn=12，本轮设备报 sn=13），约 5 s 后重问才出现。
     「录完立刻列文件」会看不到自己的新录音，不能拿第一次列表判断录音成败。
     探测台已实现缺席时最多重问 3 次并单独记账；会话层同样要处理。
  2. 设备会把**多条 `*DEV#` 文本帧合并进同一条 notify**（实测 55 B = flist+incharge+switch），
     SDK 原来按 `#` 切会看到 13 段并抛 invalidFrame → 整批消息丢失。双端已修（见 SDK CHANGELOG）。
- 裸协议侧新确证：`*DEV#flist#<正文总字节>#<页数>#`（6→7→10 条文件对应 985#3→1152#3→1653#4）；
  但 `listreq#<页>#<条数>#` 四档参数与只读下载 `opusfile#<sn>#1#0#1#0#` **全部无回包**，
  列表正文与下载请求帧仍需厂商给规则。WiFi 快传第三轮同样不通（两条路径复现）。
- 设备侧计划文件已改回 `0`（探测关闭）。

## Unreleased（2026-10-23 第十六轮：App 侧裸协议与 SDK 重新对齐，顺手抓出一个丢位的表）

- 上一轮改了 SDK 的广播解析锚点，**App 侧 Dart 的 `NewviewRaw.parseAdvertisement` 没跟上**：
  它还写死 `"NvEasy"` 字面量 + 取头 3 字节当 deviceCode，也就是真机已经否掉的那套旧规则。
  镜像测试当时依然全绿 —— 因为它是**手抄** Kotlin 的旧逻辑，抄的是改动前的版本。
  这轮把 Dart 改成与 Kotlin 同一套：先认 `"NvEasy"`，认不到就按尾部 `"NV"` 族标记倒推
  厂商码起点；`deviceCode` 改取那 6 字节厂商码本身。真机 23B 原文现在两侧都解得开
  （`ilynse` / proto 24 / sku `L1` / `f2 46 00 00`），并作为回归向量钉进测试。
- **抓出一个「丢能力位」的表**：`abilityNames` 原先只有我们自己声明的 8 行，
  厂商定义有 15 位。真机 mask 明明置了 `25 rtc`，探测台报 `declaredAbilities`
  时却把它静默丢掉 —— 报 7 项、实际 8 项，**「我们不认识」被伪装成「设备没有」**。
  现在表补全到 15 位，并把 `knownCapabilityMask` 拆成独立的
  `sdkDeclaredAbilityBits`：前者是厂商全表、后者是我们声明的子集，
  两者混成一张表的话差集检查就恒等于 0，再也指不出「声明与本机不符」。
- `kotlinExpectedFieldCounts` 补上真机推过的四条原文（`incharge` 6 / `mem` 4 /
  `flist` 4 / `switch` 3），`wifi` 8 那条明确标注**未经设备验证**；
  段数变化时 `shapeVerdict` 会报 MISMATCH，这就是「Kotlin 的硬编码过时了」的信号。
- 验证：`test/newview_protocol_mirror_test.dart` 16 条全绿，
  仓库全量 `flutter test` **110 条全绿**（改动是共享文件，跑了全量回归）。

## Unreleased（2026-10-23 第十五轮：Newview 剩三项待取证，探测台先把问题问对）

- L3 加了两档**不依赖厂商 SDK** 的取证：
  **列表分页**（`*APP#listreq#<页>#<条数>#` 四档，命中 JSON 就停并记下参数形状）和
  **只读下载**（`*APP#opusfile#<sn>#1#0#1#0#`，`isDelete=false` 所以安全；
  回包按「长度 %80」判容器形状，正文落盘 `newview_l3_dl_sn*.bin` 离线逐字节判）。
  动因：真机对裸 `listreq` 只回**表头** `*DEV#flist#985#3#` / `#1152#3#`
  （两轮数字随文件数 6→7 变化），说明列表正文要带页参数才推，
  而我们 SDK 里既没有 `flist` 分支也没有下载请求帧 —— 这两条不能靠猜落地。
- 探测计划文件当前停在 `3 only / name=Lynse`；卡一旦被扫到就跑出上面两档，
  之后把计划改成 `4 only` 再跑一次 WiFi 凭据档（`autoConnect=false` → `onWifiOpened`）。
- ⚠️ 卡 `Lynse AI 0091` 自 22:14 起多轮扫不到（11~25 条扫描结果里都没有它，
  手机蓝牙正常、XYRI 那台一直在），疑被别的客户端占着或已休眠。
  因此仍未取证：`flist` 正文、BLE 下载请求帧形状、WiFi 凭据上报。
- OTA 按决定**只接接口不真刷**：没有可用固件包，且刷坏会变砖。
  映射与判据已移植进 `lynse-hardware-sdk`（20 种 `OTAException` → Lynse 错误码、
  包大小 448/≤460、`progress==100 ≠ 成功`、成功判据 = 重连读到目标版本），
  能力在 descriptor 里保持不声明。

## Unreleased（2026-10-22 第十四轮：**Newview 录音卡全接口真机扫档**，厂商 AAR 升到 v1.2.0）

- 台架上是 `Lynse AI 0091`（BLE `E5:3C:F5:D3:D1:90`，proto 24，idMark `ilynse`，sku `L1`）。
  新增 `android/.../nveasy/NewviewVendorProbe.kt`：以**厂商 SDK 为裁判**逐接口扫档，
  每项单独计时判 OK/TIMEOUT/FAIL/SKIP，全部落盘 `newview_vendor_report.txt` + logcat `NVV`。
  计划文件 `newview_probe.txt` 第二行加 `vendor=1` 触发；L1 裸协议跑完自动接扫档。
- **换到厂商 `NvEasyBle-v1.2.0` + `NvEasyAudio-v1.0.3`**：原来的 v1.1.3 里
  `init(Application)` **根本没有 appKey 形参**、整个类也不含 `*APP#appkey#` 字符串
  （逐类扫描计数为 0），也完全没有 flashNote / recordMark / setActive / AI 档——
  用它当「厂商能不能问通」的裁判是不成立的。v1.2.0 只有一处 API 破坏：
  OTA 回调 `onFail(BleException)` 收窄成 `onFail(OTAException)`，已改。
  v1.2.0 的 `aar-metadata` 要求 compileSdk 37，本机只有 36 且 AGP 8.13.2 封顶 36，
  所以联调用了一份**只改那一行元数据**的 `NvEasyBle-v1.2.0_minSdk36.aar`
  （classes.jar 逐字节相同）；装机验完要换回原包或升到 37。
- **实测通过的接口**：`queryVersion 1.5.1/0.3.0`、`queryBattery 30%`、`queryChargeStatus`、
  `querySwitch`、`queryAuthSN`（authSN + bleMac + wifiMac + labelSN）、`queryBleName`、
  `queryBluetoothName T2403`、`queryOffTime 36000`、`queryMicGain`（会议 17/17、通话 17/13）、
  `record` 开始/暂停/恢复/停止、`recordMark`、`onStream` 实时流、`getFilesList`、
  BLE `downloadRecordFiles`（sn=10 期望=实收 70,480 B）。
- **实时音频是 16000 Hz / 双声道 / 20 ms / 80 B 一包**（`onRecordExtended` 随流上报），
  不是单声道；proto≥24 只认 `onRecordExtended`。
- **闭环验证**：第二轮下载的 `sn=10 612991.raw` 就是第一轮实时采音落到卡上的那个文件，
  字节数逐字节相等——「实时流 → 设备存储 → BLE 下载」这条链成立。
- **WiFi 快传仍未通**，且两条设计路径都堵：`switchWifi(true, autoConnect=true)` 走到
  `OPENING→OPENED→CONNECTING` 就停住；改 `autoConnect=false` 后 30 s 内
  设备**没有**回报 `onWifiOpened` 凭据。我先把它归因成「缺 `NEARBY_WIFI_DEVICES`」，
  **那个归因错了**——台架是 Android 12 / API 31，这条权限在这台机器上还不存在
  （`pm grant` 报 `Unknown permission`），而 `ACCESS_FINE_LOCATION` 早已 granted=true。
  权限声明仍补进了 manifest（与 AAR 对齐，Android 13+ 才是前提），但不是本轮原因。
- **一处曾经下错的判据**：21:41 那轮这台卡对所有 `*APP#` 命令全沉默，当时判成
  「鉴权是闸门」。22:03 重跑，**不发任何握手** 5/6 直接有回包
  （`version/battery/mem/getlist/listreq`，其中 `listreq` 回 `*DEV#flist#985#3#`，
  说明列表真身在 `flist` 分支、我们 SDK 里没有这个分支）。沉默的原因是**设备状态**。
  另外发完明文 `rtc/ostype` 初始化后掉到 0/6 —— 那两帧会把会话打死，
  探测顺序必须改成「先问完，最后再试初始化」。
- 能力位可以当接口开关用：缺席的 19/21/26/27/24 恰好对应 `flashNote` 无回包、
  `readDeviceInfo/edr/call` 明确 `onCommandFailed`。
- 装机注意：`adb` 在 Git Bash 下会把 `/sdcard/...` 改写成 `C:/Program Files/Git/sdcard/...`，
  需要 `export MSYS_NO_PATHCONV=1`。

## Unreleased（2026-10-21 第十三轮：**WiFi 快传真机闭环 —— 五项全通**）

- 结论先说：`0x21 开热点+起 TCP` → 手机入网 → BLE 发 `0x46 [0:/文件名][4B 大端偏移]`
  → TCP **`192.168.1.80:5000`**（文档默认值，终于验实）→ 收流落盘，
  77,952 B 的录音 **`integrity=verified`**，且落地文件与蓝牙下载的同一文件
  **SHA-256 逐字节相同**（`e1ab7a99…b135a1`）。第 4 项通了，五项全绿。
- **流的形状**：设备推的是**文件原始字节**，末尾追加 20 B `sendfile finish!` + 4×NUL
  收尾标记。新增 `XyrixWifiStreamSplitter` 按标记收流；标记不写盘。
  之前正是把这 20 B 算进文件长度，才让一次**已经成功**的快传被判成「数据流被污染」
  （断点越界时设备只回这个标记，于是每轮都"过收"20 B，连判 5 轮失败）。
- **TCP 选路判据改成「谁真的推字节」而不是「谁接受了 connect」**：
  手机进了卡热点后仍能到家里路由器，`192.168.1.1:80` 握手成功却零字节，
  旧实现「取第一个连上的 socket」会把路由器当成卡的服务器，然后空等 15 s。
  现在候选端点并发拨号、并发监听，探测期字节先进缓冲不丢（`_TcpProbe`），
  赢家装好回调后一次性补交，每个字节恰好投递一次。
- **断链续传**：卡的 AP 会在手机重复关联时把客户端踢掉（`reason=6`），手机随即漫游回
  有互联网的家用网。会话改成「一轮拿一段：重新 `0x21` → 等手机回到 AP →
  按 `0x46` 偏移续传」，上限 10 轮；每轮各自记录字节数，跑完能答出断在哪。
- 两个把链路挡住的实现级 bug：
  ① `WifiInfo.getSsid()` 带首尾双引号，`"AP_…"` 与 `AP_…` 比相等必然失败——
  手机明明已在卡上（`cmd wifi status` 直接显示），App 却判「没连上」并顺手关了热点。
  新增 `normalizeSsid`（Kotlin 侧同样剥引号，`<unknown ssid>` 归一为空）。
  ② 设备不回传凭证时不再直接抛错：新增带外参数 `ap=SSID:口令`（协议里确实没有
  设备下发 SSID/密码这一步），`host=ip:port` 可把拨号收窄到明确端点。
- **吞吐实测，别按名字选通道**：同一张卡、同一个 77,952 B 文件、同一台 Mate 40——
  蓝牙 887 ms ≈ **86 KB/s**，WiFi 快传 3.33 s ≈ **23 KB/s**。**本版固件的「快传」比蓝牙慢一倍以上。**
- 探测台：配了带外 AP 参数就不再跑 4 分钟的热点凭证 hunt；
  **`0xF1 设置 WiFi SSID 和密码` 从 hunt 里移除**（出厂信息写入，与 `0xF4` 写 SN 同类，
  写错不可恢复，且已证明对本固件无可见效果），测试里加了断言防止有人加回来。
- 口令不再进日志：凭证帧文本打码后打印，`HardwareException` 面向用户的文案里不含 SSID。
- 测试：新增 `test/xyrix_wifi_stream_splitter_test.dart`（含「标记被 TCP 从任意位置切开
  都能认出」的 19 种切点穷举），`xyrix_hotspot_credentials_test.dart` 补 `normalizeSsid`
  与 `parseApParams`，`flutter test` 94 项全绿。顺手修了 `xyrix_probe_test.dart` 里
  缺 `runTextCommandProbe` 导致的编译失败（上一轮加接口时漏改替身）。
- 未验到的点，别当成已验：iOS 侧 `NEHotspotConfiguration` 这条路本轮没上真机
  （Mate 40 是 Android）；Kotlin 适配层仍不声明 `WIFI_FAST_TRANSFER`（见 SDK CHANGELOG）。

## Unreleased（2026-10-19 第十二轮：真机产出**可播放** Ogg Opus —— 第 5 项通了）

- 把 `XyrixChunkAccumulator` + `XyrixOpusMuxer` 接进实时捕获落盘路径：
  原始字节继续存 `.raw`（逐字节传输证据，不再冒充任何格式），
  **另存一份可播放的 `.opus`**。收尾必须 `finish()`，否则没有 EOS 页、播放器判文件截断。
- 真机实测（Mate 40 Pro + XYRI 卡，探测台 L2，2026-10-19 23:03）：
  - `recordLifecycle … 推流包数 开始+541 暂停+2 恢复+388，设备文件 1→2`
  - 产物：`xyrix_rt_2026-10-19T23-03-46…​.opus` 29,359 B（配 `.raw` 32,075 B）、
    `…23-03-26….opus` 40,786 B（配 `.raw` 45,003 B）
  - 拉回本地验：文件头 `4f 67 67 53`（`OggS`）、`ffprobe` 读出
    `opus, 48000, 1` 且时长 **7.94 s / 11.24 s**、libopus **0 解析错误**；
    解出 PCM 零交越率 785/s、窗 RMS 123→823 —— 是带语音特征的波形，不是噪声。
  - 体量自洽：32,075 B ÷ 7.94 s ≈ 4.0 KB/s ≈ 50 包/s × ~70 B，正是 20 ms 一包。
- 至此五项里 **四项真机通过**（录音开始/暂停/恢复、蓝牙文件传输、实时流解码存成可播放 opus）；
  只剩「录音快传（WiFi）」卡在厂商热点启用规则（两张卡 + 厂商自己的 Demo 都开不出 AP）。
- 未验到的点，别当成已验：本轮没抓到 `Opus 收尾` 那行日志，所以这两个设备文件的
  「重同步跳过字节数」没有实测值（离线存档那份是 143 B / 0.019%，性质仍未定性）。

## Unreleased（2026-10-19 第十一轮：Dart 侧 Opus 打包器与 Node/Kotlin 逐字节对拍通过）

- 新增 `lib/core/hardware/xyrix/xyrix_opus_muxer.dart`：容器切块（**含 `0x48` TOC**，
  拼回完整 Opus 包）+ Ogg Opus 打包（RFC 7845，Ogg MSB-first `0x04C11DB7` CRC、
  lacing 攒到 250 才 flush、页边界只落在包边界）。
- 跨语言对拍**通过**：拿真机实时存档 `p_xyrix_rt_…opus`（753,309 B）跑
  `dart run tool/xyrix_mux_parity.dart`，输出与 Node 参考实现 **SHA-256 完全相同**
  （`42d06a31…`，680,302 B、10,588 包、211.76 s、libopus 0 解析错误）。
- 一处必须说清的细节：Dart 第一版在第一个不合规则的字节就 `break`，只走出 2,264 段；
  改成**向前重同步并如实计数**后才对齐 —— 重同步跳过了 **143 B（占 0.019%）**。
  这 143 B 是什么还没定性（传输层 seq 对账此前证明 0 丢包，所以更像记录边界的残留），
  别把它当成「无损」的一部分讲。
- 还没做：把 `XyrixOpusMuxer` 接进实时捕获的落盘路径（现在仍存原始字节成 `.opus`），
  以及**真机跑一次产出可播放文件**。这两步是第 5 项收尾的最后一段。

## Unreleased（2026-10-06 第十轮：一次性价掉「XYRI 卡其实是 Neview 固件家族」这个假设）

- 厂商交付包里那份 AAR 是 `com.nveasy.ble`，命令语言是 ASCII `*APP#…#`（回包 `*DEV#`），
  里面**正好有**目标里卡住的两项：`*APP#wifi#<n>#`（快传开关）和 `*APP#opusfile#<n>#`（opus 文件）。
  所以值得一次性价掉「这块卡其实是同一个家族、只是我们发错了通道」。
- **结论是否**（真机 L5 `text命令探测`）：裸写 `version/battery/mem/getlist/wifi#1/wifi#0`
  六条文本命令**全部无回包**。结构上也对不上——Neview 家族的服务是
  `06068d0c/1c/2c`，而这块卡的 GATT 全表只有 `6e400001(NUS)` + `…1913` + `…1930`，
  历史抓包 UUID 词频里 `06068d` **一次都没出现过**。不是发错特征，是两套固件。
- 新增探测能力：`sendRaw()`（绕过 FF55AA 封装）+ `rawTap`（把通知原始字节旁路出来，
  因为 `*DEV#…` 根本不是帧，帧解析器会丢）+ 探测档 L5 的 `text命令探测` 步。
  工厂类命令（`format/blename/devpair/sdkkey/authsn/algkey`）一律不在任何档里发。
- 那份 AAR 的正确归宿是**另一家厂商**：它读出来的 WiFi 快传时序、`*DEV#opusfile#`
   TCP 载荷格式、每包序号+校验+按 index 重传的模型，全部记进了
  `lynse-hardware-sdk/docs/newview-adapter-mapping.md`；Xyrix 侧的负结果记在
  `first-device/xyrix/README.md`。里面点出一个契约问题：`LynseWifiTransferRuntime`
  目前只会讲 LYWF（`4C 59 57 46`），而厂商自带 framing——这是契约决策，不该由适配层绕。
- 目标里那两项**仍然卡在 Xyrix 自己**：热点启用规则、`0x54` 载荷封装/解码器。
  读 Neview 的代码补不上这个洞。

## Unreleased（2026-10-06 第九轮：`0x54` 载荷「不是 Opus」补上协议级证据）

- 上一轮的结论是「套 Ogg 容器后 6,301/9,980 段 TOC 解析失败」，那是**观测**；这轮补上了
  **为什么**，并且先排除掉「是我们自己打包写坏了」：
  ① 封装边界是死的——753,309B 存档按 `[1B L][7×00][0x48][L-1B]` 全程只重同步 2 次，
     切出 10,588 段（≈20ms/段、24.8kbps）；
  ② 同一个 Ogg 打包器喂 ffmpeg 自己编码的 Opus 包 → 0 错误、时长对得上，打包器无罪；
  ③ 按首字节分类分别解码：`0x38`/`0x8c` 两类 0 错误，但占大头的 `0x3A` 是
     **config 7(SILK) + code 2**，RFC 6716 里 code 2 只能配 CELT → 3,679 段全被拒；
     `0x8D` = config 17 + code 5 同理。45 种「跳过字节数 × 尾部裁剪量」组合穷举，
     最好也只到 33% 错误率。所以不是差一个头/尾字节，是载荷本身不是 Opus。
  ④ 厂商侧核对：AAR 的 `libSDK.so` 导出只有 `Java_com_nveasy_ble_Auth_*` 与
     `Java_com_nveasy_ble_NoiseCancellation_*`，字符串全是 `gtcrn_encoder_GTConvBlock_*`
     这类 **GTCRN 语音增强网络权重**（输入是 PCM）。也就是说厂商包里没有解码器，
     「解码成可播放音频」从来不在它的交付范围内。
- 取证结论已写进 `xyrix_adapter.dart` 的 `_openRealtimeCapture` 注释与 SDK 的
  `first-device/xyrix/README.md`，复现脚本在 `.sdk-probe/`（`rt_layout.js`、
  `rt_unpack.js` + `rt_lib.js`、`bf_opus.js`）。
- 「实时音频保存成 opus」这一项因此**卡在厂商**：要么给 `0x54` 的载荷封装规则，
  要么给解码器。传输侧的字节完整（seq 连续、0 丢包）已经验证过。

## Unreleased（2026-10-06 Xyrix 联调第八轮：WiFi 与音频载荷的取证收口）

- **新增 `wifi状态机对账` 探测步（L4）**：开 `0x21` 前后各读一次 `0x1A` 卡状态与
  `0x2E` 存储，逐字节对比，用来区分「命令被固件吞了」和「生效了但我们扫不到」。
  真机结果：`0x1A 00 00 00 00 → 00 00 00 00`、`0x2E` 完全相同 → **设备侧无任何 WiFi 活动迹象**。
  诚实限定：`0x1A` 恒为全零，可能它本来就不携带 WiFi 位，所以这条**不能单独**定案；
  但对照组说明 diff 手法是活的（`0x2E` 剩余容量在几轮录音后确实从
  `01 c3 2b 40` 变成 `01 c3 1d 00`），所以「没变化」不是传感器坏了。
  它与前三条外部负证据（扫不到 AP / 已保存隐藏网络连不上 / 局域网 ping+端口全负）方向一致。
- **App 内 UI 链路端到端复验**（补第七轮没做的部分）：设备页扫描连接 → SN 显示
  `260626010…`；点文件条目触发下载，界面进度卡 `1.1 MB / 1.1 MB · 100%`、`124 KB/s`、
  **「传输完成，字节校验通过」**，条目转「已下载」。
- 记录两个未文档化状态帧（真机抓包，文档 §8 全表里没有）：
  `FF 55 AA 00 09`（空帧）与 `FF 55 AA 02 E0 xx xx`，**都在下载刚结束时出现**
  （观测到 `E0 01 01` 与 `E0 00 11` 两种），是传输收尾状态，与 WiFi 无关。
- 界面缺口（本轮发现，未修）：**设备页已连接状态下没有任何「断开」入口**，
  想重走一遍扫描连接只能 `pm clear`。
- 81 例测试全绿；analyze 仍是那 3 条历史 info。

## Unreleased（2026-10-06 Xyrix 联调第七轮：快传数据通路用替身服务器验穿）

热点启用规则还在厂商那边，但**「没有规则」不等于「我们的实现是对的」**——
所以给快传加了一个替身入口，把这条链路本身验穿：

- `Config.wifiServerOverride`（计划文件第二行 `tcp=ip:port`）：非空时跳过
  「BLE 开热点」与「手机入网」两步，把 TCP 端点指到局域网上的假服务器，
  专验 `0x46 → TCP → .part → finalize → 完整性判定`。默认空，生产路径不变。
- 探测台 L4 新增 `wifi快传闭环` 步骤（`runWifiDownload`）；配了替身服务器时
  自动跳过 4 分钟的热点凭证 hunt，自检可以反复快速迭代。
- **真机实测（手机 ↔ PC 走真实一跳网络，77,977B）**：
  - 全量：`received=77977/77977 integrity=verified`，落地文件 SHA-256
    与服务端所发**完全相同**（`795e043e…`）；
  - **断点续传**：先塞一个 40,000B 的 `.part`，日志正确识别
    「从断点 40000/77977 续传」，服务端只发后 37,977B，拼装后哈希仍与完整文件
    逐字节一致，且 `.part` 收尾后已清零。载荷里刻意含 `0x0A/0x0D`，
    任何换行转换都会暴露成哈希差异。
  → 快传现在缺的**只有**「让卡把 AP 起来」这一条厂商规则，数据通路本身已验证。
- **修掉一个我上一轮误判成「假缺陷」的真 bug：自动重连后 SN 显示「--」。**
  上一轮我只 grep 了 `BleDevice(` 就宣布「无从复现，不修」——**结论是错的**，
  模型类型其实是 `DiscoveredDevice`，`DeviceSessionController.autoReconnect()`
  会从 Hive 里存的 `{vendorId, deviceId, name}` 重建对象，**不带广播数据**，
  而 SN 只能从广播的 manufacturerData 里拿（0xFF 查设备号这版固件不回）。
  这次在真机 UI 上直接看到 SN 栏是 `--` 才认账。
  修法：连接成功时把 `serialNumber` 一起写进 `_lastDeviceKey` 的 JSON，
  自动重连时先回填 `deviceInfo`（`DeviceInfoEvent` 的归并对 null 字段保留旧值）。
  **真机验证**：`pm clear` → 扫描连接（SN 显示 `260626010…`）→ 杀进程重启 →
  自动重连后 SN 仍然显示，且该进程内 `startScan` 调用数为 **0**，
  证明它只能来自持久化回填，不是又扫到了一次。
- **App 自身的 UI 链路端到端跑通**（此前只验过探测台，没验过界面）：
  设备页 →「会议录音」→ 实时推流 2,851 块 →「暂停」增量 7 块 →「停止」增量 39 块，
  落盘 `丢包 0，乱序 0`，卡上文件数 37→38（确实录进去了）。
  点设备录音文件条目 → 界面出现「文件传输」进度卡：
  **`1.1 MB / 1.1 MB · 100%`、`124 KB/s`、`传输完成，字节校验通过`**，
  条目变成「已下载」带勾。蓝牙下载在真实界面里是走得通的。
  顺带记一个界面缺口：**设备页在已连接状态下没有任何「断开」入口**，
  想走一遍扫描连接只能清数据，这个后面要补。
- 81 例测试全绿；analyze 回到只有 3 条历史 info。

## Unreleased（2026-10-06 Xyrix 联调第六轮：蓝牙文件下载打通）

**根因**：启动帧写法。文档 §8.5 把 `0x00` 标成「Telink 芯片启动」，并在「附加数据」
一栏直接写了完整帧 `FF 55 AA 02 00 08 00`——它不是另一颗芯片的专用命令，而是
**把 0x08 启动当成 2 字节参数塞进 0x00 帧**。本卡只认这一种：
`0x07 [绝对路径][4B 大小 BE]` → 设备 `0x2D`+ACK → **`0x00 [08 00]`** → 488B 定长块流。
裸 `0x08`（无论带不带参数）一律零字节下发。

- 取证方式是穷举矩阵，不是试出来一个就算：10 种 `0x07` 载荷 × 6 种启动写法
  （`0x08` 空 / +path / +[01] / +sizeBE / 不发启动 / `0x00 [08 00]`），
  只有最后一格出数据，其余全 0。上一轮「10 种载荷全失败」因此作废——
  载荷本来就一直是对的，错的是启动帧。
- **数据完整性已实证**：`2026-10-05-23-12-07.wav` 77,977B 与
  `2026-10-05-22-21-35.wav` 1,164,887B 均 `received == expected`，
  `TransferIntegrity.verified`；1.16MB 用时 8827ms ≈ **129 KB/s**（MTU 512）。
  设备侧 `ls -l` 字节数与 `0x2D` 报的期望值逐字节相等。
- 回拉取证注意：`adb shell "run-as … cat" > 文件` 会做 LF→CRLF 转换，
  1,164,887B 落地变 1,168,853B（差值 3,966 正好是流中 0x0A 的个数），**不是丢数据**。
  二进制回拉一律走 `… | base64` 再本地解码；两条通道（`adb pull` 与 base64）
  对同一文件 MD5 一致。
- **重复传输取证（无丢失）**：删掉设备上第一份，用清理后的包重传同一个 1.16MB 文件，
  两次独立 BLE 传输落地 MD5 相同（`fcd233a3…`，均 1,164,887B）。同一次传输里
  字节数还与 `0x2D` 报的期望值精确相等，且过收会被判污染——所以既没少也没多。
- **日志吞吐闸**：`_onNotifyData` 原来对每一条通知打全量 hex。清理后的包改成
  ≤32B 的控制帧打全量 hex（对文档有用）、大块只打长度，首包 hex 仍由
  `_onDownloadBytes` 保留。同一文件同一时序：清理前的构建跑了 2.5 分钟没跑完
  （通知已 2,387 条 / 日志 5.7MB，且当时还有 8 个后台 logcat 在抢同一条流），
  清理后的构建 8.75s 完成、日志 2,584 行。**两个因素混在一起，无法单独归因**，
  但逐包 hex 在几百 pkt/s 的数据流上没有信息价值，该关。
- 下载到的「.wav」不是 RIFF/WAVE，而是厂商的分帧容器：记录以
  `[1B 长度][8B 子头，末字节 0x48][载荷]` 变长排列，需要厂商解码器才能出声。
  与用户「保存成 opus 即可」一致，播放侧不在本轮范围。
- **清掉 170 行实验脚手架**：载荷扫描（`runBlePayloadSweep`）、厂商特征订阅、
  `_dlPlan` 启动矩阵、`_dlStartCmd/_dlStartData` 等全部删除，`sendCommand` 回到只写
  NUS；`Config` 里 `xyrixDlMode/dlMode/dlSweep/dlBarePath` 退役。
  生产路径现在只剩 `0x07` → `0x2D` → `0x00 [08 00]` → 收块 → `.part` 改名。
- `xyrix_commands.dart` 里 `transferStartJl`/`transferStartTelink` 的芯片命名是文档
  的分组说法，与本卡实际行为不符，已在注释里写明「本卡只吃后者」，避免下一个人
  按名字选 0x08。`buttonConfirm` 那条「设备可能在等确认」的猜测同步作废。

### 本轮其余真机结论（清理后的同一个包上跑的）

- **录音开始/暂停/恢复/停止（L2）复核通过**：`0x1B` 后实时推流 489 包 / 43,456B
  （**丢包 0、乱序 0**）；`0x1C` 暂停后推流只剩 1 包（收尾残余）；`0x1F` 恢复又回到
  373 包；`0x1D` 停止后设备文件数 36→37，说明确实写进了卡里。
- **WiFi 快传：判不可用，且这次是双判据判的。** 旧探测台拿「有没有回执」当判据，
  而本固件大量命令不回话照样生效（录音系列全无 ack），所以那个「四种编码都失败」
  是无效结论。这轮换成两个与设备无关的外部观测：① 手机上用 `cmd wifi
  connect-network LYNSEXY wpa2 … -h` 建一张**已保存的隐藏网络**（App 侧
  `addNetworkSuggestions` 回 `status=0` 只代表系统收下，Android 12 可以不据此入网，
  单用它做判据会假阴性）；② `cmd wifi list-scan-results` 每 6s 采一次。
  9 种发法（`0x11` 的 4 种载荷编码 × 「0x11+0x21」/「0x21 带载荷」，外加
  「`0xF1` 工厂写 WiFi 凭证 → 0x21」）全部既没让手机连上、也没在 43 次扫描里
  多出一个 AP——**卡的 WiFi 根本没起来**。`0x21` 回的那帧 `[01]` 与 `0x23 关 WiFi`
  的回执形状完全相同，是通用「命令收到」，不能当「热点已开启」的证据。
  **厂商 Demo 补了终判**：`com.xyrix.ble_demo` 「文件传输」页的使用说明原文是
  「TCP 下载需**先手动连接 Wi-Fi 热点**，再连接 TCP」，TCP 页只是预填
  `192.168.1.80:5000` 等用户点连接——Demo 也不通过 BLE 下发或设置凭证，
  说明热点名/口令在厂商体系里是**带外信息**（机身标签或硬件手册）。
  缺的是厂商的热点启用规则与默认 SSID/密码，不是我们没试够编码。
- **实时落盘的 `.opus` 不是可播放文件**，别当成 Opus 交付：它是设备 0x54 流的原样存档。
  这轮拿 890,054B 真机原始推流存档（10,097 包）取证过：按
  `[1B 子记录长度][8B 以 0x48 结尾的子记录头][音频][2B CRC]` 取 offset=9 当 Opus TOC，
  98.6% 配置位合法（随机字节约 56%），说明**包边界是对的**；但同一条流里声道位
  5350 单声道 / 4746 立体声对半开、配置位在 cfg7(SILK WB) 与 cfg17(CELT FB) 间来回跳，
  套上 Ogg 交给 libopus 解则 9,980 段里 6,301 段 TOC 直接解析失败。
  → **载荷不是裸 Opus 包**，前面还有一层厂商封装（或一包多帧/声道交织）。
  顺手排掉一个假线索：offset=8 看着 99.5% 合法，那是在数 0x48 标记本身
  （0x48 当 TOC 恰好是合法 cfg9）。也核对过落盘本身没有丢数机制：队列无上限、
  关闭前先 flush、flush 与置空 sink 之间没有 await 让点。
  已在 `_openRealtimeCapture` 与 `opusData` 注释里写明「别照着这个注释写解码器」。
- 顺带把「每条通知打全量 hex」的调试日志加了长度闸（见上）。
- **厂商 Demo 反向佐证了下载启动帧**：Demo「命令面板 → 快捷命令 → 启动传输」
  往 hex 输入框预填的就是 `FF55AA02000800`，与我们穷举出的那一格逐字节相同。
  这条独立证据已写进 `transferStartTelink` 注释。
- **Demo 里根本没有解码器**：`app-release.apk` 的 `lib/arm64-v8a/` 只有
  `libflutter.so`/`libapp.so`/`libandroidx.graphics.path.so`，`libapp.so` 里
  `opus`/`ogg`/`decode` 一个符号都搜不到（只剩框架自带的媒体键名）。
  也就是说「解码」从来不在这套 SDK 的交付范围内——Demo 只搬字节。
- **排掉「卡早就在局域网上」这条路**：PC 与手机同在 `192.168.1.0/24`，
  `ping 192.168.1.80` 100% 丢包，`Test-NetConnection -Port 5000` False，
  ARP 表里没有 `c4:22:4e` 前缀的 MAC。加上前面「扫不到 AP」，WiFi 快传
  现在是三条互相独立的网络层负证据，不再依赖任何回执判据。
- 81 例测试全绿（新增 2 例锁住热点 hunt 的新判据：设备零回执但手机连上要判命中），
  analyze 仍只有那 3 条历史 info。

## Unreleased（2026-10-06 Xyrix 联调第五轮：拿到厂商 SDK 文档，逐项核对）

用户补交 `XyrixSDK-2/`（两份文档 + AAR/xcframework 构建产物 + 官方 Demo APK）。据此核对并修正：

- **文档与真机矛盾处，以真机为准**：附录 A 写「长度 = 1 + N」，但 §5 的示例帧
  `FF 55 AA 00 01` 和真机全部响应都是「长度 = N」——codec 不改。
- 补齐文档 §8.8/§8.9/§8.12 里我们命令表**完全没有**的命令：同传 `0x36-0x39`、
  会话翻译 `0x40/0x41`、`0x30 长按按钮响应`、`0x31 退出 APP`、`0x60 模式切换`。
- **连接时协商 MTU 512**（文档 connect() 明确「Android 自动 MTU 协商，默认 512」，
  我们此前从不请求）。实测 `请求 512 → 512`。
- **WiFi 快传按文档改时序**：`0x46` 先于 `tcpConnect`；TCP 端点补上文档默认
  **192.168.1.80:5000**（此前候选里根本没有 5000 端口）。凭证等待从 12s 空等
  改成 3s 后明确报「协议里没有设备下发 SSID/密码这一步」，不再伪装成设备不支持。
- GATT 全表勘察（新增 `runGattSurvey`）发现卡上除 Nordic UART 外还有两个厂商服务：
  `…1913/2b15[WwN]` 与 `…1930/2b30[Ww]+2b31/2b32/2b33[N]`。四条通知特征全部订阅后
  仍收不到文件数据；把命令改发到 `2b30`/`2b15` 则**连命令响应都没有**——
  NUS 是唯一会回话的通道，已排除「走错特征」这一因。
- **厂商 Demo 实测证明卡能流式下载**：同一张卡、同一个文件
  `2026-10-05-23-12-07.wav`，Demo 点「BLE 下载」后设备回一帧 14B（0x2D+ACK）
  → 0.6s 后**连续推 118 × 488 字节通知**。
- 于是对 `0x07` 载荷做了 10 种编码扫描（裸 ASCII 路径/裸文件名 × 大小 BE/LE/无/重复/
  十进制 ASCII/NUL 分隔/hex 编码路径），**全部只有 14B 或 6B 回执、零数据**。
  `0x30 [01]` 长按确认实测触发的是 `0x1B` 开始录音，与传输无关。
- 结论：蓝牙文件下载**不是厂商信息缺口，是我们与 Demo 之间还有一处差异未定位**，
  下一步只能从 Demo 的实际发出帧取证（HCI snoop 需 root 或 bugreport 附带）。
- 修掉探测台自身的两个假结论来源：`substring(44)` 越界把厂商特征订阅整段吃掉
  （改为按 UUID 末段取标签）；`setNotifyValue` 无超时会卡死 `connect()`
  （改为连接就绪后异步订阅 + 每条 4s 超时）。
- 79 例测试全绿，analyze 无 error/warning。

## Unreleased（2026-10-05 Xyrix SDK 联调第四轮：全命令面真机取证）

用新加的探测台 `lib/core/hardware/xyrix/xyrix_probe.dart`（`adb push` 一个
`xyrix_probe.txt` 即可分级驱动，不必重新出包）把 XyrixSDK-2 的 40 条命令逐条打到
真机（卡 SN 2606260101400084，固件 v2.0.13，NOH-AN00 / Android 12），结论写回命令表注释：

- **已实证**：0x01 电量 `[level,charging]`；0x17 版本；0x1A 卡状态 4 字节；
  0x2E 存储 = `[4B 总KB][4B 剩余KB]` 大端（读出 29.12/28.20 GB，占用 939 MB 与
  卡上 31 个 WAV 合计吻合）；0x13/0x1D 回 `2F` ACK
- **本版固件不响应**：0xFF 设备号（SN 仍取广播）、0x04 文件详情、0x20 开热点、
  0x11 隐藏热点；录音类 0x1B/0x1C/0x1F/0x50/0x52/0x53/0x32-0x35 **一律无回执**，
  写入即生效（故状态判定改看 0x54 推流与列表新增，不等回执）
- **修复（数据完整性）**：
  1. 实时音频首包丢失——捕获文件是异步打开的，现在打开期间的包先入队
  2. 实时流丢包不可见——按 0x54 序列号对账，缺口折算 `sizeMismatch` 上报，
     丢过包的 opus 绝不作为可用录音（真机 1102 包实测 0 缺口）
  3. 录音之后查询「无响应」的假象——路由器见过音频流后永久放弃按帧解码，
     现按通知边界识别完整控制帧（真机确实把 `0x21` 响应单独发一条通知）
  4. 能力清单谎报：`addMark` 声明了却必然抛异常 → 摘掉；`wifiTransfer` 实测在本卡上
     打不通 → 暂时摘掉（UI 不再摆必然失败的「快传」按钮，下载自动回 BLE）；
     `pauseResume`/`liveAudio` 实际可用却未声明 → 补上
- **录音快传（WiFi）在本卡上不成立**：0x21 只回状态字节 `FF 55 AA 01 21 01`，
  **不回传 SSID/密码**，且开完后手机连扫 25s 不见新 AP；0x11 按 空格/逗号/NUL/
  长度前缀 四种载荷编码全部无回执。当前实现的前提「设备经蓝牙下发凭证」是文档假设，
  实测不成立。已补 Android 侧 `dting/hotspot`（WifiNetworkSuggestion +
  CHANGE_WIFI_STATE），链路在拿到凭证规则后即刻可用；同时摘掉 `wifiTransfer`
  能力声明并让设备页不再渲染必然失败的「快传」按钮
- **蓝牙文件下载未通过（本轮唯一未闭环的必需功能）**：0x07→0x2D 之后设备**一字节
  都不下发**。已排除的变量：换文件（41KB / 43KB / 刚录出的 246KB）、录音后与空闲、
  拔插断电重启、`0x08`（空载荷）、`0x08`（带路径）、Telink `0x43`+`0x00 [08 00]`
  （这条拿到回执：状态 `03` + 未文档化的 `0xE0` 帧）。另注意 **0x2D 回的大小与
  App 在 0x07 里声明的完全一致**，更像回显而非「设备已备好文件」的确认，故
  `_onTransferReady` 的旧结论已标注为存疑，传输流程改用 `Config.dlMode` A/B，
  没有写死任何一种。失败路径是安全的：0 字节 → 报 `transferInterrupted`、
  丢弃 .part、绝不入库半成品
- 已知缺口：自动重连时 `DiscoveredDevice.manufacturerData` 为空 → 设备页 SN 显示
  `--`（SN 只在首次扫描时从广播解析出来，未持久化）
- 新增测试 8 例（存储字节布局、音频后控制帧、探测台分级隔离），全量 79 例

## 1.2.1 (2026-10-03)

### 重构：个人助手化（OpenMUSE UI 复刻）

产品转型：Lynse 从设备工具 app 转为以个人助手为核心，硬件录音/会议整理成为内置服务。第一版无账号纯本地。

- 全新信息架构：今日 / 录音 / 设备 / 任务 四 tab + 常驻助手输入条（点开全屏会话）
- 全新设计系统：复刻 OpenMUSE（MIT）tokens 与 12 个基础组件，浅色粉彩卡片风
- 助手对话：消息流 + 工具卡（设备状态/录音列表可跳转/任务进度）+ 追问建议 + 会话本地持久化；
  当前 Mock 后端用本地真数据应答，接口层预留 Lynse 后端切换
- 录音库：sqlite 索引替代目录扫描（存量文件自动入库），列表行内播放，来源/大小/日期展示
- 录音详情：新增播放条（进度拖拽/倍速），转写段落随播放进度高亮；转写/时间轴/纪要/编辑/导出保留
- 任务中心：下载/导入/转写/生成/固件统一状态机，实时进度 + 历史流水
- 底层：硬件抽象层平移 lib/core/（nv_easy_plugin 与旧 DtingStore 彻底解耦），
  sqlite 升 v3（五张新表），全局主题切换 AssistantTheme
- 删除：旧谛听记 UI/账号/支付/团队/积分约 300 文件（-58k 行），依赖从 70+ 收敛至 15

### New Features

- Xyrix BLE 下载闭环：0x07 后设备回 0x2D（4B 大小确认）自动下发数据的实测协议流程，
  5.3MB 真机文件完整验证（进度/速度/完成事件/断流看门狗）；通知路由重构为统一扫描器，
  列表/音频/控制帧任意交错可解析
- 已下载标识：设备文件下载后持久化标记，列表显示"已下载"并禁用重复下载；
  连接成功自动加载设备文件列表
- 传输入口按通道拆分：文件行点击默认蓝牙下载（实测稳定），"快传"按钮走 WiFi 热点+TCP；
  传输卡显示 MB 大小 + 百分比 + 速度
- 音频外传快传（Xyrix）：点击设备文件卡片即触发「BLE 开热点 → 手机连设备热点 → TCP 直传」，
  传输完成自动导入记录页并清理链路；建链阶段与传输进度均有 UI 反馈
- 设备文件列表体验：连接成功后自动拉取一次列表；停止录音后按 2s/6s/12s 轮询刷新
  （适配长录音保存耗时）；刷新超时有明确错误提示
- iOS 原生热点通道（NEHotspotConfigurationManager，dting/hotspot），
  Info.plist 增加本地网络权限描述

### Changed

- Xyrix 设备能力清单正式声明 wifiTransfer，控制层自动选择 WiFi 快传通道
- 设备文件列表点击动作改为「快传」（WiFi 通道），BLE 通道保留为回退路径

## 1.2.0 (2026-09-24)

### New Features

- Xyrix 设备录音文件蓝牙下载：传输进度、速度显示、完成后导入本地，支持取消与断流保护
- 录音实时音频流捕获：设备推送的 OPUS 音频自动保存为本地文件并在记录页显示
- 自动重连：再次打开 app 自动连接上次使用过的设备，无需重新扫描
- 停止录音后自动刷新设备文件列表

### Bug Fixes

- 修复设备录音文件列表不显示（结束帧被蓝牙通知边界切开导致解析卡死）
- 修复电量、固件版本等设备响应丢失（异常帧头堵死解析流，现可自动重新同步）
- 修复跳过登录模式下无法扫描蓝牙设备的问题

### Changed

- 蓝牙通知解析重构为可重放管线，新增真机抓包回归测试（38 个用例）
