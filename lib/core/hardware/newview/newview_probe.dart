/// Newview 真机探测台：把 `NewViewProtocolDefinition.kt` 里每一条**没上过设备的假设**
/// 逐条打到机器上取证。分级执行，破坏性命令一档都不跑。
///
/// 等级：
/// - L1 只查询。广播形状 + GATT 全表 + 两条阳性对照 + 静默观测 + 只读文本命令。
///      这一档回答本次最关键的那个问题：**不做 sdkkey 握手，设备认不认我们的命令**。
/// - L2 录音生命周期 + 实时推流（会在设备上生成一条新录音）。
/// - L3 文件面（getlist / listreq / filecmd 裸发看形状）。
/// - L4 WiFi 快传开关（`*APP#wifi#1#` → 观察 `*DEV#wifi#` 段数 → 收尾必发 `#0#`）。
///
/// 与 Xyrix 探测台最大的不同：Xyrix 那轮是在**猜厂商没写清的格式**，这里是在
/// **验我们自己已经写进 SDK 的格式**，所以每步的结论都必须是「相对 Kotlin 假设
/// PASS / MISMATCH」，而不是「解出了一个看起来合理的值」。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dting/config/config.dart';
import 'package:dting/core/hardware/newview/newview_protocol.dart';
import 'package:dting/core/hardware/newview/newview_raw_client.dart';
import 'package:dting/plugin/nv_easy_plugin.dart';
import 'package:dting/core/hardware/xyrix/hotspot_connector.dart';
import 'package:path_provider/path_provider.dart';

class NewviewProbe {
  final NewviewRawClient client;
  final NewviewCandidate candidate;
  final void Function(String line) log;

  /// L4 用带外/设备上报的热点凭据入网；Xyrix 那边已经实现过同一套通道
  final HotspotConnector _hotspot = MethodChannelHotspotConnector();

  /// 计划文件里显式开了才发 `opusfile#N#`（AAR 里它是「选下载格式」，
  /// 会改设备行为，默认不碰）
  final bool allowOpusFormatSelect;

  /// 计划文件 `vendor=1`：L1 跑完后断开裸客户端，改用厂商 AAR 对同一台机器
  /// 走一遍。没有这条对照，「设备不回」永远分不清是我们的锅还是设备的状态。
  final bool vendorControl;

  NewviewProbe({
    required this.client,
    required this.candidate,
    required this.log,
    this.allowOpusFormatSelect = false,
    this.vendorControl = false,
  });

  static const int levelReadOnly = 1;
  static const int levelRecord = 2;
  static const int levelFiles = 3;
  static const int levelWifi = 4;

  Future<void> run(int level, {int onlyLevel = 0}) async {
    final only = onlyLevel;
    log('===== Newview 裸协议探测开始 level=$level'
        '${only != 0 ? "（仅 L$only）" : ""} =====');
    log('目标 ${candidate.name} ${candidate.remoteId} rssi=${candidate.rssi}');
    log('[L1] gatt 全表: ${client.gattSurvey()}');
    _reportAdvertisement();

    Future<void> gate(int lv, String name, Future<void> Function() body) async {
      if (only != 0 ? only != lv : level < lv) return;
      try {
        await body();
      } catch (e, st) {
        log('[$name] 步骤异常: $e\n$st');
      }
    }

    await gate(levelReadOnly, 'L1', _runReadOnly);
    await gate(levelRecord, 'L2', _runRecord);
    await gate(levelFiles, 'L3', _runFiles);
    await gate(levelWifi, 'L4', _runWifi);
    await gate(5, 'L5', _runWifiThenDownload);

    log('===== 探测结束；原始字节落盘 ${client.capturePath ?? "无"} =====');
  }

  /// L5「反连判据」：先把热点开起来并**保持**，等台架侧（笔记本）入网并在
  /// 卡报的那个客户端端口上监听，然后**从 BLE** 下下载命令——
  /// 如果厂商的模型是「设备把文件从 WiFi 反推给 App」，文件字节就该出现在那条监听上。
  /// L4 已经证明 9527 是个只播报状态、不理文本命令的 socket，所以这一档才要换个方向看。
  Future<void> _runWifiThenDownload() async {
    final open = await client.exchangeText(
      NewviewRaw.wifiCommand(true),
      timeout: const Duration(seconds: 8),
    );
    final f = open.fields;
    if (f.length != 9 || f[1] != 'wifi') {
      log('[L5] wifi#1 没回 9 段凭据（${_describeReply(open)}）→ 反连判据做不了');
      return;
    }
    final parsed = NewviewWifiFields(
      serverIp: f[3],
      serverPort: f[4],
      clientIp: f[5],
      clientPort: f[6],
      ssid: f[7],
      password: f[8],
    );
    await _writeApFile(parsed);
    log('[L5] 凭据已落 newview_ap.txt（AP=***(len=${parsed.ssid.length})，'
        '服务端 ${parsed.serverIp}:${parsed.serverPort}，客户端位 ${parsed.clientIp}:${parsed.clientPort}）');
    final dir = await getExternalStorageDirectory();
    var seconds = 60;
    if (dir != null && await File('${dir.path}/newview_hold.txt').exists()) {
      seconds = int.tryParse(await File('${dir.path}/newview_hold.txt').readAsString()) ?? seconds;
    }
    final clamped = seconds.clamp(10, 300);
    log('[L5] 热点保持 ${clamped}s，等台架侧入网 + 监听 :${parsed.clientPort}');
    await Future<void>.delayed(Duration(seconds: clamped));
    // 命令一律从 BLE 发：这里要看的是「字节会不会从另一条路回来」
    log('[L5] 现在从 BLE 发下载命令（opusfile 走 sn=3，4480 B，只读）');
    await _runFileDownloadProbe();
    final close = await client.exchangeText(
      NewviewRaw.wifiCommand(false),
      timeout: const Duration(seconds: 4),
    );
    log('[L5] wifi#0 收尾 → ${_describeReply(close)}');
  }

