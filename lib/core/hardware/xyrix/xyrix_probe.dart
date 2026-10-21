/// Xyrix SDK 全命令面真机探测台。
///
/// 存在的理由：命令表里多条命令的**响应格式厂商文档没写清**（0x2E 存储字节布局、
/// 0x20/0x21 热点凭证格式、0x50 系列 OPUS 回执、0x1A 卡状态），靠猜实现等于把
/// 协议债写进产品。本类把这些未知量一次性打到真机上，用日志留下证据，
/// 再按实测字节写解析。
///
/// 分级执行，**破坏性命令默认不跑**：
/// - level 1 只查询（改名/重启/删除一律不碰）
/// - level 2 录音生命周期（会在设备上生成一条新录音）
/// - level 3 蓝牙下载 + 0x48 停止
/// - level 4 热点链路（0x20/0x21 → 关 0x23）
/// - level 5 破坏性（0x02 改名并复原、0x03 重启蓝牙、0x12/0x1E/0x55 删除/丢弃）
library;

import 'dart:async';
import 'dart:convert';

import 'package:dting/config/config.dart';
import 'package:dting/core/hardware/models.dart';
import 'package:dting/core/hardware/xyrix/xyrix_commands.dart';
import 'package:dting/core/hardware/xyrix/xyrix_frame_codec.dart';

/// 探测台需要的宿主能力（由 XyrixAdapter 实现，便于单测替换）
abstract class XyrixProbeHost {
  /// 发一条命令并等它的响应帧。
  ///
  /// 「先登记等待方、再写特征」是硬性要求：真机对 0x01/0x17 的回帧在 GATT 写
  /// 回调后 100ms 内就到，若先发后登记，帧会被业务分发吃掉、探测台误报
  /// NO_RESPONSE（2026-10-05 首跑就是这么假的）。
  /// 超时返回 null —— 「设备不响应」本身就是要记录的实测结论。
  Future<XyrixFrame?> exchange(
    int command,
    List<int> data, {
    int? expect,
    Duration timeout = const Duration(seconds: 3),
  });

  Future<List<RecordingFile>> listFiles();

  /// 走完整 BLE 下载闭环（0x07→0x2D→收流→完整性校验），返回一行结论
  Future<String> runBleDownload();

  /// 录音→暂停→恢复→停止，按实时推流包数与设备文件数变化判定效果
  Future<String> runRecordLifecycle();

  /// 走一遍 WiFi 快传闭环（配 `Config.wifiServerOverride` 即数据通路自检）
  Future<String> runWifiDownload();

  /// 试探本卡是否讲厂商 AAR（com.nveasy.ble）那套 `*APP#…#` 文本命令
  Future<String> runTextCommandProbe();

  /// 打印 GATT 全表（服务/特征/属性/描述符）+ 可选 MTU 请求
  Future<String> runGattSurvey();

  /// 把手机加入指定热点并在 [seconds] 内轮询，返回一行实测结论。
  /// 「系统收下了建议」和「真的连上了」是两件事，探测台只认后者
  Future<String> joinHotspot(String ssid, String password, int seconds);

  Future<void> hold(int seconds, String why);

  void log(String line);
}

/// 一条探测步骤
class XyrixProbeStep {
  final String name;
  final int command;
  final List<int> Function() data;
  final int minLevel;

  /// 期望的响应命令码，默认与 [command] 相同
  final int? responseCommand;

  /// 该步骤是否会改变设备状态（录音/文件/蓝牙），用于日志标注
  final bool mutating;

  /// 收到响应后再等这么久——用于「设备需要时间把热点拉起来」这类观测，
  /// 观测窗口必须比命令间隔长，否则会被下一步的收尾命令掐掉
  final int holdSeconds;

  /// 非空则不调命令，改跑这段动作（如完整下载闭环）
  final Future<String> Function()? action;

  const XyrixProbeStep({
    required this.name,
    required this.command,
    required this.minLevel,
    this.data = _empty,
    this.responseCommand,
    this.mutating = false,
    this.holdSeconds = 0,
    this.action,
  });

  static List<int> _empty() => const [];
}

class XyrixProbe {
  final XyrixProbeHost host;

  /// 当前已连接设备名，level 5 改名后按它复原
  final String? deviceName;

  XyrixProbe(this.host, {this.deviceName});

  static const int levelReadOnly = 1;
  static const int levelRecord = 2;
  static const int levelTransfer = 3;
  static const int levelHotspot = 4;
  static const int levelDestructive = 5;

  /// 设备文件名，供 0x04/0x12 等按路径寻址的步骤现取现用
  List<RecordingFile> _files = const [];

