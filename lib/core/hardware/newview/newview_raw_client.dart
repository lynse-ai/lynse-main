/// Newview（厂商 nveasy）**裸协议**客户端：flutter_blue_plus 直连，不经过厂商 AAR。
///
/// 存在的理由：目标是把调度统一到 `lynse-hardware-sdk`、不再依赖厂家 SDK，而
/// SDK 里那份 `first-device/newview/NewViewProtocolDefinition.kt` 从写出来那天起
/// **一次都没在 Newview 真机上跑过**（bench 上的卡是 Xyrix，服务 UUID 都对不上）。
///
/// 本文件是那份 Kotlin 定义的 Dart 镜像，不是第三套实现：
/// - 编码逐字节照抄 Kotlin（同一套 UUID、同一条 `*APP#…#` 文本），
///   这样「真机怎么回」直接就是在考 Kotlin 的假设；
/// - 解码**故意不做宽容修正**。Kotlin 在 `fields.size != 4` / `!= 5` / `!= 8`
///   的地方是 `throw invalidFrame(...)`，这里就照原样把段数、`#` 位置、hex
///   记进报告——判据是「Kotlin 会不会在这台机器上抛」，不是「能不能凑出一个值」。
/// - 沉默不等于失败：每次写入都取 GATT 写状态，并另读标准电池服务
///   `0000180f/2A19` 作阳性对照。两样都好而文本命令不回，才是「鉴权拦在前面」。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dting/core/hardware/command_lane.dart';
import 'package:dting/core/hardware/newview/newview_protocol.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';

/// 一次文本命令往来的实测结果（探测台只看形状，不猜语义）
class NewviewExchangeResult {
  final String sent;
  final List<List<int>> chunks;
  final String? writeStatus;

  /// 设备在窗口内回过任何东西吗（用于区分「没回」和「订阅没生效」）
  bool get heard => chunks.isNotEmpty;
  List<int> get bytes => chunks.expand((e) => e).toList();
  String get text => utf8.decode(bytes, allowMalformed: true);

  const NewviewExchangeResult({
    required this.sent,
    required this.chunks,
    this.writeStatus,
  });

  /// 按厂商的 `#` 分隔模型拆段（与 Kotlin `data.toString().split('#').filter(isNotEmpty)` 等价）
  List<String> get fields =>
      text.split('#').where((s) => s.isNotEmpty).toList();
}

/// 扫描到的候选设备，附带按 Kotlin `parseAdvertisement` 解析出的广播事实
class NewviewCandidate {
  final String remoteId;
  final String name;
  final int rssi;
  final List<int> manufacturerData;

  /// 厂商数据的 companyId（flutter_blue_plus 把前 2 字节吃掉当 key，
  /// 拼进 manufacturerData 就看不到了——重定广播偏移时这两个数是必须的）
  final List<int> companyIds;
  final List<String> serviceUuids;
  final NewviewAdFacts? facts;

  const NewviewCandidate({
    required this.remoteId,
    required this.name,
    required this.rssi,
    required this.manufacturerData,
    required this.serviceUuids,
    required this.facts,
    this.companyIds = const [],
  });

  bool get parsedFromAdvertisement => facts != null;

  @override
  String toString() =>
      '$name($remoteId) rssi=$rssi ${facts == null ? "广播未按 NvEasy 规则解析出" : "ver=${facts!.protocolVersion} sku=${facts!.sku ?? "-"} mask=${facts!.abilityMask.toRadixString(16)}"}';
}

class NewviewRawClient {
  static final Guid _service = Guid(NewviewRaw.primaryServiceUuid);
  static final Guid _write = Guid(NewviewRaw.writeCharacteristicUuid);
  static final Guid _notify = Guid(NewviewRaw.notifyCharacteristicUuid);
  static final Guid _read = Guid(NewviewRaw.readCharacteristicUuid);
  static final Guid _batteryService = Guid(NewviewRaw.batteryServiceUuid);
  static final Guid _batteryChar = Guid(NewviewRaw.batteryCharacteristicUuid);

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;
  StreamSubscription<List<int>>? _notifySub;

  /// 全量服务表，供 gattSurvey 打印（连接后填）
  List<BluetoothService> services = const [];

  /// 文本协议不走任何帧解析器，所有通知只按原样旁路给探测台。
  /// 「先登记等待方、再写特征」是硬性要求（Xyrix 上首跑就是这么假阴的）。
  final List<_Waiter> _waiters = [];

