/// Xyrix「音频外传快传」：设备热点 + TCP 通道文件传输会话。
///
/// 流程（对应命令表 XyrixCommands，顺序按 SDK 文档 §11「WiFi 文件传输时序」）：
/// 1. BLE 发 `openHotspotTcp`(0x21)：设备开热点并启动 TCP 服务。
///    2026-10-21 更正此前的错误结论（「这张卡根本没把 AP 拉起来」）：AP **确实会
///    广播**，只是两件事当时都判错了——
///    ① SSID 是 `AP_` + 一串数字（实测 20 字符），此前按厂商口语「AP26****」写成
///      截断正则 `AP[0-9A-Za-z]{2,14}`，名字被切短 → 入网被拒（Reason 1011）；
///    ② 观测用的是 `cmd wifi list-scan-results`，这张卡的 AP 从来不出现在那份结果里。
///      换成 `dumpsys wifi` 后立刻看到 `Wifi is connected to "AP_…"`、RSSI −32。
///    口令与 SSID 一样是**带外信息**（协议里没有「设备经蓝牙下发凭证」这一步，
///    文档 §8.11 明确 0x21 附加数据为空、只回一个状态字节），由计划文件 `ap=` 传入。
/// 2. 手机连热点（iOS NEHotspotConfiguration / Android WifiNetworkSuggestion，
///    见 hotspot_connector.dart；Android 侧要判「真连上了」得用 currentSsid，
///    建议提交成功 ≠ 连上）。手机若已在目标 AP 上则跳过重复提交。
/// 3. BLE 发 `wifiTransferResume`(0x46)：路径 + 4 字节大端断点偏移，触发推流。
/// 4. TCP 连设备。**判定标准是「谁真的推字节」，不是「谁接受了 connect」**：
///    真机上手机进了卡热点后仍能到家里路由器，`192.168.1.1:80` 握手成功却零字节，
///    光看连接成功会把路由器端口当成卡的服务器。文档默认端点 `192.168.1.80:5000`，
///    计划文件 `host=` 可把拨号范围收窄到明确地址。
/// 5. 收流：设备推的是**文件原始字节**，末尾追加 20 字节 `sendfile finish!`+NUL
///    作为收尾标记（见 [XyrixWifiStreamSplitter]，2026-10-21 与蓝牙下载的同一文件
///    逐字节对账过）。标记不写盘；看到它即判收满。
/// 6. 核对断点文件字节数，相符才改名为正式文件并上报导入（见
///    [TransferTarget.finalize]）；随后 BLE 发 `wifiTransferStop`(0x47)
///    + `closeWifi`(0x23) 收尾，并移除手机上的热点配置。
///
/// 实测吞吐（同一张卡、同一个 77,952 B 文件、同一台 Mate 40，2026-10-21）：
/// 蓝牙 887 ms ≈ **86 KB/s**；WiFi 快传从 0x46 到收尾标记 3.33 s ≈ **23 KB/s**
/// （纯收流段 2.10 s ≈ 34 KB/s），两条通道结果 SHA-256 相同。
/// ⚠️ 也就是说本版固件的「快传」**比蓝牙还慢一倍以上**，别按名字假设它快——
/// 选通道要按实测吞吐，或等大文件（几十 MB）场景再复测一次。
///
/// 「先 0x46 后连接」与「先连接后 0x46」两种时序在同一轮里都试（见 [run]），
/// 每轮各自记录收到的字节数——设备才是 TCP 服务端，哪种顺序才对只能由真机定。
/// 链路断掉（卡的 AP 会把手机 deauth）就按 0x46 的断点偏移续传，跑到收满为止。
///
/// 进度复用 [TransferProgressEvent]/[WifiStatusEvent]，UI 无需感知传输通道差异。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dting/config/config.dart';
import 'package:dting/core/hardware/hardware_event.dart';
import 'package:dting/core/hardware/models.dart';
import 'package:dting/core/hardware/transfer_target.dart';
import 'package:dting/core/hardware/xyrix/hotspot_connector.dart';
import 'package:dting/core/hardware/xyrix/xyrix_commands.dart';
import 'package:dting/core/hardware/xyrix/xyrix_frame_codec.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 热点凭证（0x21 响应帧解析结果）
class XyrixHotspotCredentials {
  final String ssid;
  final String password;

  /// 凭证帧若附带设备 IP/端口，TCP 直连时优先使用
  final String? ip;
  final int? port;

  const XyrixHotspotCredentials({
    required this.ssid,
    required this.password,
    this.ip,
    this.port,
  });

