/// Newview 裸协议的**纯 Dart 镜像**，与
/// `lynse-hardware-sdk/first-device/newview/android/.../NewViewProtocolDefinition.kt`
/// 一一对应；不碰蓝牙、不碰文件，可以在 PC 上单测。
///
/// 为什么要单独一层：探测台的真机结论最终要回写进那份 Kotlin 定义，
/// 两边如果各写各的，「实测通过」验的就不是要上线的代码。这里刻意保持
/// 与 Kotlin 相同的字节偏移、相同的段数假设、相同的失败判据
/// （Kotlin 用 `throw invalidFrame`，这里用 [NewviewRaw.shapeVerdict] 报 MISMATCH），
/// 这样设备一接上，差异是**逐条可数的**，不是靠事后对源码回忆。
library;

import 'dart:convert';

/// 广播解析结果（对应 Kotlin `NewViewAdvertisementFacts`）
class NewviewAdFacts {
  final String deviceCode;
  final int protocolVersion;
  final int abilityMask;
  final String? sku;
  final int markerOffset;

  const NewviewAdFacts({
    required this.deviceCode,
    required this.protocolVersion,
    required this.abilityMask,
    required this.sku,
    required this.markerOffset,
  });

  bool hasAbility(int bit) => (abilityMask & (1 << bit)) != 0;

  /// 广播位 → SDK 声明的能力。Kotlin 里 `KNOWN_CAPABILITY_MASK` 写死这 8 位，
  /// 真机 mask 与它的差集就是「我们声明多了/少了什么」的直接证据。
  List<String> get declaredAbilities => [
    for (final entry in NewviewRaw.abilityNames.entries)
      if (hasAbility(entry.key)) entry.value,
  ];

  @override
  String toString() =>
      'code=$deviceCode ver=$protocolVersion mask=0x${abilityMask.toRadixString(16)} sku=${sku ?? "-"}';
}

/// 广播解析失败时的原因（探测台要的是「为什么解不出」，不是一个 null）
class NewviewAdFailure {
  final String reason;
  final int length;
  final int? markerOffset;
  final String hex;

  const NewviewAdFailure({
    required this.reason,
    required this.length,
    required this.markerOffset,
    required this.hex,
  });

  @override
  String toString() => '解析不出($reason, len=$length, marker=${markerOffset ?? "-"}, $hex)';
}

class NewviewRaw {
  // ---- 与 Kotlin companion object 逐字节一致的 UUID ----
  static const String primaryServiceUuid =
      '06068d0c-6b97-11ef-b864-0240ac120002';
  static const String writeCharacteristicUuid =
      '06068d1c-6b97-11ef-b864-0241ac120002';
  static const String notifyCharacteristicUuid =
      '06068d2c-6b97-11ef-b864-0242ac120002';
  static const String readCharacteristicUuid =
      '06068d3c-6b97-11ef-b864-0243ac120002';
  static const String batteryServiceUuid =
      '0000180f-0000-1000-8000-00805f9b34fb';
  static const String batteryCharacteristicUuid =
      '00002a19-0000-1000-8000-00805f9b34fb';
  static const String otaServiceUuid = '00239a6f-c616-89bb-3374-f05af588a7b3';

  static const String responsePrefix = '*DEV#';
  static const String streamPrefix = '*DEV#stream#';
  static const List<String> authenticationPrefixes = [
    '*DEV#sdkkey#',
    '*DEV#appkey#',
  ];

  /// 能力位编号（Kotlin `ABILITY_*`）
  /// 厂商完整能力位表（`NvEasyBleDevice.ABILITY_*`，与 SDK 里
  /// `protocol-definition-v1.json` 的 `abilityBits` 同源）。
  ///
  /// ⚠️ 这里必须是**厂商的全表**，不是「我们自己声明了哪几位」。
  /// 原来这张表只有 8 行（就是我们声明的那 8 位），结果真机 mask 里
  /// 明明置了 `25 rtc`，探测台报 declaredAbilities 时却把它悄悄丢掉 ——
  /// 报出来 7 项、实际 8 项，差的那位正好是没人认领的位。
  /// 表不全 = 把「我们不认识」伪装成「设备没有」。
  static const Map<int, String> abilityNames = {
    31: 'storage',
    30: 'wifi',
    29: 'meetingRecording',
    28: 'callRecording',
    27: 'meetingNoiseCancellation',
    26: 'bluetooth',
    25: 'rtc',
    24: 'mediaRecording',
    23: 'oneToOneBuds',
    22: 'wifiV2',
    21: 'childParent',
    20: 'network',
    19: 'flashNote',
    18: 'recordingMark',
    17: 'pauseResume',
  };