  // ------------------------------------------------------------------
  // L1 只查询：先回答「鉴权到底拦不拦」
  // ------------------------------------------------------------------

  void _reportAdvertisement() {
    log('[L1] 广播原文 companyId=${candidate.companyIds.join(",")} '
        'payload(${candidate.manufacturerData.length}B)='
        '${NewviewRaw.hex(candidate.manufacturerData)} '
        '「${NewviewRaw.printable(candidate.manufacturerData)}」');
    final res = NewviewRaw.parseAdvertisementDetailed(candidate.manufacturerData);
    final facts = res.facts;
    if (facts != null) {
      final extra = facts.abilityMask & ~NewviewRaw.knownCapabilityMask;
      final missing = NewviewRaw.knownCapabilityMask & ~facts.abilityMask;
      log('[L1] 广播 PASS Kotlin parseAdvertisement 解出 $facts '
          '能力=${facts.declaredAbilities.join(",")}');
      log('[L1] 广播 掩码差集 SDK 未声明的位=0x${extra.toRadixString(16)} '
          'SDK 写了死值但本机没有的位=0x${missing.toRadixString(16)}');
    } else {
      log('[L1] 广播 MISMATCH ${res.failure} —— 厂商数据在偏移 '
          '${NewviewRaw.indexOfBytes(candidate.manufacturerData, 'NvEasy'.codeUnits)} '
          '处，SDK 的 marker+7/+11/+14 假设需要按这条重定');
    }
  }

  /// 厂商 AAR 对照档（计划文件 `vendor=1`）：同一台机器，改用
  /// `NvEasyBle-v1.1.3.aar` 自己走一遍扫描→连接→查询。
  ///
  /// 判读：厂商拿到回调而我们拿不到 → 我们漏了动作，继续挖 AAR；
  /// 厂商也拿不到 → 是**设备状态**问题（充电中/被别的手机绑着/未解锁），
  /// 再改协议就是白改。这一档必须在裸客户端断开之后跑，
  /// 两个客户端抢同一台设备的 GATT 连接，结论两边都不可信。
  /// 第三轮：把厂商 `onNotifySuccess()` 里的**明文**初始化两帧补上（rtc + ostype），
  /// 再把同一批查询问一遍。
  ///
  /// 为什么单独问这一轮：sdkkey 的载荷由 `Auth.init()`（JNI）生成，我们拿不到，
  /// 冒充是无效的；但 rtc/ostype 是纯明文，发出去零风险。
  /// 如果设备从这之后开始应答，那它的闸门是「没被初始化」而不是「没鉴权」——
  /// 对「能不能换掉厂商 SDK」是完全不同的两个答案。
  Future<int> _runInitRound(int previous) async {
    final epoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final rtc = await client.exchangeText(
      NewviewRaw.rtcCommand(epoch),
      timeout: const Duration(seconds: 4),
    );
    log('[L1] 初始化 rtc($epoch) → ${_describeReply(rtc)}');
    final os = await client.exchangeText(
      NewviewRaw.osTypeCommand,
      timeout: const Duration(seconds: 4),
    );
    log('[L1] 初始化 ostype#0 → ${_describeReply(os)}');
    var answered = 0;
    for (final name in NewviewRaw.readOnlyCommands) {
      final r = await client.exchangeText(
        NewviewRaw.command(name),
        timeout: const Duration(seconds: 3),
      );
      if (r.heard) answered++;
      log('[L1] 初始化后 $name → ${_describeReply(r)}');
    }
    return answered;
  }