  /// 宽松解析：提取可打印 ASCII 后按空白/逗号分词——形如 x.x.x.x 的词
  /// 记为设备 IP，2-5 位纯数字词记为端口，其余按序取 SSID、密码。
  /// 固件实际格式联调确认后在此收严。
  ///
  /// 日志只留结构与 SSID：口令一旦进 logcat 就等于进了抓取件，
  /// 所以命中口令的位置一律打码后再打印。
  static XyrixHotspotCredentials? parse(List<int> data) {
    final text = ascii.decode(data, allowInvalid: true);
    final cleaned = text.replaceAll(RegExp(r'[^\x21-\x7e]'), ' ').trim();
    if (cleaned.isEmpty) return null;
    String? ssid, password, ip;
    int? port;
    for (final token in cleaned.split(RegExp(r'[\s,;]+'))) {
      if (token.isEmpty) continue;
      if (ip == null && RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(token)) {
        ip = token;
        continue;
      }
      if (port == null &&
          ssid != null &&
          RegExp(r'^\d{2,5}$').hasMatch(token) &&
          (int.tryParse(token) ?? 0) <= 65535) {
        port = int.parse(token);
        continue;
      }
      if (ssid == null) {
        ssid = token;
      } else {
        password ??= token;
      }
    }
    if (ssid == null) return null;
    var shown = cleaned;
    if (password != null && password.isNotEmpty) {
      shown = shown.replaceAll(password, '*' * password.length);
    }
    debugPrint('[Xyrix][WiFi] 热点凭证帧文本(口令已打码): "$shown"');
    return XyrixHotspotCredentials(
      ssid: ssid,
      password: password ?? '',
      ip: ip,
      port: port,
    );
  }

  /// 解析**带外**热点参数 `SSID:口令`（探测计划文件第二行 `ap=`）。
  ///
  /// 只按第一个冒号切：口令本身可能含冒号。没写冒号 = 开放网络。
  /// 空串返回 null，表示「没配带外参数」，调用方据此决定报什么错。
  static XyrixHotspotCredentials? parseApParams(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final i = s.indexOf(':');
    if (i < 0) return XyrixHotspotCredentials(ssid: s, password: '');
    final ssid = s.substring(0, i);
    if (ssid.isEmpty) return null;
    return XyrixHotspotCredentials(ssid: ssid, password: s.substring(i + 1));
  }
}

/// 一次 WiFi 快传会话（串行使用：adapter 保证同一时刻只有一个会话）
class XyrixWifiTransferSession {
  final RecordingFile file;

  /// BLE 控制通道（0x21/0x46/0x47/0x23 都走蓝牙发）
  final Future<void> Function(int command, [List<int> data]) sendCommand;

  /// 事件出口（进度 / 链路状态 / 导入完成），adapter 转发到统一事件流
  final void Function(HardwareEvent event) emit;

  final HotspotConnector hotspotConnector;

  /// 是否复用磁盘上的未完成断点（0x46 携带字节偏移，本协议通道支持续传）
  final bool resume;

  /// 凭证等待期：设备对 0x21 的响应帧从 BLE 通知解析进来
  final Completer<XyrixHotspotCredentials> _credentials =
      Completer<XyrixHotspotCredentials>();

  XyrixHotspotCredentials? _creds;
  TransferTarget? _target;

  /// 一行实测结论，`run()` 返回后给探测台读（走的是 emit 之外的旁路，
  /// 免得为了取个结果去反推事件流）
  String verdict = '未产生结果';

  /// 每种时序各自收到多少字节——失败时的定位价值全在这几行里
  final List<String> _ordersTried = [];

  IOSink? _sink;
  Socket? _socket;

  /// 当前存活的数据通道探测结果（承载监听与缓冲，见 [_TcpProbe]）
  _TcpProbe? _probe;

  /// 断点字节数：本次传输的起点，也是进度条的起点
  int _resumeOffset = 0;
  int get _received => _resumeOffset + _newBytes;
  int _newBytes = 0;
  int get _total => file.sizeBytes;
  DateTime _startTime = DateTime.now();
  DateTime _lastProgressEmit = DateTime.fromMillisecondsSinceEpoch(0);
  bool _finished = false;
  TransferIntegrity? _lastIntegrity;

  /// TCP 数据断流看门狗：这么久无字节视为传输中断。取值要能容下
  /// 「先连接、后发 0x46」这种时序里设备的启动耗时
  Timer? _stallTimer;
  static const _stallTimeout = Duration(seconds: 20);

  /// 「先 0x46 后连接」时，等某个端点真的推出第一个字节的观察窗口
  static const _firstByteGrace = Duration(seconds: 12);

  /// 续传轮数上限。真机实测卡的 AP 会在推出约 27 KB 后把手机 deauth 掉，
  /// 一张 78 KB 的文件要 3~4 轮；上限取 10，够跑完一张典型录音，
  /// 又不至于在链路真的坏了时无限重试。
  static const _maxRounds = 10;

  /// 设备热点网段常见默认端口。5000 是 SDK 文档 tcpConnect() 的默认端口，
  /// 必须排第一（2026-10-06 拿到 XyrixSDK-2 文档才确认，此前我们从未试过它）
  static const _candidatePorts = [5000, 8080, 2222, 8888, 8090, 9000, 80];

  XyrixWifiTransferSession({
    required this.file,
    required this.sendCommand,
    required this.emit,
    required this.hotspotConnector,
    this.resume = true,
  });