  /// SDK 目前写死声明的掩码，用来和真机 mask 做差集。
  ///
  /// 刻意与 [abilityNames] 分开：前者是「厂商定义了哪些位」，
  /// 后者是「我们的 Descriptor 声称支持哪些」。合成一张表的话，
  /// 差集检查就退化成恒等于 0，再也指不出「声明与本机不符」。
  static const Set<int> sdkDeclaredAbilityBits = {
    31, 30, 29, 28, 24, 22, 18, 17,
  };

  static int get knownCapabilityMask =>
      sdkDeclaredAbilityBits.fold(0, (a, b) => a | (1 << b));

  /// Kotlin `command(name)` / `recordCommand` / `wifiCommand` 的等价写法
  static String command(String name) => '*APP#$name#';
  static String recordCommand(int status, int mode, int sampleRateCode) =>
      '*APP#record#$status#$mode#$sampleRateCode#';
  static String wifiCommand(bool open) => '*APP#wifi#${open ? 1 : 0}#';

  /// 连接后的初始化两帧。出处是 `NvEasyBleBluetooth$2.onNotifySuccess()` 的字节码
  /// （CCCD 写完、厂商认为链路就绪那一刻的固定序列）：
  ///   `Auth.init()` 16B → `*APP#sdkkey#…#`
  ///   有降噪位时 `NoiseCancellation.init()` → `*APP#algkey#…#`
  ///   `"*APP#rtc#" + System.currentTimeMillis()/1000 + "#"`
  ///   `"*APP#ostype#0#"`
  /// 后两条是纯明文、不改出厂信息，探测台可以直接发；前两条的载荷由 JNI 生成，
  /// 拿不到 native 就只能承认拿不到，别拿 AppKey 字符串冒充（本轮已实测冒充无效）。
  static String rtcCommand(int epochSeconds) => '*APP#rtc#$epochSeconds#';
  static const String osTypeCommand = '*APP#ostype#0#';

  /// 鉴权帧：`*APP#sdkkey#` + 16 字节 + `#`（整帧 29 字节）。
  ///
  /// 出处不是猜的，是 `NvEasyBle-v1.1.3.aar` 里 `NvEasyBleBluetooth.b(byte[])`
  /// 的字节码：`ByteBuffer.allocate(29)` → put("*APP#sdkkey#") → put(那 16 字节)
  /// → put("#")，命令名 `sdkkey`、withResponse=true、超时 250ms。
  /// 姊妹方法 `a(byte[])` 是 `algkey`，开头硬校验 `arraylength != 16` 就抛
  /// `IllegalArgumentException("param is wrong!")` —— 所以**载荷必须是 16 字节**。
  ///
  /// 16 个 hex 字符解码只有 8 字节，凑不满；按 ASCII 原样传 16 个字符正好 29 字节，
  /// 因此 [newviewAppKeyToPayload] 默认按 ASCII 取那 16 个字符。两条都留着，
  /// 真机用哪条由探测台说话，不由注释说话。
  static List<int> sdkKeyFrame(List<int> keyBytes) =>
      utf8.encode('*APP#sdkkey#') + keyBytes + utf8.encode('#');
  static List<int> algKeyFrame(List<int> keyBytes) =>
      utf8.encode('*APP#algkey#') + keyBytes + utf8.encode('#');

  /// 凭据 → 那 16 字节载荷的两种候选取法
  static List<int> keyAsAscii(String key) => utf8.encode(key);
  static List<int>? keyAsHexBytes(String key) {
    if (key.length.isOdd) return null;
    final out = <int>[];
    for (var i = 0; i < key.length; i += 2) {
      final b = int.tryParse(key.substring(i, i + 2), radix: 16);
      if (b == null) return null;
      out.add(b);
    }
    return out;
  }