  /// 运行 [level] 及以下的全部步骤，返回逐步骤结论。
  ///
  /// [onlyLevel] 非 0 时**只跑该等级的步骤**：部分命令（如 0x24）会把本版固件
  /// 打进不应答状态，混在一起跑会让后面的步骤全部假阴性，必须能单独隔离。
  Future<List<String>> run(int level, {int onlyLevel = 0}) async {
    final only = onlyLevel;
    final effective = only != 0 ? only : level;
    final out = <String>[];
    host.log(
      '===== Xyrix SDK 探测开始 level=$level'
      '${only != 0 ? "（仅 L$only）" : ""} =====',
    );
    try {
      _files = await host.listFiles();
      host.log('列表可得 ${_files.length} 个文件');
    } catch (e) {
      host.log('列表刷新失败: $e（后续按路径寻址的步骤会被跳过）');
    }

    for (final step in _steps) {
      if (only != 0 ? step.minLevel != only : step.minLevel > level) continue;
      if (step.mutating && step.command == XyrixCommands.rebootBt) {
        continue; // 单独收尾
      }
      out.add(await _runStep(step));
      // 观测窗口：蓝牙有没有回应都不影响设备是否真的把热点拉起来了，
      // 所以 hold 放在步骤之后而不是响应分支里
      if (step.holdSeconds > 0) {
        host.log('保持 ${step.holdSeconds}s 观测窗口（${step.name}）');
        await Future<void>.delayed(Duration(seconds: step.holdSeconds));
      }
    }

    if (effective >= levelDestructive) {
      // 0x03 会断开 GATT，必须放在最后
      out.add(
        await _runStep(
          const XyrixProbeStep(
            name: 'rebootBt',
            command: XyrixCommands.rebootBt,
            minLevel: levelDestructive,
            mutating: true,
          ),
        ),
      );
    }
    host.log('===== Xyrix SDK 探测结束 =====');
    return out;
  }