  /// 设备对 0x21/0x20 的响应帧（由 adapter 从通知流分发进来）
  void onHotspotCredentialsFrame(Uint8List data) {
    final creds = XyrixHotspotCredentials.parse(data);
    if (creds != null && !_credentials.isCompleted) {
      _credentials.complete(creds);
    }
  }

  Future<void> run() async {
    _startTime = DateTime.now();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final target = TransferTarget.inDirectory(
        dir,
        file.name,
        prefix: 'xyrix_wifi_',
      );
      _target = target;
      if (!resume) {
        // 明确不续传：必须先清掉残留断点，否则 append 会把「设备从 0 重发的
        // 完整文件」接在旧字节后面，长度必然对不上而白传一趟
        await target.discard();
      }
      _resumeOffset = resume ? await target.resumeOffset() : 0;
      // 断点比文件还大 = 设备侧这个路径已经换了内容，断点作废
      if (_total > 0 && _resumeOffset > _total) {
        debugPrint('[Xyrix][WiFi] 断点 $_resumeOffset 超出文件大小 $_total，丢弃');
        await target.discard();
        _resumeOffset = 0;
      }
      if (_resumeOffset > 0) {
        debugPrint('[Xyrix][WiFi] 从断点 $_resumeOffset/$_total 续传 ${file.name}');
      }
      _sink = target.partFile.openWrite(mode: FileMode.append);

      // 断点已经到文件大小 = 上一轮其实收满了（多出来的收尾标记当年被误判成污染，
      // 于是断点留在完整长度上）。这种情况直接结算，不必再拨号——
      // 设备对越界偏移只会回那 20 字节标记，问多少次都是它。
      if (_total > 0 && _resumeOffset >= _total) {
        debugPrint('[Xyrix][WiFi] 断点 $_resumeOffset 已达文件大小 $_total，直接收尾');
        await _finish(TransferState.completed);
        return;
      }

      // ---- 1&2. BLE 开热点 + 手机入网 ----
      await _openLink();

      // ---- 3~5. 触发推流 → 建 TCP 链 → 收流落盘（断一轮就续一轮，直到收满）----
      // 2026-10-21 真机定案：卡的 TCP 服务器就在**文档默认端点 192.168.1.80:5000**，
      // 0x46 之后 1 秒内推出 27,360 B，随后卡的 AP 把手机 deauth 掉
      // （wpa_supplicant `CTRL-EVENT-DISCONNECTED bssid=80:45:6b:… reason=6`），
      // 手机立刻漫游回有互联网的家用网。所以这条链路**天生会断、必须能续**——
      // 0x46 本来就带 4 字节断点偏移，一轮拿一段、偏移往前推，跑到收满为止，
      // 而不是把一次断流当整次失败。
      Object? lastError;
      var triggerFirst = true; // 先按文档时序；同一时序连续零进展才换另一种
      var noProgress = 0;
      for (var round = 1; round <= _maxRounds; round++) {
        final label = triggerFirst ? '0x46→TCP' : 'TCP→0x46';
        try {
          if (round > 1) await _relink();
          await _transferOnce(triggerFirst: triggerFirst);
          lastError = null;
          if (round > 1) {
            debugPrint('[Xyrix][WiFi] 第 $round 轮续传收满 $_received/$_total');
          }
          break;
        } catch (e) {
          lastError = e;
          final got = _newBytes;
          _ordersTried.add('R$round/$label +$got B');
          debugPrint('[Xyrix][WiFi] 第 $round 轮($label)未收满，本轮 +$got B: $e');
          // 本轮落盘的字节并进断点，下一轮用新的 0x46 偏移续传
          _resumeOffset += got;
          _newBytes = 0;
          if (got == 0) {
            noProgress++;
            // 连续两轮一个字节都没有，才怀疑是时序问题，换一种顺序再试
            if (noProgress >= 2) {
              triggerFirst = !triggerFirst;
              noProgress = 0;
              debugPrint('[Xyrix][WiFi] 换时序为 ${triggerFirst ? "0x46→TCP" : "TCP→0x46"}');
            }
          } else {
            noProgress = 0; // 有进展 = 时序是对的，只是链路断了，继续往前推
          }
          await _resetPush();
        }
      }
      if (lastError != null) throw lastError;
      await _finish(TransferState.completed);
    } catch (e) {
      await _finish(
        TransferState.failed,
        error: e,
        stopIntent: TransferStopIntent.interrupted,
      );
    } finally {
      await _teardown();
    }
  }

  /// 1~2 步：让设备开热点并把手机送进那个 AP，拿到可用的 SSID/口令。
  ///
  /// 口令来源优先级：设备经 0x21 响应回传（协议里其实没有这一步，留着是因为
  /// 万一某版固件真推）→ 计划文件 `ap=SSID:密码` 带外参数 → 明确报缺参数。
  /// 替身服务器（`tcp=`）仍然支持：它专门验数据通路本身，不用真机就能反复跑。
  Future<void> _openLink() async {
    final override = Config.wifiServerOverride;
    if (override.isNotEmpty) {
      final sp = override.split(':');
      _creds = XyrixHotspotCredentials(
        ssid: '',
        password: '',
        ip: sp.first,
        port: int.tryParse(sp.length > 1 ? sp.last : '') ??
            _candidatePorts.first,
      );
      debugPrint(
        '[Xyrix][WiFi] 替身服务器 ${_creds!.ip}:${_creds!.port}，'
        '跳过开热点与入网，只验数据通路',
      );
      _linkPhase(WifiTransferStatus.connected);
      return;
    }

    _linkPhase(WifiTransferStatus.opening);
    await sendCommand(XyrixCommands.openHotspotTcp);
    // 只等一帧凭证（实测 0x21 只回 `FF 55 AA 01 21 01` 一个状态字节），
    // 拿不到就用带外参数，不再用长超时冒充「设备不支持」。
    _creds = await _credentials.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () => const XyrixHotspotCredentials(ssid: '', password: ''),
    );
    var ssid = _creds!.ssid;
    var password = _creds!.password;
    var ip = _creds!.ip;
    var port = _creds!.port;
    if (ssid.isEmpty) {
      final ap = XyrixHotspotCredentials.parseApParams(Config.wifiApCredential);
      if (ap == null) {
        throw HardwareException(
          HardwareErrorCode.unsupportedCapability,
          '设备不回传热点 SSID/密码（0x21 仅回状态字节），且计划文件没给带外参数'
          '——第二行补 `ap=AP_xxx:口令` 即可走真实热点链路',
        );
      }
      ssid = ap.ssid;
      password = ap.password;
      debugPrint(
        '[Xyrix][WiFi] 热点凭证走带外参数: ssid=$ssid '
        '口令长度=${password.length}（设备侧不回传）',
      );
    } else {
      debugPrint('[Xyrix][WiFi] 热点凭证来自设备响应帧: ssid=$ssid');
    }
    final target = Config.wifiTcpTarget;
    if (target.isNotEmpty) {
      ip = target.split(':').first;
      if (target.contains(':')) {
        port = int.tryParse(target.split(':').last) ?? port;
      }
    }
    _creds = XyrixHotspotCredentials(
      ssid: ssid,
      password: password,
      ip: ip,
      port: port,
    );
    _linkPhase(WifiTransferStatus.opened);

    // 手机已经在目标 AP 上（联调时常用 adb `cmd wifi connect-network` 先入网）
    // 就别再提交一遍建议——重复提交反而可能被系统忽略。
    final cur = await hotspotConnector.currentSsid();
    if (cur.linked && cur.ssid == ssid) {
      debugPrint('[Xyrix][WiFi] 手机已在 $ssid，跳过入网');
      _linkPhase(WifiTransferStatus.connected);
      return;
    }
    _linkPhase(WifiTransferStatus.connecting);
    await hotspotConnector.connect(ssid, password);
    // 「系统收下建议」≠「真的连上了」：轮询到连上为止，等不到就如实报
    final until = DateTime.now().add(const Duration(seconds: 20));
    var last = cur.ssid;
    while (DateTime.now().isBefore(until)) {
      final r = await hotspotConnector.currentSsid();
      last = r.ssid;
      if (r.linked && r.ssid == ssid) {
        // DHCP 拿到地址要一点时间，早一秒拨号就多一次假失败
        await Future.delayed(const Duration(milliseconds: 1200));
        debugPrint('[Xyrix][WiFi] 已入网 $ssid');
        _linkPhase(WifiTransferStatus.connected);
        return;
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    throw HardwareException(
      HardwareErrorCode.connectionLost,
      '手机未能进入设备热点（仍在 "${last.isEmpty ? "未知" : last}"，'
      '目标 $ssid）。Android 网络建议可能要用户在通知里确认，'
      '或改用 adb cmd wifi connect-network 预连',
    );
  }

  /// 一种时序的完整一遍：触发 + 建链 + 收流。
  Future<void> _transferOnce({required bool triggerFirst}) async {
    if (triggerFirst) await _sendTrigger();
    final probe = await _dial(trigger: triggerFirst ? null : _sendTrigger);
    _probe = probe;
    _socket = probe.socket;
    _linkPhase(WifiTransferStatus.connected);
    debugPrint(
      '[Xyrix][WiFi] TCP 选中 ${probe.host}:${probe.port} '
      '（时序 ${triggerFirst ? "0x46→TCP" : "TCP→0x46"}，建链窗口内已推 ${probe.bytes} B）',
    );
    await _receive(probe);
  }

  /// 3 步：BLE 发 0x46（路径 + 4 字节大端断点偏移），设备从该偏移起经 TCP 推送
  Future<void> _sendTrigger() async {
    final data = XyrixFrameCodec.wifiResumeData(
      '0:/${file.name}',
      _resumeOffset,
    );
    debugPrint(
      '[Xyrix][WiFi] 触发推流 0x46 path=0:/${file.name} offset=$_resumeOffset '
      'data=${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );
    await sendCommand(XyrixCommands.wifiTransferResume, data);
    _emitProgress(TransferState.transferring, force: true);
  }

  /// 换时序前先让设备停一下当前推流（0x47）。失败吞掉：这一步不通
  /// 不该掩盖「两种顺序都没字节」这个真正的结论。
  Future<void> _resetPush() async {
    try {
      await sendCommand(XyrixCommands.wifiTransferStop);
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 2));
  }

  /// 断链重来：重新发 0x21（TCP 服务器随热点一起起），再等手机回到卡的 AP。
  ///
  /// 手机被 deauth 后会自己漫游回有互联网的家用网，所以「等」是必须的，
  /// 不是可选的优化。等不到就如实中止——偏移已经推进到磁盘上的真实长度，
  /// 下一次会话从断点接着传，不会把已收到的字节再要一遍。
  Future<void> _relink({int seconds = 30}) async {
    final ssid = _creds?.ssid ?? '';
    if (ssid.isEmpty) return; // 替身服务器模式没有 AP 可等
    await sendCommand(XyrixCommands.openHotspotTcp);
    final until = DateTime.now().add(Duration(seconds: seconds));
    var now = '';
    while (DateTime.now().isBefore(until)) {
      final r = await hotspotConnector.currentSsid();
      now = r.ssid;
      if (r.linked && r.ssid == ssid) {
        // DHCP 重新拿地址要一点时间，早一秒拨号就多一次假失败
        await Future.delayed(const Duration(milliseconds: 1500));
        debugPrint('[Xyrix][WiFi] 手机已回到 $ssid，从 offset=$_resumeOffset 续传');
        return;
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    throw HardwareException(
      HardwareErrorCode.connectionLost,
      '断链后 ${seconds}s 内手机没回到设备热点（当前 "$now"），'
      '续传中止（已收 $_received/$_total，偏移已落盘）',
    );
  }

  /// 4 步：建 TCP 链，**判定标准是「谁真的推了字节」，不是「谁接受了 connect」**。
  ///
  /// 这条判据是真机踩出来的：手机进了卡的 AP 之后仍能走到家里路由器，
  /// `192.168.1.1:80` 三次握手成功却一个字节都不推。旧实现「取第一个连上的
  /// socket」会把路由器端口当成卡的服务器，然后 15 秒空等，得出
  /// 「设备不推流」的假结论。所以候选端点并发拨号、并发听，
  /// 只有先推出字节的才留下，其余一律关掉，并把每个端点的下场记进日志。
  ///
  /// [trigger] 非空时在「连接已建好」这一刻发 0x46，用来覆盖
  /// 「先连接、后触发」这种时序；两种时序共用同一套按字节定胜负的选路逻辑，
  /// 不会出现「连上了错端点，只好瞎猜」的情况。
  Future<_TcpProbe> _dial({Future<void> Function()? trigger}) async {
    final hosts = await _candidateHosts();
    final ports = _candidatePortList();
    final combos = <(String, int)>[
      for (final host in hosts)
        for (final port in ports) (host, port),
    ];
    debugPrint('[Xyrix][WiFi] TCP 候选 ${combos.length} 个: '
        '${combos.map((c) => '${c.$1}:${c.$2}').join(', ')}');

    final probes = <_TcpProbe>[];
    await Future.wait(combos.map((c) async {
      final p = _TcpProbe(c.$1, c.$2);
      probes.add(p);
      Socket s;
      try {
        s = await Socket.connect(
          c.$1,
          c.$2,
          timeout: const Duration(seconds: 4),
        );
      } catch (e) {
        p.note = '连不上 ${e.toString().split('\n').first.trim()}';
        return;
      }
      p.socket = s;
      p.note = '已连接，无数据';
      p.attach();
    }));

    final connected = probes.where((p) => p.socket != null).toList();
    if (connected.isEmpty) {
      for (final p in probes) {
        p.cancel();
      }
      throw HardwareException(
        HardwareErrorCode.connectionLost,
        'TCP 候选端点全部连不上（${probes.length} 个），'
        '请确认手机已连上设备热点且拿到了同网段地址',
      );
    }

    // 连接就绪后才触发，随后统一在同一个窗口里看谁先推字节
    if (trigger != null) await trigger();
    final until = DateTime.now().add(_firstByteGrace);
    while (DateTime.now().isBefore(until)) {
      if (probes.any((p) => p.bytes > 0)) break;
      // 连上的端点全提前收尾了，就没必要把窗口等满
      if (connected.every((p) => p.earlyDone || p.earlyError != null)) break;
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _TcpProbe? winner;
    for (final p in probes) {
      if (p.bytes > 0) {
        winner = p;
        break;
      }
    }
    for (final p in probes) {
      if (!identical(p, winner)) p.cancel();
    }
    debugPrint(
      '[Xyrix][WiFi] TCP 下场: '
      '${probes.map((p) => '${p.host}:${p.port}=${p.note}').join(' | ')}',
    );
    if (winner == null) {
      throw HardwareException(
        HardwareErrorCode.connectionLost,
        '已发 0x46，但 ${probes.length} 个候选端点没有推出任何字节'
        '（连上的 ${connected.length} 个）——要么 IP/端口不对'
        '（计划文件补 `host=ip:port` 收窄），要么设备不认这条触发',
      );
    }
    winner.note = '先推 ${winner.bytes} B';
    return winner;
  }

  /// 端口列表：明确指定了就只拨它，没指定才扫常见端口
  List<int> _candidatePortList() {
    final p = _creds?.port;
    if (Config.wifiTcpTarget.isNotEmpty) {
      if (p != null) return [p];
      // 收窄到单个 IP 后扫描是安全的（不会再打到别的主机），保留常见端口试探
      return _candidatePorts;
    }
    return [if (p != null) p, ..._candidatePorts];
  }

  /// TCP 候选地址。计划文件 `host=` 给了就**只拨这一个**——收窄的意义正在于
  /// 此：不收窄就无法排除家里路由器那个「握手成功但零字节」的假端点。
  /// 没给才按凭证帧 IP → 本机网段网关（.1）→ 厂商常见默认段推。
  Future<List<String>> _candidateHosts() async {
    final explicit = Config.wifiTcpTarget.split(':').first.trim();
    if (explicit.isNotEmpty) return [explicit];
    final hosts = <String>[if (_creds?.ip != null) _creds!.ip!];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4 && !addr.isLoopback) {
            final gw = '${parts[0]}.${parts[1]}.${parts[2]}.1';
            if (!hosts.contains(gw)) hosts.add(gw);
          }
        }
      }
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4 && !addr.isLoopback && !hosts.contains(addr.address)) {
            hosts.add(addr.address);
          }
        }
      }
    } catch (_) {}
    for (final fallback in const [
      '192.168.1.80',
      '192.168.4.1',
      '192.168.1.1',
    ]) {
      if (!hosts.contains(fallback)) hosts.add(fallback);
    }
    return hosts;
  }

  /// 5 步：把选中端点的数据流落盘并判定完整性。
  ///
  /// 监听在 [_dial] 里就已经挂上（探测期缓冲），这里只做「装回调 + 补缓冲」，
  /// 两步在同一个同步块里完成——Dart 单线程事件循环保证两者之间不会插入新数据，
  /// 所以每个字节恰好进 [handler] 一次：既不会漏，也不会重。
  Future<void> _receive(_TcpProbe probe) async {
    final done = Completer<void>();
    final splitter = XyrixWifiStreamSplitter();

    void settle(Object? error) {
      if (done.isCompleted) return;
      if (error == null) {
        done.complete();
      } else {
        done.completeError(error);
      }
    }

    void handler(Uint8List data) {
      _stallTimer?.cancel();
      // 收尾标记不算文件字节：设备推完最后一块会原样追加 sendfile finish!
      final fileBytes = splitter.feed(data);
      if (fileBytes.isNotEmpty) {
        _sink?.add(fileBytes);
        _newBytes += fileBytes.length;
      }
      _stallTimer = Timer(_stallTimeout, () {
        settle(TimeoutException('TCP 数据断流 ${_stallTimeout.inSeconds} 秒'));
      });
      if (!_finished) _emitProgress(TransferState.transferring);
      if (splitter.finished) {
        debugPrint('[Xyrix][WiFi] 收到 sendfile finish! 收尾标记，收流');
        settle(null);
        return;
      }
      if (_total > 0 && _received > _total) {
        // 没有标记却超出文件大小 = 真有别的字节混进来了，内容不可信
        settle(
          HardwareException(
            HardwareErrorCode.integrityMismatch,
            '收到字节超出文件大小（$_received/$_total）且未见收尾标记，数据流被污染',
          ),
        );
        return;
      }
      if (_total > 0 && _received >= _total) settle(null);
    }

    probe.onData = handler;
    probe.onEnd = (error) {
      if (error != null) {
        settle(error);
        return;
      }
      if (_total <= 0 || _received >= _total) {
        settle(null);
      } else {
        settle(
          HardwareException(
            HardwareErrorCode.transferInterrupted,
            '设备提前断开连接（已收 $_received/$_total 字节）',
          ),
        );
      }
    };
    final pending = probe.takePending();
    if (pending.isNotEmpty) handler(pending);
    // 探测期间就可能已经收尾（推完就关连接），这些状态要在这里结算，不能丢
    if (probe.earlyError != null) {
      settle(probe.earlyError);
    } else if (probe.earlyDone) {
      probe.onEnd!(null);
    }
    if (!done.isCompleted && _total > 0 && _received >= _total) settle(null);
    if (!done.isCompleted) {
      _stallTimer?.cancel();
      _stallTimer = Timer(_stallTimeout, () {
        settle(TimeoutException('TCP 无数据（首字节等 ${_stallTimeout.inSeconds} 秒）'));
      });
    }
    try {
      await done.future;
    } finally {
      _stallTimer?.cancel();
      probe.cancel();
      _probe = null;
      _socket = null;
    }
  }

  Future<void> _finish(
    TransferState state, {
    Object? error,
    TransferStopIntent stopIntent = TransferStopIntent.none,
  }) async {
    if (_finished) return;
    _finished = true;
    final target = _target;
    final sink = _sink;
    _sink = null;
    _target = null;
    TransferOutcome? outcome;
    if (sink != null && target != null) {
      outcome = await target.finalize(
        sink,
        state == TransferState.completed ? _total : 0,
      );
      _lastIntegrity = outcome.integrity;
    }
    if (error != null) {
      verdict =
          '失败 state=$state received=$_received/$_total '
          '[${_ordersTried.join(' / ')}]：$error';
      debugPrint('[Xyrix][WiFi] 快传失败 received=$_received/$_total: $error');
    } else {
      verdict =
          'state=$state received=$_received/$_total '
          '[${_ordersTried.isEmpty ? "首轮即成功" : _ordersTried.join(' / ')}] '
          'integrity=${outcome?.integrity ?? _lastIntegrity} → ${outcome?.filePath}';
      debugPrint(
        '[Xyrix][WiFi] 快传结束 state=$state intent=$stopIntent '
        'received=$_received/$_total $outcome',
      );
    }
    _emitProgress(state, force: true);
    if (outcome != null && outcome.trusted) {
      emit(
        FileImportedEvent(
          ImportedRecording(
            filePath: outcome.filePath,
            recordStartTime: file.startTime,
            fileSn: file.sn,
            deviceFileName: file.name,
            scene: file.scene,
            expectedBytes: outcome.expectedBytes,
            actualBytes: outcome.actualBytes,
            integrity: outcome.integrity,
          ),
        ),
      );
      return;
    }
    if (stopIntent == TransferStopIntent.userCancelled) {
      await target?.discard();
      return;
    }
    if (state == TransferState.failed) {
      // 校验/链路未通过：断点留在磁盘上供下次 0x46 续传，但绝不作为录音上报
      if (outcome != null &&
          outcome.integrity == TransferIntegrity.sizeMismatch) {
        await target?.discard();
      }
      final hError = error is HardwareException ? error : null;
      var detail = hError?.message ?? '$error';
      if (detail.isEmpty || detail == 'null') {
        detail = '快传未完成（已收 $_received/$_total 字节）';
      }
      emit(
        HardwareErrorEvent(
          hError?.code ?? HardwareErrorCode.transferInterrupted,
          detail,
        ),
      );
    }
  }

  /// 收尾：停传输 + 关设备热点 + 移除手机热点配置。
  /// BLE 可能已断（快传不依赖蓝牙保活），所有命令失败都吞掉。
  Future<void> _teardown() async {
    _linkPhase(WifiTransferStatus.stopping);
    _stallTimer?.cancel();
    _probe?.cancel();
    _probe = null;
    try {
      await sendCommand(XyrixCommands.wifiTransferStop);
    } catch (_) {}
    try {
      await sendCommand(XyrixCommands.closeWifi);
    } catch (_) {}
    await hotspotConnector.disconnect(_creds?.ssid ?? '');
    _linkPhase(WifiTransferStatus.stopped);
  }

  void _linkPhase(WifiTransferStatus status) {
    debugPrint('[Xyrix][WiFi] 链路状态 → $status');
    emit(WifiStatusEvent(status));
  }

  void _emitProgress(TransferState state, {bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        now.difference(_lastProgressEmit) < const Duration(milliseconds: 250)) {
      return;
    }
    _lastProgressEmit = now;
    final total = _total;
    final received = _received;
    final elapsedSec = now.difference(_startTime).inMilliseconds / 1000.0;
    final speedKbps =
        elapsedSec > 0.2 ? (received / 1024 / elapsedSec).round() : 0;
    emit(
      TransferProgressEvent(
        TransferProgress(
          state: state,
          receivedBytes: received,
          totalBytes: total,
          totalPacket: total > 0 ? (total / 512).ceil() : 1,
          currentPacket: total > 0 ? (received / 512).ceil() : 0,
          speedKbps: speedKbps,
          integrity:
              state == TransferState.transferring ? null : _lastIntegrity,
        ),
        fileSn: file.sn,
      ),
    );
  }

  /// 用户主动取消：终止链路并丢弃断点（区别于 [abort] 的意外中断保留）。
  Future<void> cancel() async {
    _socket?.destroy();
    _stallTimer?.cancel();
    await _finish(
      TransferState.cancelled,
      stopIntent: TransferStopIntent.userCancelled,
    );
    await _teardown();
  }

  /// 外部强制终止（适配器销毁/断连时调用）：保留断点供下次续传
  Future<void> abort() async {
    _socket?.destroy();
    _stallTimer?.cancel();
    await _finish(
      TransferState.failed,
      stopIntent: TransferStopIntent.interrupted,
      error: HardwareException(
        HardwareErrorCode.transferInterrupted,
        '传输被强制终止',
      ),
    );
    await _teardown();
  }
}