  /// 探测期允许发的**查询类**命令（全部只读，不改设备状态）
  /// 只读查询帧。前 6 条是最早按厂商 SDK 编码面发的那批；
  /// 后面 9 条是 2026-10-23 从 v1.2.0 `classes.jar` 反汇编里补的：
  /// 判据是「常量后面直接 `String.getBytes()` 就送出去」——**没有参数**，
  /// 也就没有「写错一个字段把机器设坏」的空间；同一套判据拿来标定已知项
  /// （`battery`/`version`/`mem`/`incharge`/`recmark` 都落在无参数一侧，
  /// `record`/`listreq`/`opusfile`/`wifi`/`micgain`/`offtime` 都落在带参数一侧）。
  ///
  /// ⚠️ 「无参数」只证明**不能带参数**，不等于「无副作用」——
  /// 所以这 9 条里刻意排除了 `active`（看名字可能是「激活」而不是「查激活状态」）、
  /// `call`（可能触发通话录音）、`algkey`（算法密钥本体）、
  /// 以及 `format`/`default`/`devunpair` 这三条同样是「一帧直发」但**改机器状态**的危险帧。
  /// `authsn` 当时也在排除之列，2026-10-23 21:47 真机答了 6 段之后移进这份只读清单：
  /// 厂商自己每次连接都调 `queryAuthSN`，它读序列号、不写机器，
  /// 风险只在「回包落日志」，由 [sensitiveFieldIndexes] 与 SDK 侧「不出 Diagnostic」兜住。
  /// 这批的上发经过使用者点头（2026-10-23），仅限只读取证。
  static const List<String> readOnlyCommands = [
    'version',
    'battery',
    'mem',
    'getlist',
    'listreq',
    'switch',
    'cblename',
    'cbtname',
    'cofftime',
    'cmicgain',
    'edr',
    'epblestat',
    'netinfo',
    'netstate',
    // 这三条也是**无参数直发**那一类（矩阵 13.1：反汇编里常量后面直接 getBytes()）。
    // `authsn` 对应厂商 `queryAuthSN`（读鉴权序列号）、`call` 对应 `queryCall`、
    // `serquery` 是查询式；上一轮 20:35 没带上它们，是因为当时还判不出读写。
    // 仍然排除：`active`（看名字可能是「激活设备」）、`algkey`（算法密钥本体）、
    // 以及 `format`/`default`/`devunpair` 这三条同样无参数但**改机器状态**的危险帧。
    'authsn',
    'call',
    'serquery',
    // `rtc` 实测会把这条会话打死（矩阵第 7 节），所以永远排最后——它一上，后面拿不到回包。
    'rtc',
  ];

  /// 绝不允许出现的命令。厂商 AAR 字符串常量里有这 45 条，其中这些是
  /// 「写一次可能不可恢复」的出厂信息写入或鉴权材料下发；探测台任何一档都不发，
  /// 也不给 UI 留入口。
  ///
  /// **唯一例外是 `sdkkey`**：它不是工厂写入，是厂商每次连接都要发的鉴权帧
  /// （见 [NewviewRaw.sdkKeyFrame] 的字节码出处），只有当手机上那份计划文件里
  /// 显式给了 `appkey=` 才会发。`algkey` 没这个例外——它是算法密钥本体，
  /// demo 源码里从不写它。
  static const List<String> forbiddenCommands = [
    'format',
    'devpair',
    'devunpair',
    'bound',
    'unbound',
    'blename',
    'btname',
    // cblename / cbtname / cofftime 三条 2026-10-23 移到只读清单：
    // 字节码证明它们是「无参数直发」的查询式（对应的写式是不带 c 前缀的
    // blename/btname/offtime，那三条仍在上面的禁发名单里）。
    // authsn 同批移出：厂商自己就在连接流程里调 `queryAuthSN`，它是**读**序列号，
    // 不写机器、不下发密钥，21:47 真机也答了 6 段。风险只在回包落日志，
    // 而那由 sensitiveFieldIndexes/maskedFields 兜住（Kotlin/Swift 侧更彻底：
    // 连 Diagnostic 都不发，只进 authSn 快照）。
    'algkey',
    'default',
    'active',
    'ota',
    'upgrade',
    'ostype',
    'offtime',
  ];

  /// 例外清单，写清楚免得下一个人当成越界
  static const List<String> authCommandsAllowedWithExplicitKey = ['sdkkey'];