  /// 厂商 AAR 全接口扫档（计划文件 `vendor=1`）。
  ///
  /// 第二轮改写：原先这里只是「AAR 扫 12s + 问一次电量和版本」的点检，
  /// 它用的还是 v1.1.3——那版 AAR 连 `init(Application, appKey)` 都没有、
  /// 类里也不含 `*APP#appkey#` 字符串，对新固件本来就握不上手，
  /// 所以它得出的「厂商 SDK 也拿不到应答」根本不能作为判据。
  /// 现在把整档交给 v1.2.0 的 [NewviewVendorProbe]：扫描→连接→鉴权→
  /// 设备信息 14 项→录音控制 7 项→文件列表/BLE 下载→WiFi 快传，逐项计时判定。
  Future<void> _runVendorControl() async {
    log('[L1][厂商AAR扫档] 断开裸客户端，把射频让给 NvEasyBle v1.2.0');
    await client.disconnect();
    final plugin = NvEasyPlugin();
    try {
      final start = await plugin.vendorProbeStart(
        name: candidate.name,
        appKey: Config.newviewAppKey.isEmpty ? null : Config.newviewAppKey,
        mac: candidate.remoteId,
        // 广播原文交给 AAR 兜底构造句柄：厂商扫描器按自己的 idMark 过滤，
        // 这块卡（"ilynse"/"L1NV"）在它默认 scan() 下是 0 台。
        advHex: NewviewRaw.hex(candidate.manufacturerData).replaceAll(' ', ''),
        record: true,
        wifi: true,
        delete: false,
      );
      log('[L1][厂商AAR扫档] 已下发：$start；扫档约需 3-5 分钟');
      var waited = 0;
      while (await plugin.vendorProbeRunning() && waited < 480) {
        await Future<void>.delayed(const Duration(seconds: 5));
        waited += 5;
        if (waited % 30 == 0) {
          final t = await plugin.vendorProbeTail(lines: 2);
          log('[L1][厂商AAR扫档] ${waited}s 进度: ${t.split("\n").last}');
        }
      }
      final tail = await plugin.vendorProbeTail(lines: 200);
      final verdicts = tail
          .split('\n')
          .where((l) =>
              l.contains('[') &&
              (l.contains('OK]') || l.contains('TIMEOUT]') || l.contains('FAIL]') || l.contains('SKIP]')) &&
              l.contains('::'))
          .toList();
      log('[L1][厂商AAR扫档] 判定 ${verdicts.length} 项：');
      for (final v in verdicts) {
        log('    $v');
      }
      log('[L1][厂商AAR扫档] 判读口径：厂商 OK 而我们裸协议 TIMEOUT 的接口，'
          '缺的是握手（sdkkey 载荷由 libnveasysdk.so 的 Auth.encrypt 生成，'
          '我们拿不到密钥，冒充无效）；厂商也 TIMEOUT 的接口是设备状态或固件问题，'
          '不该再改我们的协议。完整日志见设备侧 newview_vendor_report.txt');
    } catch (e) {
      log('[L1][厂商AAR扫档] 异常: $e');
    }
  }

  Future<void> _runReadOnly() async {
    // 阳性对照 1/2：与厂商文本协议无关的 GATT 读通路
    log('[L1] 对照·标准电池服务(180f/2a19): ${await client.readStandardBattery()}');
    log('[L1] 对照·主服务 READ 特征(06068d3c): '
        '${await client.readPrimaryReadCharacteristic()}');

    // 阳性对照 3：连上但不发任何命令，看设备是否主动上报
    final idle = await client.listenOnly(4);
    if (idle.isEmpty) {
      log('[L1] 静默 4s 观测: 无通知');
    } else {
      log('[L1] 静默 4s 观测: ${idle.length} 包');
      for (final p in idle) {
        final text = utf8.decode(p, allowMalformed: true);
        final fields = text.split('#').where((s) => s.isNotEmpty).toList();
        log('[L1]  主动上报 ${p.length}B「${NewviewRaw.redact(NewviewRaw.printable(p))}」 '
            '${fields.length}段(${NewviewRaw.redact(fields.join("|"))})');
      }
    }

    log('[L1] 关键判据：**不发任何握手**，直接按 SDK 的编码发查询');
    log('[L1] 实际下发方式: ${client.lastWriteMode ?? "尚未成功下发过"}');
    var answered = 0;
    var writeRejected = 0;
    for (final name in NewviewRaw.readOnlyCommands) {
      final frame = NewviewRaw.command(name);
      final r = await client.exchangeText(frame, timeout: const Duration(seconds: 3));
      if (r.heard) answered++;
      if ((r.writeStatus ?? '').contains('写失败') ||
          (r.writeStatus ?? '').contains('不支持')) {
        writeRejected++;
      }
      log('[L1] $name → ${_describeReply(r)}');
    }
    final total = NewviewRaw.readOnlyCommands.length;
    final String verdict;
    if (answered > 0) {
      verdict = '$answered/$total 条有回包 → 无握手也能取数据，自研 SDK 路径当场可走';
    } else if (writeRejected > 0) {
      // 这条分支必须存在：上一轮就是被它救回来的——写都没写进去，
      // 却把结论写成「鉴权拦在前面」，那是把我们的 bug 记成厂商的墙。
      verdict = '全部沉默，但其中 $writeRejected/$total 条**下发就被拒**。'
          '鉴权问题还没问到，先修写类型/属性匹配';
    } else {
      verdict = '全部沉默且每条都确认下发成功 → 命令确实没被接受。'
          '是「没初始化」还是「没鉴权」，由后面两轮分辨，不在这里下结论';
    }
    log('[L1] 结论: $verdict');
    final afterKey = await _runAfterHandshake(answered, writeRejected);
    final afterInit = await _runInitRound(afterKey);

    // 三轮对照一次说清，免得下一个人只看见最后一轮
    log('[L1] 三轮对照: 裸发 $answered/$total → 冒充 sdkkey $afterKey/$total → '
        '明文初始化 $afterInit/$total。');
    final String gate;
    if (afterInit > answered) {
      gate = '初始化才是闸门，不是鉴权 → rtc/ostype 是明文可复现的，'
          '换掉厂商 SDK 这条路不用碰 libSDK.so';
    } else if (afterKey > answered) {
      gate = '那帧 sdkkey 起了作用 → 载荷得由 native 生成，得向厂商要算法';
    } else {
      gate = '三轮都没改变任何结果 → 命令闸门既不是初始化也不是我们试得起的那帧 '
          'sdkkey（厂商线上载荷由 Auth.init() 生成，冒充无效已被实测确认）；'
          '下一步只剩厂商 AAR 对照与 HCI 取证';
    }
    log('[L1] 闸门判读: $gate');
    // 必须放最后：这一档会把裸客户端断开，射频让给厂商 AAR
    if (vendorControl) await _runVendorControl();
  }

