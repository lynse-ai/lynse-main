/// Xyrix「音频外传快传」：设备热点 + TCP 通道文件传输会话。
///
/// 流程（对应命令表 XyrixCommands，顺序按 SDK 文档 §11「WiFi 文件传输时序」）：
/// 1. BLE 发 `openHotspotTcp`(0x21)：设备开热点并启动 TCP 服务。
///    ⛔ **2026-10-06 双判据实测：这张卡根本没把 AP 拉起来，整条链路无法自证**。
///    试了 9 种发法（`0x11` 载荷 = 空格/逗号/NUL/长度前缀 4 种编码 × 「0x11+0x21」
///    与「0x21 直接带载荷」两种发法，外加「0xF1 工厂写 WiFi 凭证 → 0x21」），
///    每轮之后同时看两个与设备无关的外部观测：
///    ① 手机上「已保存的隐藏网络 LYNSEXY」能不能自动连上（`cmd wifi` 建的，
///      绕开 App 网络建议可能被系统无视这个坑）；
///    ② `cmd wifi list-scan-results` 每 6s 采一次，43 次采样里 AP 集合从未变化。
///    两路全负。`0x21/0x23` 回的那帧 `[01]` 是通用「命令收到」——`0x23 关 WiFi`
///    回的是一模一样的形状，所以它证明不了热点开起来了。
///    协议里也没有「设备下发 SSID/密码」这一步，缺的是厂商的热点启用规则。
///    **厂商 Demo 与此一致**：`com.xyrix.ble_demo`「文件传输」页使用说明写的是
///    「TCP 下载需先手动连接 Wi-Fi 热点，再连接 TCP」，TCP 页只预填
///    `192.168.1.80:5000` 等用户点连接——Demo 同样不通过 BLE 设凭证，
///    可见 SSID/密码在厂商体系里是**带外信息**（机身标签 / 硬件手册）。
///    还排掉一种「卡早就在局域网上、根本不用开热点」的可能：PC 与手机同在
///    192.168.1.0/24，`ping 192.168.1.80` 100% 丢包、`Test-NetConnection -Port 5000`
///    返回 False、ARP 表里没有 c4:22:4e 前缀的 MAC——卡从未上过这个网段。
/// 2. 手机连热点（iOS NEHotspotConfiguration / Android WifiNetworkSuggestion，
///    见 hotspot_connector.dart；Android 侧要判「真连上了」得用 currentSsid，
///    建议提交成功 ≠ 连上）。
/// 3. BLE 发 `wifiTransferResume`(0x46)：路径 + 4 字节大端断点偏移，触发推流。
/// 4. TCP 连设备：文档默认 **192.168.1.80:5000**（此前我们从未试过这个端点），
///    凭证帧若带 IP/端口则优先用它，否则再按本机网段网关与常见端口探测。
/// 5. 收满 `sizeBytes` 后核对断点文件字节数，相符才改名为正式文件并上报
///    导入（见 [TransferTarget.finalize]）；随后 BLE 发 `wifiTransferStop`(0x47)
///    + `closeWifi`(0x23) 收尾，并移除手机上的热点配置。
///
/// 进度复用 [TransferProgressEvent]/[WifiStatusEvent]，UI 无需感知传输通道差异。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  static XyrixHotspotCredentials? parse(List<int> data) {
    final text = ascii.decode(data, allowInvalid: true);
    final cleaned = text.replaceAll(RegExp(r'[^\x21-\x7e]'), ' ').trim();
    if (cleaned.isEmpty) return null;
    debugPrint('[Xyrix][WiFi] 热点凭证帧原始文本: "$cleaned"');
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
    return XyrixHotspotCredentials(
      ssid: ssid,
      password: password ?? '',
      ip: ip,
      port: port,
    );
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
  IOSink? _sink;
  Socket? _socket;

  /// 断点字节数：本次传输的起点，也是进度条的起点
  int _resumeOffset = 0;
  int get _received => _resumeOffset + _newBytes;
  int _newBytes = 0;
  int get _total => file.sizeBytes;
  DateTime _startTime = DateTime.now();
  DateTime _lastProgressEmit = DateTime.fromMillisecondsSinceEpoch(0);
  bool _finished = false;
  TransferIntegrity? _lastIntegrity;

  /// TCP 数据断流看门狗：15 秒无字节视为传输中断
  Timer? _stallTimer;

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

      // ---- 1&2. BLE 开热点 + 手机入网 ----
      // 厂商的热点启用规则还没给（见文件头：9 种发法 + 三条独立网络层负证据），
      // 所以留一个替身入口：`Config.wifiServerOverride` 指到局域网上的假服务器，
      // 跳过这两步，专门验 0x46→TCP→.part→finalize→完整性 这条数据通路本身。
      final override = Config.wifiServerOverride;
      if (override.isNotEmpty) {
        final sp = override.split(':');
        _creds = XyrixHotspotCredentials(
          ssid: '',
          password: '',
          ip: sp.first,
          port:
              int.tryParse(sp.length > 1 ? sp.last : '') ??
              _candidatePorts.first,
        );
        debugPrint(
          '[Xyrix][WiFi] 替身服务器 ${_creds!.ip}:${_creds!.port}，'
          '跳过开热点与入网，只验数据通路',
        );
        _linkPhase(WifiTransferStatus.connected);
      } else {
        _linkPhase(WifiTransferStatus.opening);
        await sendCommand(XyrixCommands.openHotspotTcp);
        // 凭证来源：SDK 文档 §8.11 里 0x21「开启热点并打开 TCP 服务器」**附加数据为无、
        // 也没有响应数据**，真机实测只回 `FF 55 AA 01 21 01` 一个状态字节。也就是说
        // 「设备经蓝牙把 SSID/密码下发给 App」这个前提在协议里根本不存在，
        // 文档给的是 0x11「启动隐藏热点：热点名称+密码」——由 App 侧提供参数。
        // 所以这里只短暂等一帧凭证（万一某版固件真推），拿不到就明确报缺什么，
        // 不再用 12 秒超时冒充「设备不支持」。
        _creds = await _credentials.future.timeout(
          const Duration(seconds: 3),
          onTimeout:
              () => const XyrixHotspotCredentials(ssid: '', password: ''),
        );
        if (_creds!.ssid.isEmpty) {
          throw HardwareException(
            HardwareErrorCode.unsupportedCapability,
            '设备不回传热点 SSID/密码（0x21 仅回状态字节），需厂商提供热点参数规则'
            '或改用 0x11 由 App 指定名称与密码',
          );
        }
        debugPrint(
          '[Xyrix][WiFi] 热点凭证: ssid=${_creds!.ssid} '
          'password=${_creds!.password} ip=${_creds?.ip} port=${_creds?.port}',
        );
        _linkPhase(WifiTransferStatus.opened);

        // ---- 2. 手机连热点 ----
        _linkPhase(WifiTransferStatus.connecting);
        await hotspotConnector.connect(_creds!.ssid, _creds!.password);
        // 等 DHCP 分配完成
        await Future.delayed(const Duration(milliseconds: 1500));
      }

      // ---- 3. BLE 触发传输（文档时序：0x46 先于 tcpConnect）----
      // 0x46 携带断点偏移，设备从该偏移起经 TCP 推送
      await sendCommand(
        XyrixCommands.wifiTransferResume,
        XyrixFrameCodec.wifiResumeData('0:/${file.name}', _resumeOffset),
      );
      _emitProgress(TransferState.transferring, force: true);

      // ---- 4. TCP 连设备 ----
      final socket = await _connectTcp();
      _socket = socket;
      _linkPhase(WifiTransferStatus.connected);
      debugPrint(
        '[Xyrix][WiFi] TCP 已连接 ${socket.remoteAddress.address}:'
        '${socket.remotePort}',
      );

      // ---- 5. 收流落盘 ----
      await _receive(socket);
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

  Future<Socket> _connectTcp() async {
    final hosts = await _candidateHosts();
    final ports = <int>[
      if (_creds?.port != null) _creds!.port!,
      ..._candidatePorts,
    ];
    final combos = <(String, int)>[
      for (final host in hosts)
        for (final port in ports) (host, port),
    ];
    debugPrint(
      '[Xyrix][WiFi] TCP 探测: '
      '${combos.map((c) => '${c.$1}:${c.$2}').join(', ')}',
    );

    final results = await Future.wait(
      combos.map(((String, int) c) async {
        try {
          return await Socket.connect(
            c.$1,
            c.$2,
            timeout: const Duration(seconds: 3),
          );
        } catch (e) {
          debugPrint('[Xyrix][WiFi] ${c.$1}:${c.$2} 连接失败: $e');
          return null;
        }
      }),
    );

    Socket? picked;
    for (final s in results) {
      if (s == null) continue;
      if (picked == null) {
        picked = s;
      } else {
        s.destroy(); // 探测产生的多余连接一律关掉
      }
    }
    if (picked == null) {
      throw HardwareException(
        HardwareErrorCode.connectionLost,
        '无法通过热点连接设备（TCP 探测失败），请确认手机已连上设备热点',
      );
    }
    return picked;
  }

  /// TCP 候选地址：凭证帧给的 IP 优先，其次按本机热点网段推断网关（.1），
  /// 最后补设备厂商常见默认段
  Future<List<String>> _candidateHosts() async {
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

  Future<void> _receive(Socket socket) async {
    final done = Completer<void>();
    late final StreamSubscription<Uint8List> sub;
    sub = socket.listen(
      (data) {
        _stallTimer?.cancel();
        _sink?.add(data);
        _newBytes += data.length;
        _stallTimer = Timer(const Duration(seconds: 15), () {
          if (!done.isCompleted) {
            done.completeError(TimeoutException('TCP 数据断流 15 秒'));
          }
        });
        if (!_finished) {
          _emitProgress(TransferState.transferring);
        }
        if (_total > 0 && _received > _total && !done.isCompleted) {
          // 过收 = 有非文件字节混进了 TCP 流，内容不可信
          done.completeError(
            HardwareException(
              HardwareErrorCode.integrityMismatch,
              '收到字节超出文件大小（$_received/$_total），数据流被污染',
            ),
          );
          return;
        }
        if (_total > 0 && _received >= _total && !done.isCompleted) {
          done.complete();
        }
      },
      onError: (Object e) {
        if (!done.isCompleted) done.completeError(e);
      },
      onDone: () {
        if (!done.isCompleted) {
          if (_total > 0 && _received >= _total) {
            done.complete();
          } else {
            done.completeError(
              HardwareException(
                HardwareErrorCode.transferInterrupted,
                '设备提前断开连接（已收 $_received/$_total 字节）',
              ),
            );
          }
        }
      },
      cancelOnError: true,
    );
    _stallTimer = Timer(const Duration(seconds: 15), () {
      if (!done.isCompleted) {
        done.completeError(TimeoutException('TCP 数据断流 15 秒'));
      }
    });
    try {
      await done.future;
    } finally {
      _stallTimer?.cancel();
      await sub.cancel();
      socket.destroy();
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
      verdict = '失败 state=$state received=$_received/$_total：$error';
      debugPrint('[Xyrix][WiFi] 快传失败 received=$_received/$_total: $error');
    } else {
      verdict =
          'state=$state received=$_received/$_total '
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