  /// 命令车道：`exchangeRaw` 全部排队，一次只发一条（见方法上的注释）。
  /// 有了车道，[_waiters] 里正常情况下永远最多一条。
  final CommandLane commandLane = CommandLane(label: 'newview-raw');

  IOSink? _captureSink;
  String? _capturePath;

  /// 最近一次通知的时间戳，用于判断链路是否还活着
  DateTime? lastNotifyAt;

  bool get isConnected => _writeChar != null;

  String? get capturePath => _capturePath;

  // ------------------------------------------------------------------
  // 扫描
  // ------------------------------------------------------------------

  /// 无过滤扫描 + 本地判据：服务 UUID 命中主服务，或厂商数据里含 `NvEasy`。
  ///
  /// 之所以不直接用 `withServices` 过滤：厂商 AAR 自己也是不过滤扫的
  /// （`BleManager.kt:98`），有些批次只在响应包/扫描响应里带服务 UUID，
  /// 广播包里没有；先收全量再看形状，才不会把「其实在这」判成「不在范围」。
  Future<List<NewviewCandidate>> scan({
    Duration timeout = const Duration(seconds: 15),
    bool newviewOnly = true,
  }) async {
    await FlutterBluePlus.adapterState
        .where((s) => s == BluetoothAdapterState.on)
        .first
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw StateError('蓝牙未开启'),
        );
    final found = <String, NewviewCandidate>{};
    final rawSeen = <String>{};
    final unattributed = <String>{};
    scanError = null;

    // 用累积流 scanResults，不用增量流 onScanResults：
    // Xyrix 那条路径在同版本插件上就是这么跑通的，换成增量流实测一轮
    // 15s 扫描回调里一条都没进（2026-10-22 本机实测）。
    // 这个版本的 scanResults 是普通 Stream、没有 .value 可快照，
    // 所以原始条数自己记账——「扫不到」必须能分辨是没信号还是判据筛掉了。
    void absorb(List<ScanResult> results) {
      for (final r in results) {
        final id = r.device.remoteId.str;
        rawSeen.add(id);
        final candidate = _toCandidate(r);
        if (candidate == null) {
          unattributed.add(id);
          continue;
        }
        found[id] = candidate;
      }
    }