  /// Kotlin 对每条回包的**段数假设**（`fields.size != N → throw invalidFrame`）。
  /// 真机段数与此不一致，就意味着上线后那台设备会在 `decode()` 里抛异常——
  /// 这就是探测台的主判据。
  static const Map<String, int> kotlinExpectedFieldCounts = {
    'version': 4, // 真机实测 `*DEV#version#1.5.1#0.3.0#` = 4 段，与 Kotlin 一致
    'battery': 5, // 真机实测 `*DEV#battery#0#0#30#` = 5 段（左/右/主三格）
    'wifi': 9,
    // 真机 2026-10-23 09:06 取到回包，形状是 9 段：
    // `*DEV#wifi#<开关回显 1>#<服务器 IP>#<端口>#<客户端 IP>#<客户端端口>#<SSID>#<密码>#`
    // 也就是 `*APP#wifi#1#` 的状态位也回了。上一版按 8 段（无回显）写，
    // 一旦真机连上就会整帧抛 invalidFrame，而且不抛也会把端口当 SSID。
    // 下面三位都是 2026-10-22 真机推过的原文，Kotlin 现在也按这个段数硬解：
    'incharge': 6, // `*DEV#incharge#0#0#0#30#`（0 未充电/1 充电中/2 充满）
    'mem': 4, // `*DEV#mem#0#0#`；同一场会话晚一点回过 `30492464#30523424`，语义未定
    'flist': 4, // `*DEV#flist#<正文总字节>#<页数>#` —— 只是表头，正文按 listreq 逐页取
    'switch': 3, // `*DEV#switch#0#`
    // 2026-10-23 20:35 第二台台架（PLQ110 / Android 16）验通的三条 c* 查询：
    'cblename': 4, // `*DEV#cblename#0#Lynse AI 0091#`
    'cbtname': 4, // `*DEV#cbtname#0#T2403#`
    'cofftime': 4, // `*DEV#cofftime#0#36000#`
    // 2026-10-23 21:47 同一台台架验通：`*DEV#authsn#<24 位鉴权序列号>#<连接 MAC>#<公网 MAC>#<机型串>#`。
    // 是 6 段而不是 c* 那三条的 4 段——所以它单列一段判据，Kotlin/Swift 也各有分支。
    // 第 3 段是鉴权材料，见 [sensitiveFieldIndexes]：这段只准出现在手机那份 .bin 里。
    'authsn': 6,
  };

  /// 每种回包里**不许进日志**的段位（下标按 [fields]：0 是 `*DEV`，1 是命令名）。
  ///
  /// 之所以在 [shapeVerdict] 里就地打码，而不是指望调用方记得套 [redact]：
  /// `redact` 认的是 `*DEV#authsn#…#` 这种带 `#` 的整帧，而这里拼出来的是 `a|b|c`，
  /// 分隔符一换它就漏——热点的 SSID/密码此前就是这么跟着判据进了探测台日志。
  static const Map<String, Set<int>> sensitiveFieldIndexes = {
    'authsn': {2}, // 鉴权序列号
    // 帧尾两段恒为 SSID、口令：9 段（真机现形）落在 7/8，旧的 8 段假设落在 6/7。
    // 所以这里三格一起盖——多盖的那一格是客户端端口，不是秘密，
    // 而且同一行日志里 `${parsed.clientIp}:${parsed.clientPort}` 本来就单独印着。
    'wifi': {6, 7, 8},
  };

  /// 按 [sensitiveFieldIndexes] 打码后的段列表，专供落日志的那句拼接用。
  static List<String> maskedFields(String kind, List<String> fields) {
    final sensitive = sensitiveFieldIndexes[kind];
    if (sensitive == null) return fields;
    return [
      for (var i = 0; i < fields.length; i++)
        sensitive.contains(i) ? '***(len=${fields[i].length})' : fields[i],
    ];
  }

  /// 一条回包相对 Kotlin 假设的判定
  static String shapeVerdict(String kind, List<String> fields) {
    final expected = kotlinExpectedFieldCounts[kind];
    // 三处出口都拼了段列表，所以在这里一次性换掉鉴权/热点凭据那几段：
    // 判据要的是「第几段是什么形状」，不是「那一段的值」。
    final shown = maskedFields(kind, fields).join('|');
    if (expected == null) {
      return '${fields.length}段($shown)';
    }
    if (fields.length == expected) {
      return 'PASS ${fields.length}段与 Kotlin 一致($shown)';
    }
    return 'MISMATCH 真机 ${fields.length}段 / Kotlin 按 ${expected}段硬解'
        '($shown) → decode() 会抛 invalidFrame';
  }