  /// 第二轮：把 AppKey 当作 sdkkey 载荷发一遍，再问同一批查询。
  ///
  /// 顺序是刻意的——**先跑不握手那一轮**，否则「鉴权到底拦不拦」就永远问不出来了。
  /// 但要说清楚：厂商线上那 16 字节由 `Auth.init()`（JNI，在 libSDK.so 里）生成，
  /// 这一轮发的是**冒充值**，沉默不能当成「鉴权不是墙」的证据；
  /// 它唯一能证明的是「拿 AppKey 字符串顶上不行」。
  Future<int> _runAfterHandshake(int bareAnswered, int bareRejected) async {
    final key = Config.newviewAppKey;
    if (key.isEmpty) {
      log('[L1] 计划文件未给 appkey=，跳过握手轮');
      return bareAnswered;
    }
    // AAR `NvEasyBleBluetooth.a/b(byte[])` 要求载荷正好 16 字节
    // （不满足直接 IllegalArgumentException("param is wrong!")）。
    // 16 个 hex 字符按 ASCII 传正好 16B；hex 解码只有 8B，过不去那道校验。
    final ascii = NewviewRaw.keyAsAscii(key);
    final hexBytes = NewviewRaw.keyAsHexBytes(key);
    final payload = ascii.length == 16
        ? ascii
        : (hexBytes != null && hexBytes.length == 16 ? hexBytes : ascii);
    log('[L1] 握手轮：sdkkey 载荷取 ${payload.length}B '
        '(${identical(payload, ascii) ? "ASCII 原样" : "hex 解码"})，'
        '整帧 ${NewviewRaw.sdkKeyFrame(payload).length}B');
    final auth = await client.exchangeRaw(
      NewviewRaw.sdkKeyFrame(payload),
      label: '*APP#sdkkey#***(len=${payload.length})#',
      timeout: const Duration(seconds: 6),
    );
    log('[L1] sdkkey → ${_describeReply(auth)}');

    var answered = 0;
    for (final name in NewviewRaw.readOnlyCommands) {
      final r = await client.exchangeText(
        NewviewRaw.command(name),
        timeout: const Duration(seconds: 3),
      );
      if (r.heard) answered++;
      log('[L1] 握手后 $name → ${_describeReply(r)}');
    }
    return answered;
  }

  String _describeReply(NewviewExchangeResult r) {
    if (!r.heard) return '无回包（${r.writeStatus ?? "未写"}）';
    final bytes = r.bytes;
    final text = r.text;
    final kind = _replyKind(text);
    final shape = kind == null
        ? '非 *DEV# 形状'
        : NewviewRaw.shapeVerdict(kind, r.fields);
    return '${bytes.length}B/${r.chunks.length}包 '
        '「${NewviewRaw.redact(NewviewRaw.printable(bytes.length > 60 ? bytes.sublist(0, 60) : bytes))}」 '
        '$shape';
  }

  static String? _replyKind(String text) {
    for (final k in NewviewRaw.kotlinExpectedFieldCounts.keys) {
      if (text.startsWith('${NewviewRaw.responsePrefix}$k#')) return k;
    }
    if (text.startsWith(NewviewRaw.streamPrefix)) return 'stream';
    final seg = text.split('#');
    return seg.length > 1 && seg[0] == '*DEV' ? seg[1] : null;
  }

  // ------------------------------------------------------------------
  // L2 录音 + 实时推流
  // ------------------------------------------------------------------

  Future<void> _runRecord() async {
    final mode = 0; // 会议模式；广播位若只支持通话，下一步再按 mask 换
    final rate = 1; // 16k
    log('[L2] 开始录音（会在设备上生成一条新录音）record#1#$mode#$rate#');
    final start = await client.exchangeText(
      NewviewRaw.recordCommand(1, mode, rate),
      timeout: const Duration(seconds: 4),
    );
    log('[L2] record#1 → ${_describeReply(start)}');

    final stream = await client.listenOnly(8);
    _reportStream(stream);

    log('[L2] 暂停 record#2');
    final pause = await client.exchangeText(
      NewviewRaw.recordCommand(2, mode, rate),
      timeout: const Duration(seconds: 4),
    );
    log('[L2] record#2 → ${_describeReply(pause)}');
    log('[L2] 恢复 record#3');
    final resume = await client.exchangeText(
      NewviewRaw.recordCommand(3, mode, rate),
      timeout: const Duration(seconds: 4),
    );
    log('[L2] record#3 → ${_describeReply(resume)}');
    log('[L2] 停止 record#0');
    final stop = await client.exchangeText(
      NewviewRaw.recordCommand(0, mode, rate),
      timeout: const Duration(seconds: 4),
    );
    log('[L2] record#0 → ${_describeReply(stop)}');
  }