    // 这个插件把扫描失败作为**流错误**抛出（`_scanResults.addError` 后立即停扫），
    // 只给 onData 不给 onError 的话，失败原因会被吞成「扫到 0 台」——
    // 2026-10-22 本机第一轮就是这么糊过去的。必须把它接下来落进报告。
    final sub = FlutterBluePlus.scanResults.listen(
      absorb,
      onError: (Object e, StackTrace _) {
        scanError = '$e';
      },
    );
    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        continuousUpdates: true,
        // 注意 AndroidScanMode 在这个插件里是 class 不是 enum（static const 成员）
        androidScanMode: AndroidScanMode.lowLatency,
      );
      await FlutterBluePlus.isScanning.where((s) => !s).first;
      // 关扫描后尾包还在路上，给 300ms 再收一次
      await Future<void>.delayed(const Duration(milliseconds: 300));
      // 这个版本没有 scanResults.value，但有 lastScanResults（累积列表的最新值）。
      // 排空它一次：漏一帧也不该把「设备其实在范围」判成不在范围。
      absorb(FlutterBluePlus.lastScanResults);
      rawScanCount = rawSeen.length;
      unattributedCount = unattributed.length;
    } finally {
      await sub.cancel();
    }
    final all = found.values.toList();
    final list = (newviewOnly
            ? all.where(
                (c) => c.facts != null || c.serviceUuids.contains(NewviewRaw.primaryServiceUuid),
              )
            : all)
        .toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return list;
  }

  /// 阳性对照两个数：插件一共报过多少台、其中多少台被本地判据判成「不是设备」
  int rawScanCount = 0;
  int unattributedCount = 0;

  /// 插件通过流错误抛回来的扫描失败原因；为空才可以说「空气里真的没有」
  String? scanError;

  NewviewCandidate? _toCandidate(ScanResult r) {
    final adv = r.advertisementData;
    final name = r.device.platformName.isNotEmpty
        ? r.device.platformName
        : adv.advName;
    final mfg = <int>[];
    adv.manufacturerData.forEach((_, v) => mfg.addAll(v));
    final serviceUuids = adv.serviceUuids.map((g) => g.str128.toLowerCase()).toList();
    if (name.isEmpty && mfg.isEmpty && serviceUuids.isEmpty) return null;
    return NewviewCandidate(
      remoteId: r.device.remoteId.str,
      name: name.isEmpty ? '(无名)' : name,
      rssi: r.rssi,
      manufacturerData: mfg,
      companyIds: adv.manufacturerData.keys.toList(),
      serviceUuids: serviceUuids,
      facts: NewviewRaw.parseAdvertisement(mfg),
    );
  }

  // ------------------------------------------------------------------
  // 连接
  // ------------------------------------------------------------------

  Future<void> connect(
    NewviewCandidate candidate, {
    int requestMtu = 512,
    bool captureRaw = true,
  }) async {
    final dev = BluetoothDevice.fromId(candidate.remoteId);
    _device = dev;
    await dev.connect(
      timeout: const Duration(seconds: 20),
      mtu: null, // 自己协商，好把结果记进报告
    );
    if (requestMtu > 0 && Platform.isAndroid) {
      try {
        final got = await dev.requestMtu(requestMtu);
        debugPrint('[Newview][裸] MTU 请求 $requestMtu → $got');
      } catch (e) {
        debugPrint('[Newview][裸] MTU 协商失败（用默认值继续）: $e');
      }
    }
    services = await dev.discoverServices();
    debugPrint('[Newview][裸] 发现 ${services.length} 个服务: '
        '${services.map((s) => s.uuid.str).join(', ')}');

    if (captureRaw) await _openCapture(candidate);

    for (final service in services) {
      for (final c in service.characteristics) {
        if (c.uuid == _notify) {
          await c.setNotifyValue(true);
          await _notifySub?.cancel();
          _notifySub = c.onValueReceived.listen(_onNotify);
          debugPrint('[Newview][裸] 已订阅通知特征 ${service.uuid.str} / ${c.uuid.str}');
        }
        if (c.uuid == _write) {
          _writeChar = c;
        }
      }
    }
    if (_writeChar == null) {
      throw StateError(
        '未找到写特征 ${NewviewRaw.writeCharacteristicUuid}；'
        '这台机器的 GATT 表和 SDK 里写死的主服务不一致（见 gattSurvey 全表）',
      );
    }
  }

  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _notifySub = null;
    _waiters.clear();
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
    _writeChar = null;
    await _closeCapture();
  }

  // ------------------------------------------------------------------
  // 收发
  // ------------------------------------------------------------------

  /// 发一条 `*APP#…#` 文本命令，收集 [timeout] 内（或提前满足 [stopWhen]）的原始回包。
  Future<NewviewExchangeResult> exchangeText(
    String frame, {
    Duration timeout = const Duration(seconds: 3),
    bool Function(List<int> chunk)? stopWhen,
    bool withResponse = true,
    String? matchCommand,
  }) {
    // 文本协议的回包自带命令名（*DEV#<cmd>#…），按它配对才能把「谁的回复」
    // 归给谁；不配对的话，一条迟到的 version 会被记到 battery 头上。
    final cmd = matchCommand ?? commandNameOf(frame);
    return exchangeRaw(
      utf8.encode(frame),
      label: frame,
      timeout: timeout,
      withResponse: withResponse,
      stopWhen: stopWhen ??
          (cmd == null
              ? null
              : (chunk) => utf8
                  .decode(chunk, allowMalformed: true)
                  .startsWith('${NewviewRaw.responsePrefix}$cmd#')),
    );
  }

  /// 从 `*APP#<cmd>#…` 取出命令名；形状不对就返回 null（不猜）
  static String? commandNameOf(String frame) {
    final fields = frame.split('#').where((s) => s.isNotEmpty).toList();
    if (fields.length < 2 || fields[0] != '*APP') return null;
    return fields[1];
  }

  /// 字节版：鉴权帧的载荷未必是可打印 ASCII（AAR 那 16 字节可以直接给 hex 值）
  Future<NewviewExchangeResult> exchangeRaw(
    List<int> bytes, {
    required String label,
    Duration timeout = const Duration(seconds: 3),
    bool Function(List<int> chunk)? stopWhen,
    bool withResponse = true,
  }) {
    // 一条命令一条道：上一条的回包（或超时）到了才发下一条。
    // 依据是这张卡的两条实测行为——多条 `*DEV#` 会被合并进同一条 notify
    // （第 11.1 节），而会话类命令（getlist → listreq、opusfile）被后来的命令
    // 打断就整段作废。车道在 `_exchangeRawUnlocked` 返回（含超时）之后才放行。
    return commandLane.run(
      'exchange(${NewviewRaw.redact(label)})',
      () => _exchangeRawUnlocked(
        bytes,
        label: label,
        timeout: timeout,
        stopWhen: stopWhen,
        withResponse: withResponse,
      ),
    );
  }

  /// 真正下发并等回包。**只允许经 [exchangeRaw] 调用**——串行由车道保证。
  Future<NewviewExchangeResult> _exchangeRawUnlocked(
    List<int> bytes, {
    required String label,
    Duration timeout = const Duration(seconds: 3),
    bool Function(List<int> chunk)? stopWhen,
    bool withResponse = true,
  }) async {
    final char = _writeChar;
    if (char == null) throw StateError('未连接');
    final waiter = _Waiter(stopWhen);
    _waiters.add(waiter);
    String? writeStatus;
    try {
      // Kotlin 侧把写类型硬编码成 withResponse，但 2026-10-22 真机（Lynse AI 0091）
      // 的 06068d1c 只有 WoR 属性，照抄就全部以
      // "The WRITE property is not supported by this BLE characteristic" 失败。
      // 探测台必须按**实际属性**下发，否则「设备不回」永远是假阴。
      final mode = _writeModeFor(char, preferWithResponse: withResponse);
      if (mode == null) {
        return NewviewExchangeResult(
          sent: label,
          chunks: const [],
          writeStatus: '写特征 ${char.uuid.str128} 既不支持 WRITE 也不支持 WRITE_NO_RESPONSE',
        );
      }
      await char.write(bytes, withoutResponse: mode == _WriteMode.noResponse);
      lastWriteMode = mode.name;
      writeStatus = '已下发(${mode.name}, ${bytes.length}B)';
      debugPrint('[Newview][裸] → ${NewviewRaw.redact(label)}');
      final got = await waiter.completer.future.timeout(
        timeout,
        // 超时不是「没收到」：字节可能早就进来了，只是没触发 stopWhen。
        // 这里返回 const [] 会让整台探测台把「设备在回话」记成「全程沉默」——
        // 2026-10-22 就是这么把三轮对照量成 0/6 的，落盘的原始 .bin 里
        // 明明有 *DEV#version#1.5.1#0.3.0#。必须交还已收分块。
        onTimeout: () => waiter.take(),
      );
      return NewviewExchangeResult(
        sent: label,
        chunks: got,
        writeStatus: writeStatus,
      );
    } catch (e) {
      writeStatus = '写失败: $e';
      return NewviewExchangeResult(
          sent: label, chunks: waiter.take(), writeStatus: writeStatus);
    } finally {
      _waiters.remove(waiter);
    }
  }

  /// 最近一次实际用的写模式，报告里要能看出这台机器吃哪一种
  String? lastWriteMode;

  static _WriteMode? _writeModeFor(
    BluetoothCharacteristic c, {
    bool preferWithResponse = true,
  }) {
    if (preferWithResponse && c.properties.write) return _WriteMode.withResponse;
    if (c.properties.writeWithoutResponse) return _WriteMode.noResponse;
    if (c.properties.write) return _WriteMode.withResponse;
    return null;
  }

  /// 纯观测：不发命令，只收 [seconds] 秒内的通知（实时推流、设备主动上报都靠它）
  Future<List<List<int>>> listenOnly(int seconds) async {
    final waiter = _Waiter(null);
    _waiters.add(waiter);
    try {
      await Future<void>.delayed(Duration(seconds: seconds));
      return waiter.take();
    } finally {
      _waiters.remove(waiter);
    }
  }

  void _onNotify(List<int> value) {
    lastNotifyAt = DateTime.now();
    for (final w in _waiters.toList()) {
      w.add(value);
    }
    try {
      _captureSink?.add(value);
    } catch (_) {}
    if (value.length <= 64) {
      debugPrint('[Newview][裸] ← ${value.length}B ${NewviewRaw.hex(value)} '
          '「${NewviewRaw.redact(utf8.decode(value, allowMalformed: true)).replaceAll('\n', r'\n')}」');
    } else {
      debugPrint('[Newview][裸] ← ${value.length}B ${NewviewRaw.hex(value.sublist(0, 16))}…');
    }
  }

  // ------------------------------------------------------------------
  // 阳性对照：与厂商文本协议无关的 GATT 通路自检
  // ------------------------------------------------------------------

  /// 读标准电池服务（Kotlin 里同样声明了 0000180f/2A19）。
  /// 读到值就证明扫描→连接→服务发现→读这条链是通的，
  /// 之后文本命令沉默才不能赖到「订阅没生效」上。
  Future<String> readStandardBattery() async {
    final dev = _device;
    if (dev == null) return '未连接';
    for (final service in services) {
      if (service.uuid != _batteryService) continue;
      for (final c in service.characteristics) {
        if (c.uuid != _batteryChar) continue;
        try {
          final v = await c.read();
          if (v.isEmpty) return '电池特征返回 0 字节';
          return '${v.first}%';
        } catch (e) {
          return '读失败 $e';
        }
      }
    }
    return '无 180f 服务';
  }

  /// 读主服务的 READ 特征（06068d3c）。Kotlin 定义了它但从没读过——
  /// 能不能读、读出什么形状，本身就是给 SDK 补的证据。
  Future<String> readPrimaryReadCharacteristic() async {
    for (final service in services) {
      if (service.uuid != _service) continue;
      for (final c in service.characteristics) {
        if (c.uuid != _read) continue;
        try {
          final v = await c.read();
          return '${v.length}B ${NewviewRaw.hex(v.take(32).toList())} '
              '「${NewviewRaw.printable(v.take(32).toList())}」';
        } catch (e) {
          return '读失败 $e';
        }
      }
    }
    return '主服务里没有 06068d3c';
  }

  /// GATT 全表：服务/特征/属性/描述符。SDK 里 UUID 是写死的，
  /// 这台机器实际长什么样必须能一眼对出来。
  String gattSurvey() {
    final out = <String>[];
    for (final s in services) {
      final chars = s.characteristics.map((c) {
        final props = <String>[
          if (c.properties.read) 'R',
          if (c.properties.write) 'W',
          if (c.properties.writeWithoutResponse) 'WoR',
          if (c.properties.notify) 'N',
          if (c.properties.indicate) 'I',
        ].join('/');
        final descs = c.descriptors.map((d) => _compact(d.uuid)).join(',');
        return '${_compact(c.uuid)}[$props${descs.isEmpty ? "" : " {$descs}"}]';
      }).join(' ');
      out.add('${_compact(s.uuid)} → $chars');
    }
    return out.isEmpty ? '服务表为空' : out.join(' || ');
  }

  /// 128 位 UUID 只留前面那段（厂商那几条的区分位就在开头），
  /// 全表读起来才不会是一屏 `-ac120002`
  static String _compact(Guid g) {
    final s = g.str128;
    return s.length <= 12 ? s : '${s.substring(0, 8)}…';
  }

  Future<void> _openCapture(NewviewCandidate candidate) async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return;
      final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File('${dir.path}/newview_raw_${ts}.bin');
      _capturePath = file.path;
      _captureSink = file.openWrite(mode: FileMode.append);
      // 头部一行明文，方便拉回来的人知道这段字节是哪台机器、哪次连接
      _captureSink!.add(utf8.encode('# ${candidate.remoteId} ${candidate.name}\n'));
    } catch (e) {
      debugPrint('[Newview][裸] 打开原始落盘失败: $e');
    }
  }

  Future<void> _closeCapture() async {
    try {
      await _captureSink?.flush();
      await _captureSink?.close();
    } catch (_) {}
    _captureSink = null;
  }
}

/// 下发方式：按特征实际属性挑，不照抄 SDK 里写死的 withResponse
enum _WriteMode { withResponse, noResponse }

class _Waiter {
  final bool Function(List<int> chunk)? stopWhen;
  final List<List<int>> _chunks = [];
  final Completer<List<List<int>>> completer = Completer();

  _Waiter(this.stopWhen);

  void add(List<int> chunk) {
    _chunks.add(List<int>.from(chunk));
    if (stopWhen?.call(chunk) == true && !completer.isCompleted) {
      completer.complete(_chunks);
    }
  }

  List<List<int>> take() => _chunks.map(List<int>.from).toList();
}