  List<XyrixProbeStep> get _steps => [
    // ---- level 1：只查询 ----
    XyrixProbeStep(
      name: 'gattSurvey',
      command: XyrixCommands.queryBattery,
      minLevel: 1,
      action: host.runGattSurvey,
    ),
    const XyrixProbeStep(
      name: 'queryBattery',
      command: XyrixCommands.queryBattery,
      minLevel: 1,
    ),
    const XyrixProbeStep(
      name: 'queryVersion',
      command: XyrixCommands.queryVersion,
      minLevel: 1,
    ),
    const XyrixProbeStep(
      name: 'queryStorage',
      command: XyrixCommands.queryStorage,
      minLevel: 1,
    ),
    const XyrixProbeStep(
      name: 'queryDeviceId',
      command: XyrixCommands.queryDeviceId,
      minLevel: 1,
    ),
    const XyrixProbeStep(
      name: 'recordCardStatus',
      command: XyrixCommands.recordCardStatus,
      minLevel: 1,
    ),
    const XyrixProbeStep(
      name: 'syncTime',
      command: XyrixCommands.syncTime,
      minLevel: 1,
      data: _syncTimeData,
      responseCommand: XyrixCommands.commandAck,
    ),
    XyrixProbeStep(
      name: 'fileList',
      command: XyrixCommands.fileList,
      minLevel: 1,
      data: () => XyrixFrameCodec.pathData('0:/ .wav'),
    ),
    XyrixProbeStep(
      name: 'fileInfo',
      command: XyrixCommands.fileInfo,
      minLevel: 1,
      data: _firstFilePath,
      responseCommand: XyrixCommands.fileInfo,
    ),

    // ---- level 2：录音生命周期 ----
    // 本版固件对录音类命令一律不回回执（L1 逐条实测），发一遍命令码只能证明
    // 「写了进去」，证明不了「设备开始/暂停录音」。所以这一步改看行为：
    // 0x54 推流包数的起停 + 设备上文件数的增减。
    XyrixProbeStep(
      name: 'recordLifecycle',
      command: XyrixCommands.recordStart,
      minLevel: 2,
      mutating: true,
      action: host.runRecordLifecycle,
    ),
    // 以下命令族回执与语义均未确认，只在显式隔离实验（L5）时才发，
    // 避免污染同一次运行里其它步骤的观测
    // 本卡一贯按 FF55AA 二进制帧对话；这条一次性核对它是否同时认厂商 AAR 的
    // `*APP#…#` 文本命令。认的话，WiFi 快传与 opusfile 的规则就能从厂商代码里读，
    // 不必再猜。放 L5 是为了不污染同一次运行里其它步骤的观测。
    XyrixProbeStep(
      name: 'text命令探测',
      command: 0,
      minLevel: levelDestructive,
      mutating: true,
      action: host.runTextCommandProbe,
    ),
    const XyrixProbeStep(
      name: 'opusStart',
      command: XyrixCommands.opusStart,
      minLevel: levelDestructive,
      mutating: true,
    ),
    const XyrixProbeStep(
      name: 'opusResume',
      command: XyrixCommands.opusResume,
      minLevel: levelDestructive,
      mutating: true,
    ),
    const XyrixProbeStep(
      name: 'rtStart',
      command: XyrixCommands.rtStart,
      minLevel: levelDestructive,
    ),
    const XyrixProbeStep(
      name: 'rtPause',
      command: XyrixCommands.rtPause,
      minLevel: levelDestructive,
    ),
    const XyrixProbeStep(
      name: 'rtResume',
      command: XyrixCommands.rtResume,
      minLevel: levelDestructive,
    ),
    const XyrixProbeStep(
      name: 'rtStopSave',
      command: XyrixCommands.rtStopSave,
      minLevel: levelDestructive,
      mutating: true,
    ),
    const XyrixProbeStep(
      name: 'recordWithTransfer',
      command: XyrixCommands.recordWithTransfer,
      minLevel: levelDestructive,
      mutating: true,
    ),

    // ---- level 3：蓝牙下载闭环（0x07→0x2D→收流→完整性校验）----
    XyrixProbeStep(
      name: 'bleDownloadSmallest',
      command: XyrixCommands.transferPrepareJl,
      minLevel: levelTransfer,
      mutating: true,
      action: host.runBleDownload,
    ),

    // ---- level 4：热点链路凭证格式（0x21 的确切响应就靠这一步）----
    const XyrixProbeStep(
      name: 'openHotspot',
      command: XyrixCommands.openHotspot,
      minLevel: levelHotspot,
    ),
    // 热点拉起需要时间，且手机侧扫描是异步的：观测窗口必须比命令间隔长，
    // 否则 AP 还没广播出来就被下一步 closeWifi 掐掉，得出「设备不开热点」的假结论
    const XyrixProbeStep(
      name: 'openHotspotTcp',
      command: XyrixCommands.openHotspotTcp,
      minLevel: levelHotspot,
      holdSeconds: 25,
    ),
    XyrixProbeStep(
        name: 'wifi状态机对账',
        command: -1,
        minLevel: levelHotspot,
        action: probeWifiState),
    XyrixProbeStep(
      name: 'hotspot凭证hunt',
      command: XyrixCommands.hiddenHotspot,
      minLevel: levelHotspot,
      mutating: true,
      action: () => Config.wifiApCredential.isNotEmpty
          // 带外参数已经拿到（计划文件 `ap=`），4 分钟的规则穷举就没有必要了，
          // 而且它会反复发 0x11 改热点名——能不发就不发
          ? Future.value('已配置带外 AP 参数，跳过热点凭证 hunt')
          : Config.wifiServerOverride.isEmpty
          // 真·找规则时才跑这 4 分钟穷举；替身服务器模式下跳过，
          // 让「数据通路自检」能反复快速迭代
              ? huntHotspotCredentials()
              : Future.value('替身服务器模式，跳过热点凭证 hunt'),
    ),
    // WiFi 快传闭环。三种参数决定它跑成什么：
    //   `tcp=ip:port` → 替身服务器，跳过开热点与入网，只验数据通路本身；
    //   `ap=SSID:密码` → 真实链路（0x21 → 入网 → 0x46 → TCP → 逐字节校验）；
    //   都不配 → 明确报「缺带外参数」，不会拿超时冒充「设备不支持」。
    XyrixProbeStep(
      name: 'wifi快传闭环',
      command: -1,
      minLevel: levelHotspot,
      mutating: true,
      action: host.runWifiDownload,
    ),
    const XyrixProbeStep(
      name: 'closeWifi',
      command: XyrixCommands.closeWifi,
      minLevel: levelHotspot,
    ),

    // ---- level 5：破坏性 ----
    XyrixProbeStep(
      name: 'setBtName(回读用原名)',
      command: XyrixCommands.setBtName,
      minLevel: levelDestructive,
      data: _currentName,
      mutating: true,
    ),
    XyrixProbeStep(
      name: 'deleteFile(仅 probe 自建的丢弃文件)',
      command: XyrixCommands.deleteFile,
      minLevel: levelDestructive,
      data: _lastFilePath,
      mutating: true,
    ),
    const XyrixProbeStep(
      name: 'recordDiscard',
      command: XyrixCommands.recordDiscard,
      minLevel: levelDestructive,
      mutating: true,
    ),
    const XyrixProbeStep(
      name: 'opusDiscard',
      command: XyrixCommands.opusDiscard,
      minLevel: levelDestructive,
      mutating: true,
    ),
  ];