  // ------------------------------------------------------------------
  // 广播解析：逐行镜像 Kotlin parseAdvertisement
  // ------------------------------------------------------------------

  static NewviewAdFacts? parseAdvertisement(List<int> data) =>
      parseAdvertisementDetailed(data).facts;

  static ({NewviewAdFacts? facts, NewviewAdFailure? failure})
      parseAdvertisementDetailed(List<int> data) {
    // 锚点：先按厂商字面量 "NvEasy"，找不到再按尾部 "NV" 族标记倒推。
    // 真机证据（2026-10-22，Lynse AI 0091）：那张卡的 6 字节厂商码是 **"ilynse"**，
    // 但 mask=+7 / version=+11 / sku=+12 / "NV"=+14 的相对布局与厂商族完全一致，
    // 厂商 AAR v1.2.0 解析同一份广播也输出 idMark=ilynse、proto=24。
    // 只认字面量的旧写法在这张卡上直接解不出（探测台报的就是「广播按 SDK 规则解不出」）。
    final literal = indexOfBytes(data, 'NvEasy'.codeUnits);
    final marker = literal >= 0 ? literal : _signatureAnchor(data);
    if (marker == null) {
      return (facts: null, failure: NewviewAdFailure(reason: '无 NvEasy 标记（尾部 NV 锚点也未成立）', length: data.length, markerOffset: null, hex: hex(data.take(24).toList())));
    }
    if (data.length - marker < 12) {
      return (facts: null, failure: NewviewAdFailure(reason: '标记后不足 12B', length: data.length, markerOffset: marker, hex: hex(data.take(24).toList())));
    }
    final protocolVersion = data[marker + 11];
    var abilityMask = 0;
    for (var i = 0; i < 4; i++) {
      abilityMask = (abilityMask << 8) | data[marker + 7 + i];
    }
    if (protocolVersion >= 21) {
      if (data.length - marker < 16) {
        return (facts: null, failure: NewviewAdFailure(reason: 'ver≥21 但标记后不足 16B', length: data.length, markerOffset: marker, hex: hex(data.take(24).toList())));
      }
      final tag = String.fromCharCodes(data.sublist(marker + 14, marker + 16));
      if (tag != 'NV') {
        return (facts: null, failure: NewviewAdFailure(reason: 'ver≥21 但 marker+14..15 != "NV"(读到 $tag)', length: data.length, markerOffset: marker, hex: hex(data.take(24).toList())));
      }
    }
    // deviceCode 就是这 6 字节厂商码本身。旧写法取广播头 3 字节并要求可打印 ASCII，
    // 真机头 3 字节是 `32 e5 3c`（'2' + MAC 前两字节），必然解不出。
    final deviceCode = String.fromCharCodes(data.sublist(marker, marker + 6));
    if (deviceCode.codeUnits.any((c) => c < 32 || c > 126)) {
      return (facts: null, failure: NewviewAdFailure(reason: '厂商码 6B 非可打印 ASCII($deviceCode)', length: data.length, markerOffset: marker, hex: hex(data.take(24).toList())));
    }
    final sku = protocolVersion >= 21 && data.length - marker >= 14
        ? String.fromCharCodes(data.sublist(marker + 12, marker + 14))
        : null;
    return (
      facts: NewviewAdFacts(
        deviceCode: deviceCode,
        protocolVersion: protocolVersion,
        abilityMask: abilityMask,
        sku: sku,
        markerOffset: marker,
      ),
      failure: null,
    );
  }

  /// 以尾部 `NV` 族标记倒推 6 字节厂商码的起点；三个约束都来自厂商族自身的形状，
  /// 不是为某一张卡特判（与 Kotlin `anchor()` 同一套）。
  static int? _signatureAnchor(List<int> data) {
    for (var start = data.length - 16; start >= 0; start--) {
      final tag = String.fromCharCodes(data.sublist(start + 14, start + 16));
      if (tag != 'NV') continue;
      final version = data[start + 11];
      if (version < 16 || version > 31) continue;
      if (data.sublist(start, start + 6).any((c) => c < 32 || c > 126)) continue;
      return start;
    }
    return null;
  }