  void _reportStream(List<List<int>> packets) {
    if (packets.isEmpty) {
      log('[L2] 实时流: 8s 内一包都没有 → SDK 的 `*DEV#stream#` 前缀假设在这台机器上未成立');
      return;
    }
    final first = packets.first;
    final text = utf8.decode(first, allowMalformed: true);
    if (!text.startsWith(NewviewRaw.streamPrefix)) {
      log('[L2] 实时流: 首包不是 stream 前缀，${first.length}B '
          '${NewviewRaw.hex(first.take(32).toList())}「${NewviewRaw.printable(first.take(32).toList())}」');
      return;
    }
    final h = NewviewRaw.parseStreamHeader(first);
    final total = packets.expand((e) => e).length;
    log('[L2] 实时流: ${packets.length}包/${total}B 头判据 ${h.reason}');
    if (h.frame > 0 && h.total > 0) {
      final bodyBytes = total - h.headerBytes;
      log('[L2] 实时流: 首包后正文 ${bodyBytes}B，按 frame=${h.frame}B '
          '应还能拆 ${bodyBytes ~/ h.frame} 帧；'
          'Kotlin 判据「total % frame == 0」= '
          '${h.total % h.frame == 0 ? "PASS" : "MISMATCH 余 ${h.total % h.frame}B，finishAudioIfComplete 会抛"}');
    }
  }

  // ------------------------------------------------------------------
  // L3 文件面
  // ------------------------------------------------------------------

  Future<void> _runFiles() async {
    for (final name in ['getlist', 'listreq', 'mem']) {
      final r = await client.exchangeText(
        NewviewRaw.command(name),
        timeout: const Duration(seconds: 8),
      );
      log('[L3] $name → ${_describeReply(r)}');
      if (r.heard) {
        final bytes = r.bytes;
        log('[L3] $name 原始首 96B: '
            '${NewviewRaw.hex(bytes.take(96).toList())}');
      }
    }
    await _runFilePaging();
    await _runFileDownloadProbe();
    if (allowOpusFormatSelect) {
      final r = await client.exchangeText(
        '*APP#opusfile#1#',
        timeout: const Duration(seconds: 5),
      );
      log('[L3] opusfile#1（计划文件显式开启）→ ${_describeReply(r)}');
    } else {
      log('[L3] opusfile 跳过：会改设备下载格式选择，需计划文件 opusfile=1 显式开启');
    }
    // filecmd 的入参形状厂商没写清，这里只**裸发一次看它要什么**，
    // 不做任何参数穷举（Xyrix 那轮穷举的教训：先让设备自己把格式叫出来）
    final fc = await client.exchangeText(
      NewviewRaw.command('filecmd'),
      timeout: const Duration(seconds: 5),
    );
    log('[L3] filecmd 裸发 → ${_describeReply(fc)}');
  }

  /// 列表分页：真机对裸 `*APP#listreq#` 回的是 `*DEV#flist#985#3#`，
  /// 两轮分别是 985 与 1152（文件数 6→7），同一个尾数 3 —— 这不是列表正文，
  /// 是**表头**（大概率 `flist#<正文总字节>#<页数>#`）。正文要带页参数才推。
  /// AAR 字节码里 `FilesReceiver.b(int,int)` 构造 `*APP#listreq#<p1>#<p2>#`，
  /// 它的两个**真实调用点**给出了参数语义（不再靠猜）：
  ///  - 起手（`getFilesList` 路径）：先把 `f=1`、`g=0` 置好，再 `b(0, 1)`
  ///    → `*APP#listreq#0#1#`。所以第一个参数是**模式码**（0=起），不是页号；
  ///  - 重发（日志串 `file list packet not match:` 那条）：`b(2, f)`
  ///    → `*APP#listreq#2#<期望包号>#`，即「按包号要那一片」。
  /// 上一轮 7 档全按「页号 + 条数/字节」猜，方向就错了。
  /// 监听窗口拉到 15 s，并且每档前先发 `getlist` 重建列表会话（AAR 就是这顺序）——
  /// 表头是立刻回的，正文若紧随其后，6 s 窗口可能只抓到表头就收队。
  Future<void> _runFilePaging() async {
    const candidates = <String, String>{
      '*APP#listreq#0#1#': 'AAR 起手 b(0,1)',
      '*APP#listreq#2#1#': 'AAR 重发 b(2,包号) 包号=1',
      '*APP#listreq#2#2#': 'AAR 重发 b(2,包号) 包号=2',
      '*APP#listreq#2#3#': 'AAR 重发 b(2,包号) 包号=3',
      '*APP#listreq#2#4#': 'AAR 重发 b(2,包号) 包号=4',
    };
    for (final entry in candidates.entries) {
      await client.exchangeText(
        NewviewRaw.command('getlist'),
        timeout: const Duration(seconds: 3),
      );
      final r = await client.exchangeText(entry.key, timeout: const Duration(seconds: 15));
      final text = r.text.trim();
      final looksJson = text.contains('{') || text.contains('[');
      log('[L3] 分页 ${entry.value} ${entry.key} → '
          '${r.heard ? '${r.bytes.length}B/${r.chunks.length}包' : "无回包"}'
          '${looksJson ? "  ★拿到 JSON 正文" : ""}');
      if (r.heard) {
        log('[L3]   可读: ${text.length > 400 ? "${text.substring(0, 400)}…" : text}');
      }
      if (looksJson) {
        log('[L3] 分页判据成立：正文按「${entry.value}」这一档取，'
            'SDK 的 FilePage/nextCursor 就按它接');
        await _dumpCapture(r.bytes, 'l3_flist_body');
        // 帧形状已从 AAR 字节码 + 线上实测确定：
        //   表头  *DEV#flist#<正文总字节>#<页数>#
        //   每页  *DEV#listreq#<页号>#<该页正文字节>#<校验># + 紧接的 JSON 分片
        // 现在把剩下的页走完：假设「模式 0 + 页号」就是取第 N 页，
        // 用总字节数当收满判据（不许猜完就写进 SDK，必须凑齐并解析成数组）。
        final header = RegExp(r'\*DEV#flist#(\d+)#(\d+)#').firstMatch(r.text);
        if (header == null) return;
        final totalBytes = int.parse(header.group(1)!);
        final pages = int.parse(header.group(2)!);
        var body = _flistBodyOf(r.text);
        log('[L3] 表头声明正文 $totalBytes B / $pages 页；已收 ${body.length} B');
        for (var page = 2; page <= pages && body.length < totalBytes; page++) {
          final pr = await client.exchangeText(
            '*APP#listreq#0#$page#',
            timeout: const Duration(seconds: 12),
          );
          final chunk = _flistBodyOf(pr.text);
          if (chunk.isEmpty) {
            log('[L3] 第 $page 页无正文（${_describeReply(pr)}）→ 取页参数假设不成立，停下');
            return;
          }
          body += chunk;
          log('[L3] 第 $page 页 +${chunk.length} B，累计 ${body.length}/$totalBytes B');
        }
        try {
          final decoded = jsonDecode(body) as List;
          log('[L3] ★正文拼齐并解析成功：${decoded.length} 条记录，'
              '字段=${(decoded.first as Map).keys.join(",")}');
          await _dumpCapture(utf8.encode(body), 'l3_flist_full');
          log('[L3] 完整 JSON 已落盘 newview_l3_flist_full_*.bin，'
              'SDK 的 storage.files 解码器按这份真实向量写');
        } catch (e) {
          log('[L3] 拼完仍解析失败（$e）；累计 ${body.length} B，不把半截格式写进 SDK');
        }
        return;
      }
    }
    log('[L3] AAR 的两档真实形状（起 0#1、重发 2#<包号>）都拿不到 JSON 正文 → '
        '列表正文这一层仍然只在厂商二进制里，不许凭猜把 flist/transfer.file 写进 SDK');
  }