  static List<int> _syncTimeData() => XyrixFrameCodec.timeData(DateTime.now());

  List<int> _firstFilePath() {
    if (_files.isEmpty) return const [];
    return XyrixFrameCodec.pathData('0:/${_files.first.name}');
  }

  List<int> _lastFilePath() {
    if (_files.isEmpty) return const [];
    final last = _files.reduce((a, b) => a.sn >= b.sn ? a : b);
    return XyrixFrameCodec.pathData('0:/${last.name}');
  }

  List<int> _currentName() => XyrixFrameCodec.pathData(deviceName ?? 'LYNSE');

  Future<String> _runStep(XyrixProbeStep step) async {
    final label = '0x${step.command.toRadixString(16).padLeft(2, '0')}';
    final action = step.action;
    if (action != null) {
      try {
        return _conclusion(step, label, 'DONE', await action());
      } catch (e) {
        return _conclusion(step, label, 'FAILED', '$e');
      }
    }
    List<int> data;
    try {
      data = step.data();
    } catch (e) {
      return _conclusion(step, label, 'SKIP', '数据组装失败: $e');
    }
    if (data.isEmpty && step.command == XyrixCommands.fileInfo) {
      return _conclusion(step, label, 'SKIP', '无文件可查');
    }
    final expected = step.responseCommand ?? step.command;
    XyrixFrame? frame;
    try {
      frame = await host.exchange(step.command, data, expect: expected);
    } catch (e) {
      return _conclusion(step, label, 'SEND_FAIL', '$e');
    }
    if (frame == null) {
      return _conclusion(step, label, 'NO_RESPONSE', '3s 内无任何响应帧');
    }
    final hex = frame.data
        .take(64)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    final asciiText = ascii
        .decode(frame.data, allowInvalid: true)
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '.');
    return _conclusion(
      step,
      label,
      frame.command == expected ? 'RESPONDED' : 'ACK_ONLY',
      'cmd=0x${frame.command.toRadixString(16)} len=${frame.data.length} '
      'hex=[$hex] ascii="$asciiText"',
    );
  }

  /// 热点凭证假设验证：0x21 实测只回状态字节、不回 SSID/密码，开完热点后手机
  /// 连扫 25s 也不见新 AP——指向「凭证是 App 经 0x11 写给设备的」，而非当前实现
  /// 假设的「设备下发凭证」。逐个试载荷编码；有回执就真开一次热点并留观测窗口，
  /// AP 到底起没起来由手机侧的 WiFi 扫描判定，不靠这里的回执下结论。
  /// 0x11（隐藏热点：热点名称 + 密码）的载荷编码 hunt。
  ///
  /// **判据换掉了。** 旧版拿「有没有回执」当 oracle，但本固件里大量命令不回话
  /// 却照样生效（录音 0x1B 系列实测全部无 ack），所以「无回执」证明不了任何事，
  /// 上一轮「四种编码全部失败」是无效结论。现在的 oracle 是**手机能不能连上
  /// 我们指定的那个 SSID/密码**——这是设备侧无法作假的外部观测：连上了，
  /// 说明卡真的按我们给的名称和口令开了 AP，编码也就是对的。
  ///
  /// 每种编码试两种发法：`0x11(名称+密码) → 0x21` 和 `0x21(名称+密码)` 直接带载荷
  /// （文档把「开 TCP 服务器」挂在 0x21 上，没说 0x21 不能带参数）。
  /// 卡的 WiFi 状态机到底动没动？
  ///
  /// 热点 hunt 的判据是「手机能不能看见/连上 AP」，那是**外部**观测；
  /// 如果卡的 WiFi 根本没被使能（比如出厂没写凭证、或要先进产线模式），
  /// 外部观测只会一直负，分不清「命令没生效」和「生效了但我们扫不到」。
  /// 这一步改成问设备自己：开热点前后各读一次 0x1A 卡状态与 0x2E 存储，
  /// 逐字节对比。有字节翻转 = 命令确实驱动了状态机，我们扫不到是频段/隐藏问题；
  /// 一字节都不变 = 命令被固件吞了，方向就该转回厂商。
  Future<String> probeWifiState() async {
    String hex(XyrixFrame? f) =>
        f == null ? '无响应' : f.data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    Future<(String, String)> snap() async => (
          hex(await host.exchange(XyrixCommands.recordCardStatus, const [],
              expect: XyrixCommands.recordCardStatus)),
          hex(await host.exchange(XyrixCommands.queryStorage, const [],
              expect: XyrixCommands.queryStorage)),
        );
    final before = await snap();
    await host.exchange(XyrixCommands.openHotspotTcp, const [],
        expect: XyrixCommands.openHotspotTcp);
    await host.hold(12, '给卡的 WiFi 状态机走完的时间');
    final after = await snap();
    final same = before.$1 == after.$1 && before.$2 == after.$2;
    return '0x1A ${before.$1} → ${after.$1}；0x2E ${before.$2} → ${after.$2}；'
        '${same ? "开热点前后设备状态一字节未变（命令被固件吞了）" : "设备状态有变化"}';
  }

  Future<String> huntHotspotCredentials() async {
    const ssid = 'LYNSEXY';
    const pwd = '12345678';
    final nul = String.fromCharCode(0);
    final variants = <String, List<int>>{
      '空格分隔': XyrixFrameCodec.pathData('$ssid $pwd'),
      '逗号分隔': XyrixFrameCodec.pathData('$ssid,$pwd'),
      'NUL分隔': XyrixFrameCodec.pathData('$ssid$nul$pwd'),
      '长度前缀': _lenPrefixed(ssid, pwd),
    };
    final tried = <String>[];
    for (final entry in variants.entries) {
      for (final withTcpCmd in [false, true]) {
        final label = '${entry.key}/${withTcpCmd ? '0x21带载荷' : '0x11+0x21'}';
        await host.exchange(
          XyrixCommands.closeWifi,
          const [],
          expect: XyrixCommands.closeWifi,
        );
        await host.hold(3, '关 WiFi，清掉上一轮的 AP 残余');
        if (withTcpCmd) {
          await host.exchange(
            XyrixCommands.hiddenHotspot,
            const [],
            expect: XyrixCommands.hiddenHotspot,
          );
          await host.exchange(
            XyrixCommands.openHotspotTcp,
            entry.value,
            expect: XyrixCommands.openHotspotTcp,
          );
        } else {
          await host.exchange(
            XyrixCommands.hiddenHotspot,
            entry.value,
            expect: XyrixCommands.hiddenHotspot,
          );
          await host.exchange(
            XyrixCommands.openHotspotTcp,
            const [],
            expect: XyrixCommands.openHotspotTcp,
          );
        }
        final joined = await host.joinHotspot(ssid, pwd, 18);
        tried.add('$label→$joined');
        host.log('[热点hunt] $label: $joined');
        if (joined.startsWith('已连上')) {
          await host.exchange(
            XyrixCommands.closeWifi,
            const [],
            expect: XyrixCommands.closeWifi,
          );
          return '命中 $label；其余 $tried';
        }
      }
    }
    await host.exchange(
      XyrixCommands.closeWifi,
      const [],
      expect: XyrixCommands.closeWifi,
    );
    // ⛔ 不再试「0xF1 写 WiFi 凭证」这条路。文档把 0xF1 记作「设置 WiFi SSID 和密码」，
    // 属于**出厂信息写入**，与 0xF4 写 SN 同一类：写错就不可恢复。2026-10-21 之前
    // 它确实被发过一次（当时以为卡的 WiFi 没被使能），而卡之后仍然广播
    // `AP_` + SN 形状的名字与固定口令，说明这条命令对本版固件没有可见效果——
    // 既然带外参数已经拿到，就没有理由再拿一张产品卡去赌它。
    host.log('[热点hunt] 跳过 0xF1 出厂凭证写入（不可恢复，且已证明对本固件无效）');
    tried.add('0xF1→按策略不再尝试');
    return '0x11 全部 ${variants.length * 2} 种发法都没让手机连上 $ssid：'
        '${tried.join(' ; ')}；真实链路请改用计划文件第二行 `ap=SSID:口令`';
  }

  static List<int> _lenPrefixed(String ssid, String pwd) => [
    ssid.length,
    ...XyrixFrameCodec.pathData(ssid),
    pwd.length,
    ...XyrixFrameCodec.pathData(pwd),
  ];

  String _conclusion(
    XyrixProbeStep step,
    String label,
    String verdict,
    String detail,
  ) {
    final line =
        '[探测] ${step.name}($label) L${step.minLevel} '
        '${step.mutating ? "变更类 " : ""}$verdict $detail';
    host.log(line);
    return line;
  }
}