/// 把设备推来的 TCP 流切成「文件字节」与「收尾标记」两段。
///
/// 2026-10-21 真机定案（`2026-10-19-22-10-43.wav`，设备报 77,952 B）：
/// 设备经 `192.168.1.80:5000` 推来的流 = **文件原始字节**（与蓝牙下载到的
/// 同一文件逐字节相同，SHA-256 `e1ab7a99…b135a1` 一致），
/// 末尾再原样追加 20 字节 ASCII 收尾标记 `sendfile finish!` + 4 个 NUL。
///
/// 这既不是帧头也不是分块长度，就是 sendfile 循环跑完的标志。此前把它算进
/// 文件字节，于是 `_received > sizeBytes` 判成「数据流被污染」，一次**已经
/// 成功**的快传被自己判死；断点越界时设备只回这 20 字节，又被当成新一轮的
/// 过收。所以按标记收流：看到它就结算，标记之后的字节一律不写盘。
class XyrixWifiStreamSplitter {
  /// 设备原样追加的收尾标记（16 字符 + 4 字节 NUL 填充 = 20 B）
  static const List<int> trailer = <int>[
    0x73, 0x65, 0x6e, 0x64, 0x66, 0x69, 0x6c, 0x65, // sendfile
    0x20, 0x66, 0x69, 0x6e, 0x69, 0x73, 0x68, 0x21, // ' finish!'
    0x00, 0x00, 0x00, 0x00,
  ];

