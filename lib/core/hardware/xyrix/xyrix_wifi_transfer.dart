/// Xyrix「音频外传快传」：设备热点 + TCP 通道文件传输会话。
///
/// 流程（对应命令表 XyrixCommands）：
/// 1. BLE 发 `openHotspotTcp`(0x21)：设备开热点并启动 TCP 服务，经蓝牙
///    通知回传热点凭证（SSID/密码，帧格式厂商未给死——按宽松 ASCII 解析
///    + 全量日志，真机联调确认实际格式后精化 [XyrixHotspotCredentials.parse]）。
/// 2. 手机连热点（iOS NEHotspotConfiguration，见 hotspot_connector.dart）。
/// 3. TCP 连设备：凭证帧里若未带 IP/端口，按本机网段 .1 + 常见默认端口
///    并发探测。
/// 4. BLE 发 `wifiTransferResume`(0x46)：路径 + 4 字节大端断点（首传为 0），
///    设备开始经 TCP 推送文件字节。
/// 5. 收满文件列表上报的 sizeBytes 判定完成；BLE 发 `wifiTransferStop`(0x47)
///    + `closeWifi`(0x23) 收尾，并移除手机上的热点配置。
///
/// 进度复用 [TransferProgressEvent]/[WifiStatusEvent]，UI 无需感知传输通道差异。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dting/core/hardware/hardware_event.dart';
import 'package:dting/core/hardware/models.dart';
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

  /// 凭证等待期：设备对 0x21 的响应帧从 BLE 通知解析进来
  final Completer<XyrixHotspotCredentials> _credentials =
      Completer<XyrixHotspotCredentials>();

  XyrixHotspotCredentials? _creds;
  IOSink? _sink;
  File? _outFile;
  Socket? _socket;
  int _received = 0;
  int get _total => file.sizeBytes;
  DateTime _startTime = DateTime.now();
  DateTime _lastProgressEmit = DateTime.fromMillisecondsSinceEpoch(0);
  bool _finished = false;

  /// TCP 数据断流看门狗：15 秒无字节视为传输中断
  Timer? _stallTimer;

  /// 设备热点网段常见默认端口（凭证帧未带端口时逐个探测）
  static const _candidatePorts = [8080, 2222, 8888, 8090, 9000, 80];

  XyrixWifiTransferSession({
    required this.file,
    required this.sendCommand,
    required this.emit,
    required this.hotspotConnector,
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
      _outFile = File('${dir.path}/xyrix_wifi_${file.name}');
      _sink = _outFile!.openWrite();

      // ---- 1. BLE 开热点，等凭证 ----
      _linkPhase(WifiTransferStatus.opening);
      await sendCommand(XyrixCommands.openHotspotTcp);
      debugPrint('[Xyrix][WiFi] 已发送 0x21（开热点+TCP），等待设备回传凭证…');
      _creds = await _credentials.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw HardwareException(
            HardwareErrorCode.deviceError,
            '设备未回传热点信息，请确认设备支持音频外传快传',
          );
        },
      );
      debugPrint('[Xyrix][WiFi] 热点凭证: ssid=${_creds!.ssid} '
          'password=${_creds!.password} ip=${_creds?.ip} port=${_creds?.port}');
      _linkPhase(WifiTransferStatus.opened);

      // ---- 2. 手机连热点 ----
      _linkPhase(WifiTransferStatus.connecting);
      await hotspotConnector.connect(_creds!.ssid, _creds!.password);
      // 等 DHCP 分配完成
      await Future.delayed(const Duration(milliseconds: 1500));

      // ---- 3. TCP 连设备 ----
      final socket = await _connectTcp();
      _socket = socket;
      _linkPhase(WifiTransferStatus.connected);
      debugPrint('[Xyrix][WiFi] TCP 已连接 ${socket.remoteAddress.address}:'
          '${socket.remotePort}');

      // ---- 4. BLE 触发传输（断点 0）----
      // 若真机联调发现设备无推流，优先怀疑 0x46 应改走 TCP 发送
      await sendCommand(
        XyrixCommands.wifiTransferResume,
        XyrixFrameCodec.wifiResumeData('0:/${file.name}', 0),
      );
      _emitProgress(TransferState.transferring, force: true);

      // ---- 5. 收流落盘 ----
      await _receive(socket);
      await _finish(TransferState.completed);
    } catch (e) {
      await _finish(TransferState.failed, error: e);
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
      for (final host in hosts) for (final port in ports) (host, port),
    ];
    debugPrint('[Xyrix][WiFi] TCP 探测: '
        '${combos.map((c) => '${c.$1}:${c.$2}').join(', ')}');

    final results = await Future.wait(combos.map(((String, int) c) async {
      try {
        return await Socket.connect(c.$1, c.$2,
            timeout: const Duration(seconds: 3));
      } catch (e) {
        debugPrint('[Xyrix][WiFi] ${c.$1}:${c.$2} 连接失败: $e');
        return null;
      }
    }));

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
    final hosts = <String>[
      if (_creds?.ip != null) _creds!.ip!,
    ];
    try {
      final interfaces =
          await NetworkInterface.list(type: InternetAddressType.IPv4);
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
    for (final fallback in const ['192.168.4.1', '192.168.1.1']) {
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
        _received += data.length;
        _stallTimer = Timer(const Duration(seconds: 15), () {
          if (!done.isCompleted) {
            done.completeError(TimeoutException('TCP 数据断流 15 秒'));
          }
        });
        if (!_finished) {
          _emitProgress(TransferState.transferring);
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
            done.completeError(HardwareException(
              HardwareErrorCode.transferInterrupted,
              '设备提前断开连接（已收 $_received/$_total 字节）',
            ));
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

  Future<void> _finish(TransferState state, {Object? error}) async {
    if (_finished) return;
    _finished = true;
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {}
    final outFile = _outFile;
    _sink = null;
    _outFile = null;
    if (error != null) {
      debugPrint('[Xyrix][WiFi] 快传失败 received=$_received/$_total: $error');
    } else {
      debugPrint('[Xyrix][WiFi] 快传完成 received=$_received/$_total '
          '→ ${outFile?.path}');
    }
    _emitProgress(state, force: true);
    if (state == TransferState.completed && outFile != null) {
      emit(FileImportedEvent(ImportedRecording(
        filePath: outFile.path,
        recordStartTime: file.startTime,
        fileSn: file.sn,
        scene: file.scene,
      )));
    }
    if (state == TransferState.failed && outFile != null && _received == 0) {
      try {
        await outFile.delete();
      } catch (_) {}
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
    final speedKbps = elapsedSec > 0.2 ? (received / 1024 / elapsedSec).round() : 0;
    emit(TransferProgressEvent(
      TransferProgress(
        state: state,
        receivedBytes: received,
        totalBytes: total,
        totalPacket: total > 0 ? (total / 512).ceil() : 1,
        currentPacket: total > 0 ? (received / 512).ceil() : 0,
        speedKbps: speedKbps,
      ),
      fileSn: file.sn,
    ));
  }

  /// 外部强制终止（适配器销毁/断连时调用）
  Future<void> abort() async {
    _socket?.destroy();
    _stallTimer?.cancel();
    await _finish(TransferState.cancelled);
    await _teardown();
  }
}