  static int indexOfBytes(List<int> haystack, List<int> needle) {
    if (needle.isEmpty || haystack.length < needle.length) return -1;
    for (var start = 0; start <= haystack.length - needle.length; start++) {
      var hit = true;
      for (var i = 0; i < needle.length; i++) {
        if (haystack[start + i] != needle[i]) {
          hit = false;
          break;
        }
      }
      if (hit) return start;
    }
    return -1;
  }

  /// 实时推流头：Kotlin `beginAudioFrame` 取**前 4 个** `#`，
  /// 用第 2~3 个之间的十进制当总字节、第 3~4 个之间当单帧字节。
  /// 真机头不是这个形状时必须能立刻看出来，所以单独判一份。
  static ({int total, int frame, int headerBytes, String reason}) parseStreamHeader(
      List<int> data) {
    final separators = <int>[];
    for (var i = 0; i < data.length && separators.length < 4; i++) {
      if (data[i] == 0x23) separators.add(i);
    }
    if (separators.length != 4) {
      return (total: 0, frame: 0, headerBytes: 0, reason: '前缀后不足 4 个 #(读到 ${separators.length})');
    }
    final total = int.tryParse(
        utf8.decode(data.sublist(separators[1] + 1, separators[2]), allowMalformed: true));
    final frame = int.tryParse(
        utf8.decode(data.sublist(separators[2] + 1, separators[3]), allowMalformed: true));
    if (total == null || frame == null) {
      return (total: 0, frame: 0, headerBytes: separators[3] + 1, reason: 'total/frame 非十进制');
    }
    if (total <= 0 || frame <= 0 || total > 8 * 1024 * 1024) {
      return (total: total, frame: frame, headerBytes: separators[3] + 1, reason: '越界 total=$total frame=$frame');
    }
    return (
      total: total,
      frame: frame,
      headerBytes: separators[3] + 1,
      reason: 'PASS total=$total frame=$frame 头部分隔位=$separators',
    );
  }

  static String hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

  /// 鉴权材料不落日志：把 `*APP#sdkkey#…#` / `*DEV#appkey#…#` 这类帧的载荷段
  /// 换成 `***(len=N)`。只影响打印与报告文本；手机那份 `.bin` 里仍是原始字节
  /// （那台手机不进仓库，等价于 Xyrix 那边「真值只写进手机上的计划文件」的口径）。
  static String redact(String text) {
    var out = text;
    for (final kind in ['sdkkey', 'appkey', 'algkey', 'authsn']) {
      out = out.replaceAllMapped(
        RegExp(r'(\*(?:DEV|APP)#' + kind + r'#)([^#]*)'),
        (m) => '${m.group(1)}***(len=${m.group(2)?.length ?? 0})',
      );
    }
    // `*DEV#wifi#…` 不是单段载荷，SSID 与口令是第 8、9 段，上面那条一条都盖不住。
    return redactHotspotFrame(out);
  }

  /// 热点帧里凭据相对命令名的偏移。原文按 `#` 切时，9 段形状凭据在 7/8（命令名在 1，
  /// 即 +6/+7），旧的 8 段假设在 6/7（+5/+6），所以 +5/+6/+7 三格一起盖：
  /// 多出来的那格是客户端端口，不是秘密，同一行日志里本来就单独印着。
  static const List<int> _wifiCredentialOffsets = [5, 6, 7];

  /// 把 `*DEV#wifi#…#<SSID>#<口令>#` 的凭据两段换成 `***(len=N)`。
  ///
  /// 按段处理而不是按正则，是因为同一帧在日志里有两种形态（原文用 `#`、
  /// 段列表用 `|`），只认一种分隔符就会漏——`sensitiveFieldIndexes` 那条注释记的
  /// 正是这个坑。一行里出现多帧也逐帧盖。
  static String redactHotspotFrame(String text) {
    if (!text.contains('wifi')) return text;
    var out = text;
    for (final sep in ['#', '|']) {
      if (!out.contains(sep)) continue;
      final parts = out.split(sep);
      for (var at = 0; at < parts.length; at++) {
        if (parts[at] != 'wifi') continue;
        for (final offset in _wifiCredentialOffsets) {
          final i = at + offset;
          if (i < parts.length && parts[i].isNotEmpty && !parts[i].startsWith('***')) {
            parts[i] = '***(len=${parts[i].length})';
          }
        }
      }
      out = parts.join(sep);
    }
    return out;
  }

  static String printable(List<int> bytes) =>
      utf8.decode(bytes, allowMalformed: true).replaceAll('\n', r'\n');
}