  /// 从一批 `*DEV#…#` 合并帧里剥出所有 `listreq` 页的 JSON 正文。
  /// 页头形状（实测）：`*DEV#listreq#<页号>#<该页字节>#<校验>#`。
  String _flistBodyOf(String text) {
    final parts = <String>[];
    var start = 0;
    while (true) {
      final next = text.indexOf('*DEV#', start + 1);
      parts.add(text.substring(start, next < 0 ? text.length : next));
      if (next < 0) break;
      start = next;
    }
    final buf = StringBuffer();
    for (final p in parts) {
      if (!p.startsWith('*DEV#listreq#')) continue;
      final rest = p.substring('*DEV#listreq#'.length);
      final head = RegExp(r'^(\d+)#(\d+)#(\d+)#').firstMatch(rest);
      buf.write(head == null ? rest : rest.substring(head.end));
    }
    return buf.toString();
  }

  /// BLE 文件下载：AAR 字节码形状
  /// `opusfile#<sn>#<packet>#<isDelete>#<flag>#<offset>#`。
  /// isDelete=false、offset=0 的下载是**只读**操作，安全，可以发。
  /// 拿到的正文形状决定 SDK 里 `transfer.file` 的解码器要不要自己切块
  /// （Xyrix 那边是「8B 小端长度 + Opus 包」，这家大概率是定长 80B 包，
  ///  因为文件尺寸全部能被 packetSize 整除）。
  /// BLE 下载。参数语义不再猜，取自 AAR 字节码：
  ///  - `FilesReceiver$ResponseCmd` 的 `static{}` 给出
  ///    **`STOP_DOWNLOAD.cmd() = 0`、`READY.cmd() = 1`**，
  ///    所以下载前要先发 `*APP#filecmd#1#`（READY）把传输装上膛；
  ///    之前探测台只裸发过 `*APP#filecmd#`（无参数），当然什么都等不到 ——
  ///    「opusfile 四种形状全无回包」那个结论在此之前是不成立的。
  ///  - 两种帧形状（`FilesReceiver` 里两处 StringBuilder）：
  ///    A: `opusfile#<a>#<b>#<c>#<m:Z>#<d>#`
  ///    B: `opusfile#2#<a>#<b>#<m:Z>#<c>#`
  ///  两档都真发一遍，并先记下 `filecmd#1#` 自己有没有回包（那是又一个接口面）。
  Future<void> _runFileDownloadProbe() async {
    final arm = await client.exchangeText(
      '*APP#filecmd#1#',
      timeout: const Duration(seconds: 6),
    );
    log('[L3] 上膛 filecmd#1#(READY) → ${_describeReply(arm)}');
    final stop = await client.exchangeText(
      '*APP#filecmd#0#',
      timeout: const Duration(seconds: 6),
    );
    log('[L3] 对照 filecmd#0#(STOP_DOWNLOAD) → ${_describeReply(stop)}');
    // 停完再上一次膛，后面的 opusfile 才在 READY 状态下发
    await client.exchangeText('*APP#filecmd#1#', timeout: const Duration(seconds: 4));
    await client.exchangeText(
      NewviewRaw.command('getlist'),
      timeout: const Duration(seconds: 3),
    );
    const shapes = <String, String>{
      'B（opusfile#2#sn#包号#m#偏移#）': '*APP#opusfile#2#%SN%#1#0#0#',
      'A（opusfile#sn#包号#a#m#偏移#）': '*APP#opusfile#%SN%#1#0#0#0#',
    };
    for (final entry in shapes.entries) {
      for (final sn in const [3, 2]) {
        final r = await client.exchangeText(
          entry.value.replaceAll('%SN%', '$sn'),
          timeout: const Duration(seconds: 10),
        );
        if (!r.heard) continue;
        final b = r.bytes;
        final mod80 = b.length % 80;
        log('[L3] 下载 ${entry.key} sn=$sn → ${b.length}B/${r.chunks.length}包 '
            '前 48B=${NewviewRaw.hex(b.take(48).toList())}');
        log('[L3]   判据：长度 %80='
            '${mod80 == 0 ? "0，与 packetSize=80 定长包一致" : "${mod80}B，说明有头/不是定长"}'
            '；首包可读「${NewviewRaw.printable(b.take(32).toList())}」');
        await _dumpCapture(b, 'l3_dl_${entry.key.hashCode}_sn$sn');
        return;
      }
      log('[L3] 下载形状「${entry.key}」两档 sn 在 READY 上膛后仍无回包');
    }
    log('[L3] filecmd 上膛 + 两种帧形状都无回包 → 请求帧这一层仍在厂商二进制里，'
        '不许凭猜把 transfer.file 写进 Raw Definition');
  }