  final List<int> _tail = <int>[];
  bool _finished = false;

  /// 收到过标记 = 设备说这个文件推完了
  bool get finished => _finished;

  /// 喂入一段流字节，返回其中**属于文件**、应当写盘的部分。
  ///
  /// 标记可能被 TCP 切成任意两段，所以始终留 `trailer.length - 1` 字节的尾巴
  /// 不参与写盘，等下一段再判——留到下一轮的字节要么是标记的前缀，
  /// 要么下一轮就被吐出来，不会丢也不会重。
  Uint8List feed(List<int> data) {
    if (_finished) return Uint8List(0);
    final buf = BytesBuilder(copy: false)
      ..add(_tail)
      ..add(data);
    final all = buf.takeBytes();
    final idx = _indexOf(all, trailer);
    if (idx >= 0) {
      _finished = true;
      _tail.clear();
      return Uint8List.sublistView(all, 0, idx);
    }
    final keep = trailer.length - 1;
    if (all.length <= keep) {
      _tail
        ..clear()
        ..addAll(all);
      return Uint8List(0);
    }
    _tail
      ..clear()
      ..addAll(Uint8List.sublistView(all, all.length - keep));
    return Uint8List.sublistView(all, 0, all.length - keep);
  }

  static int _indexOf(List<int> haystack, List<int> needle) {
    outer:
    for (var i = 0; i + needle.length <= haystack.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }
}

/// 一个 TCP 候选端点的探测状态。
///
/// 存在的理由是「建链」和「收流」之间不能有空档：候选端点并发拨号时，
/// 真正推流的那个可能在我们选定赢家之前就把前几百字节推完，若此时还没挂
/// 监听，这些字节就丢了——快传要的是逐字节可比对的文件，丢头就等于白传。
/// 所以监听在 connect 成功那一刻就挂上（[attach]），没装业务回调之前
/// 一律先进 [_pending] 缓冲，[_receive] 装好回调后再一次性取出补交。
class _TcpProbe {
  _TcpProbe(this.host, this.port);