  /// 把抓到的字节落盘，方便离线逐字节判容器形状（不塞进日志）。
  Future<void> _dumpCapture(List<int> bytes, String tag) async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return;
      final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
      final f = File('${dir.path}/newview_${tag}_$ts.bin');
      await f.writeAsBytes(bytes, flush: true);
      log('[L3] 已落盘 ${f.path}（${bytes.length}B）');
    } catch (e) {
      log('[L3] 落盘失败: $e');
    }
  }

  // ------------------------------------------------------------------
  // L4 WiFi 快传开关
  // ------------------------------------------------------------------

  Future<void> _runWifi() async {
    String? ssid;
    try {
      final open = await client.exchangeText(
        NewviewRaw.wifiCommand(true),
        timeout: const Duration(seconds: 8),
      );
      log('[L4] wifi#1 → ${_describeReply(open)}');
      final f = open.fields;
      // 真机（2026-10-23 09:06，同一台卡）回的是 **9 段**：
      // `*DEV | wifi | 开关回显 | serverIp | serverPort | clientIp | clientPort | ssid | pwd`。
      // 之前这里写死 8 段，所以凭据帧一直在走 MISMATCH 分支——
      // 「设备不回凭据」那个结论就是这么来的（列位差一格，等于什么都没解出来）。
      // 两种形状都收：9 段按真机取，8 段留给「没有回显位」的情况，但默认按真机。
      final base = f.length == 9 ? 1 : (f.length == 8 ? 0 : -1);
      if (base >= 0 && f[1] == 'wifi') {
        // 字段顺序取自厂商回调 onWifiOpened(serverIp, port, clientIp, port, ssid, pwd)
        final parsed = NewviewWifiFields(
          serverIp: f[2 + base],
          serverPort: f[3 + base],
          clientIp: f[4 + base],
          clientPort: f[5 + base],
          ssid: f[6 + base],
          password: f[7 + base],
        );
        log('[L4] wifi PASS ${f.length}段 服务端 ${parsed.serverIp}:${parsed.serverPort} '
            '客户端 ${parsed.clientIp}:${parsed.clientPort} '
            'AP=***(len=${parsed.ssid.length}) 口令已写进手机上的 newview_ap.txt（不落日志、不进仓库）');
        ssid = parsed.ssid;
        await _writeApFile(parsed);
        /**
         * App 自己在 Android 12 上入不了网（`WifiNetworkSuggestion` 要用户点确认，
         * 而 `_hotspot.connect` 那一下还会把已经关联上的网络拽掉）。
         * 所以留一条后门：**手机上存在 `newview_nojoin` 这个空文件时**，
         * 探测台不碰 WiFi，只等外部（`adb shell cmd wifi connect-network`）先关联上，
         * 再跑 TCP 判据。否则「TCP 连不上」永远分不清是卡不服务还是自己把网断了。
         */
        final dir = await getExternalStorageDirectory();
        final noJoin = dir != null &&
            await File('${dir.path}/newview_nojoin').exists();
        if (noJoin) {
          // 后门存在时不只跳过入网，还可以用 `newview_hold.txt` 里写的秒数
          // 把热点**按住**（默认 30 s）——台架侧要用笔记本入网再测 TCP，
          // 30 s 不够写完 profile、关联、再探测。手机自己不碰 WiFi，
          // BLE 就不会因为 2.4 G 抢占而掉，热点也就不会被卡自己收掉。
          var seconds = 30;
          final holdFile = dir == null ? null : File('${dir.path}/newview_hold.txt');
          if (holdFile != null && await holdFile.exists()) {
            seconds = int.tryParse(await holdFile.readAsString()) ?? seconds;
          }
          final clamped = seconds.clamp(5, 300);
          log('[L4] 计划后门 newview_nojoin 在 → 跳过 App 入网，热点按住 $clamped s'
              '（关联由台架侧的笔记本/`cmd wifi` 做，不看这里）');
          await Future<void>.delayed(Duration(seconds: clamped));
        } else {
          final join = await _join(parsed.ssid, parsed.password);
          log('[L4] 入网: $join');
          // App 既然连上了，就顺手用它自己那条网络问设备：这条 socket 认哪种命令写法
          // （矩阵第 14.3 节）。Dart 的 Socket 绑不了 specifier 网络，所以走原生。
          final probe = await _hotspot.joinAndProbeTcp(
            ssid: parsed.ssid,
            password: parsed.password,
            host: parsed.serverIp,
            port: int.tryParse(parsed.serverPort) ?? 0,
          );
          log('[L4] 原生 TCP 判据: ' + probe.toString());
        }
        // 入网之后才是**数据通道**：能不能连上服务端口、连上之后对面说什么。
        // 「拿到凭据」不等于「快传可用」，这一步才是 transfer.wifi 该不该声明的判据。
        log('[L4] TCP ${parsed.serverIp}:${parsed.serverPort} → '
            '${await _tcpProbe(parsed.serverIp, int.tryParse(parsed.serverPort) ?? 0)}');
      } else if (open.heard) {
        log('[L4] wifi MISMATCH 回包存在但既不是 9 段也不是 8 段 wifi：'
            '${f.length}段(${f.join("|")})');
      } else {
        log('[L4] wifi#1 无回包（${open.writeStatus}）→ BLE 控制面这条就没通');
      }
    } finally {
      // 收尾：热点不能留着。关 wifi + 移掉系统里的网络建议，两步都不能省
      final close = await client.exchangeText(
        NewviewRaw.wifiCommand(false),
        timeout: const Duration(seconds: 4),
      );
      log('[L4] wifi#0 收尾 → ${_describeReply(close)}');
      if (ssid != null) {
        try {
          await _hotspot.disconnect(ssid);
        } catch (_) {}
      }
    }
  }

  /// 数据通道判据：能不能真的把 TCP 连上，以及连上之后对面先说什么。
  /// 这里刻意**不**发任何文件请求——先只观察「可连接 + 首包」，
  /// 因为帧格式（厂商 `WifiMessenger`）还没取证，乱发只会把设备带进未知状态。
  Future<String> _tcpProbe(String host, int port) async {
    if (host.isEmpty || port <= 0) return '参数不全（host=$host port=$port）';
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 6));
      final got = <int>[];
      final done = Completer<void>();
      final sub = socket.listen((chunk) {
        got.addAll(chunk);
        if (got.length > 512 && !done.isCompleted) done.complete();
      }, onError: (Object _) {
        if (!done.isCompleted) done.complete();
      }, onDone: () {
        if (!done.isCompleted) done.complete();
      });
      await done.future.timeout(const Duration(seconds: 3), onTimeout: () {});
      await sub.cancel();
      await socket.close();
      final preview = got.take(48).toList();
      return '可连接；首包 ${got.length}B'
          '${got.isEmpty ? "（3 s 内没主动说话，属于「连上要自己发请求」那一型）" : ""}'
          ' 前 ${preview.length}B=${NewviewRaw.hex(preview)}';
    } catch (e) {
      return '连不上：$e';
    }
  }

  Future<String> _join(String ssid, String password) async {
    try {
      await _hotspot.connect(ssid, password);
    } on HotspotException catch (e) {
      return '系统拒绝建议 ${e.code}: ${e.message}';
    }
    final until = DateTime.now().add(const Duration(seconds: 30));
    var last = '';
    while (DateTime.now().isBefore(until)) {
      final r = await _hotspot.currentSsid();
      last = r.ssid;
      // 注意 Android 的 getSsid() 带首尾双引号，不比裸值会误判「没连上」
      // 两个名字都不进文案：设备热点名是凭据的一部分，`last` 还可能读到用户自己家的 Wi-Fi。
      if (r.linked && r.ssid.replaceAll('"', '') == ssid) {
        return '已连上设备热点（AP=***(len=${ssid.length})）';
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return '未连上（当前 ${last.isEmpty ? "读不到 SSID，缺定位权限=观测失效" : "***(len=${last.length})"}）';
  }

  /// 凭据只落在手机上，报告里只留掩码——契约规定 SSID/口令不进公共日志
  Future<void> _writeApFile(NewviewWifiFields f) async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return;
      await File('${dir.path}/newview_ap.txt')
          .writeAsString('${f.ssid}:${f.password} host=${f.serverIp}:${f.serverPort}\n');
    } catch (_) {}
  }
}

class NewviewWifiFields {
  final String serverIp;
  final String serverPort;
  final String clientIp;
  final String clientPort;
  final String ssid;
  final String password;

  const NewviewWifiFields({
    required this.serverIp,
    required this.serverPort,
    required this.clientIp,
    required this.clientPort,
    required this.ssid,
    required this.password,
  });
}