  final String host;
  final int port;
  Socket? socket;
  StreamSubscription<Uint8List>? _sub;
  final BytesBuilder _pending = BytesBuilder(copy: false);

  /// 累计收到的字节数（含缓冲里的），选赢家与写结论都看它
  int bytes = 0;

  /// 一行下场，用于「N 个端点各自怎么样了」这种定位
  String note = '未连接';

  void Function(Uint8List data)? onData;
  void Function(Object? error)? onEnd;

  /// 流在探测窗口内就结束了：两者都要留给 [_receive] 结算，不能当没发生
  bool earlyDone = false;
  Object? earlyError;

  /// 挂监听。回调在 onData 装上之前只缓冲，装上之后直通。
  /// Dart 单线程，bytes 自增与两种投递路径互斥，字节不会重复计数。
  void attach() {
    final s = socket;
    if (s == null) return;
    _sub = s.listen(
      (data) {
        bytes += data.length;
        if (onData != null) {
          onData!(data);
        } else {
          _pending.add(data);
        }
      },
      onError: (Object e) {
        note = '读失败 ${e.toString().split('\n').first.trim()}';
        earlyError = e;
        if (onEnd != null) onEnd!(e);
      },
      onDone: () {
        earlyDone = true;
        if (onEnd != null) onEnd!(null);
      },
      cancelOnError: true,
    );
  }

  /// 取走探测期缓冲的字节（调用方随即装上 onData，两步之间不会有新数据）
  Uint8List takePending() => _pending.takeBytes();

  void cancel() {
    onData = null;
    onEnd = null;
    final s = socket;
    socket = null;
    final sub = _sub;
    _sub = null;
    try {
      sub?.cancel();
    } catch (_) {}
    try {
      s?.destroy();
    } catch (_) {}
  }
}
