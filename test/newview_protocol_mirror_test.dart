/// Newview 裸协议镜像的**跨语言对拍**测试。
///
/// 存在的理由：探测台在真机上验的是 Dart 镜像，而要上线的是
/// `lynse-hardware-sdk/first-device/newview/.../NewViewProtocolDefinition.kt`。
/// 两边必须吃同一组向量，否则「实测通过」验的不是那份代码。
///
/// 下面每条都标了出处：
/// - `[K]` = 逐条抄自 `certification/kotlin-tests/MultiVendorResolutionSmokeTest.kt`
///   （行号在注释里），那是 Kotlin 已经断言过的行为，Dart 侧必须一致；
/// - `[合成]` = Kotlin 那边**没有**这条断言，向量是按 `parseAdvertisement` 的
///   偏移反推出来的，只能证明两端读同一段字节会得到同一个结论。
///   真机数据到手后必须替换成真包，别把它当设备证据。
library;

import 'package:dting/core/hardware/newview/newview_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('编码与 Kotlin 一致', () {
    test('开/关热点两帧 [K:142,148]', () {
      expect(NewviewRaw.wifiCommand(true), '*APP#wifi#1#');
      expect(NewviewRaw.wifiCommand(false), '*APP#wifi#0#');
    });

    test('查询与控制帧就是裸 ASCII [K:560 command() 的写法]', () {
      expect(NewviewRaw.command('version'), '*APP#version#');
      expect(NewviewRaw.recordCommand(1, 0, 1), '*APP#record#1#0#1#');
      expect(NewviewRaw.recordCommand(0, 0, 1), '*APP#record#0#0#1#');
    });

    test('工厂与鉴权类命令在黑名单里，探测台一档都不发', () {
      for (final name in ['format', 'devpair', 'algkey', 'blename',
          'ota', 'upgrade', 'default', 'active']) {
        expect(NewviewRaw.forbiddenCommands, contains(name), reason: name);
        expect(NewviewRaw.readOnlyCommands, isNot(contains(name)));
      }
      // authsn 是**读**：厂商自己每次连接都调 queryAuthSN，它不写机器也不下发密钥，
      // 2026-10-23 21:47 真机答了 6 段。它的风险全在「回包别落日志」那侧，
      // 由上面那条打码用例钉住，所以不在禁发名单里。
      expect(NewviewRaw.forbiddenCommands, isNot(contains('authsn')));
      expect(NewviewRaw.readOnlyCommands, contains('authsn'));
      // sdkkey 是唯一例外：厂商每次连接都发它，属鉴权帧而不是工厂写入。
      // 它必须**不在**黑名单里、但也不在只读清单里——只有计划文件显式给
      // appkey= 才允许发，这个约束由探测台执行。
      expect(NewviewRaw.forbiddenCommands, isNot(contains('sdkkey')));
      expect(NewviewRaw.readOnlyCommands, isNot(contains('sdkkey')));
      expect(NewviewRaw.authCommandsAllowedWithExplicitKey, contains('sdkkey'));
    });

    test('连接后的明文初始化两帧 [AAR onNotifySuccess 字节码]', () {
      expect(NewviewRaw.rtcCommand(1761234567), '*APP#rtc#1761234567#');
      expect(NewviewRaw.osTypeCommand, '*APP#ostype#0#');
    });

    test('鉴权帧 29 字节：12 + 16 + 1（AAR 里 ByteBuffer.allocate(29)）', () {
      // 合成占位值：只验形状，不进仓库放真 key
      // （真值只写手机上那份 newview_probe.txt，见 runner 的 appkey= 约定）
      const key = '0123456789ABCDEF'; // 16 个 hex 字符
      final ascii = NewviewRaw.keyAsAscii(key);
      expect(ascii.length, 16, reason: '按 ASCII 原样传正好 16 字节');
      expect(NewviewRaw.sdkKeyFrame(ascii).length, 29);
      // hex 解码只有 8 字节，a(byte[]) 那种 arraylength==16 的校验根本过不去
      expect(NewviewRaw.keyAsHexBytes(key)!.length, 8);
      expect(
        NewviewRaw.sdkKeyFrame(ascii).sublist(0, 12),
        utf8Bytes('*APP#sdkkey#'),
      );
      expect(NewviewRaw.sdkKeyFrame(ascii).last, 0x23);
    });
  });

  group('回包形状判据（Kotlin 用 throw，判据必须等价）', () {
    test('真机 9 段 wifi = PASS，SSID/口令取的是设备实际回的那两列 [K:wifi]', () {
      // 2026-10-23 09:06 从 Lynse AI 0091 取到的形状（凭据打码，段数与列位保持真实）：
      // *DEV | wifi | 开关回显 | 服务器IP | 端口 | 客户端IP | 客户端端口 | SSID | 密码
      const reply =
          '*DEV#wifi#1#192.168.4.1#9527#192.168.4.2#8936#Lynse AI_MASKED#MASKEDSECRET000000#';
      final fields = reply.split('#').where((s) => s.isNotEmpty).toList();
      expect(fields.length, 9);
      expect(NewviewRaw.shapeVerdict('wifi', fields), startsWith('PASS'));
      // Kotlin: switchEcho=fields[2] host=fields[3] port=fields[4]
      //         clientIp=fields[5] clientPort=fields[6] ssid=fields[7] password=fields[8]
      expect(fields[2], '1');
      expect(fields[3], '192.168.4.1');
      expect(fields[4], '9527');
      expect(fields[7], 'Lynse AI_MASKED');
      expect(fields[8], 'MASKEDSECRET000000');
    });

    test('旧的 8 段假设现在必须判 MISMATCH——那正是真机会让 decode() 抛的形状', () {
      const legacy8 =
          '*DEV#wifi#192.168.4.1#9527#192.168.4.2#8936#Lynse AI_MASKED#MASKEDSECRET000000#';
      final fields = legacy8.split('#').where((s) => s.isNotEmpty).toList();
      expect(fields.length, 8);
      expect(NewviewRaw.shapeVerdict('wifi', fields), contains('MISMATCH'));
      expect(NewviewRaw.shapeVerdict('wifi', fields), contains('decode() 会抛'));
    });

    test('version/battery 的段数假设与 Kotlin 的硬编码一致 [K:394,448]', () {
      expect(NewviewRaw.kotlinExpectedFieldCounts['version'], 4);
      expect(NewviewRaw.kotlinExpectedFieldCounts['battery'], 5);
      expect(NewviewRaw.kotlinExpectedFieldCounts['wifi'], 9);
    });

    test('authsn 是 6 段，不是 c* 那三条的 4 段 [K:parseAuthSn]', () {
      // 2026-10-23 21:47 真机原文（第 2 段是鉴权序列号，等长合成串替位）：
      // *DEV#authsn#***(len=24)#E53CF5D3D190#6825DD87E4A9#LYNSENOTE0719091#
      final serial = 'S' * 24;
      final fields =
          '*DEV#authsn#$serial#E53CF5D3D190#6825DD87E4A9#LYNSENOTE0719091#'
              .split('#')
              .where((s) => s.isNotEmpty)
              .toList();
      expect(fields.length, 6);
      expect(NewviewRaw.kotlinExpectedFieldCounts['authsn'], 6);
      expect(NewviewRaw.shapeVerdict('authsn', fields), startsWith('PASS'));
      // 第 3 段就是广播 MAC 去掉分隔符，第 4 段尾号是热点 SSID 的后缀——咬合关系钉住
      expect(fields[3], 'E5:3C:F5:D3:D1:90'.replaceAll(':', ''));
      expect(NewviewRaw.shapeVerdict('authsn', ['*DEV', 'authsn', 'A', 'B']),
          contains('MISMATCH'));
    });

    test('判据文本不落凭据：序列号与 SSID/口令一律打码 [K:NewViewAuthSn 不出 Diagnostic]', () {
      final serial = 'S' * 24;
      final verdict = NewviewRaw.shapeVerdict(
        'authsn',
        '*DEV#authsn#$serial#E53CF5D3D190#6825DD87E4A9#LYNSENOTE0719091#'
            .split('#')
            .where((s) => s.isNotEmpty)
            .toList(),
      );
      expect(verdict, isNot(contains(serial)));
      expect(verdict, contains('***(len=24)'));
      // 热点：真机 9 段与旧的 8 段两种形状都要盖住尾两格（SSID/口令）
      const ssid = 'Lynse AI_LEAKCHECK';
      const pass = 'LEAKCHECKSECRET000000';
      for (final frame in [
        '*DEV#wifi#1#192.168.4.1#9527#192.168.4.2#8936#$ssid#$pass#',
        '*DEV#wifi#192.168.4.1#9527#192.168.4.2#8936#$ssid#$pass#',
      ]) {
        final fields =
            frame.split('#').where((s) => s.isNotEmpty).toList();
        final v = NewviewRaw.shapeVerdict('wifi', fields);
        expect(v, isNot(contains(ssid)), reason: 'SSID 跟着判据进了日志');
        expect(v, isNot(contains(pass)), reason: '口令跟着判据进了日志');
        expect(NewviewRaw.redact(frame), isNot(contains(ssid)));
        expect(NewviewRaw.redact(frame), isNot(contains(pass)));
      }
      // 非敏感帧不受影响：机型串照印
      expect(
        NewviewRaw.shapeVerdict('cbtname', ['*DEV', 'cbtname', '0', 'T2403']),
        contains('T2403'),
      );
    });
  });

  group('广播解析（镜像 Kotlin parseAdvertisement 的偏移）', () {
    // [合成] 按 marker+7..10 掩码、marker+11 版本、marker+12..13 SKU、
    // marker+14..15 必须为 "NV" 反推的 19 字节载荷
    List<int> ad({int version = 24, int mask = 0xF0000000, String tag = 'NV'}) {
      final out = <int>[0x4E, 0x56, 0x31]; // deviceCode "NV1"
      out.addAll('NvEasy'.codeUnits); // marker 落在偏移 3
      out.add(0x00); // marker+6
      out.addAll([(mask >> 24) & 0xff, (mask >> 16) & 0xff, (mask >> 8) & 0xff, mask & 0xff]);
      out.add(version); // marker+11
      out.addAll('AB'.codeUnits); // marker+12..13 = SKU
      out.addAll(tag.codeUnits); // marker+14..15
      return out;
    }

    test('解出协议版本、能力掩码与 SKU', () {
      final facts = NewviewRaw.parseAdvertisement(ad());
      expect(facts, isNotNull);
      expect(facts!.markerOffset, 3);
      expect(facts.protocolVersion, 24);
      expect(facts.abilityMask, 0xF0000000);
      // deviceCode = 那 6 字节厂商码本身（旧写法取头 3 字节，真机必然解不出）
      expect(facts.deviceCode, 'NvEasy');
      expect(facts.sku, 'AB');
      expect(facts.declaredAbilities,
          containsAll(['storage', 'wifi', 'meetingRecording', 'callRecording']));
    });

    // [真机] Lynse AI 0091 / E5:3C:F5:D3:D1:90，2026-10-22 广播原文 23B。
    // 厂商码是 "ilynse" 而不是 "NvEasy"，靠尾部 "NV" 族标记才锚得出来；
    // 掩码/版本/SKU 的相对偏移与厂商族一致，且与厂商 AAR v1.2.0
    // 自己 hasAbility() 的输出逐位相符（见 SDK docs/newview-interface-matrix.md 第 1 节）。
    test('真机广播：厂商码是 ilynse，靠 NV 锚点解出 proto24/L1/8 个能力位', () {
      final real = <int>[
        0x32, 0xe5, 0x3c, 0xf5, 0xd3, 0xd1, 0x90, // 头 + MAC(6B)
        0x69, 0x6c, 0x79, 0x6e, 0x73, 0x65, // "ilynse"
        0x40, // state
        0xf2, 0x46, 0x00, 0x00, // 能力掩码 BE
        0x18, // protocolVersion = 24
        0x4c, 0x31, // "L1" = SKU
        0x4e, 0x56, // "NV" = 族标记
      ];
      final r = NewviewRaw.parseAdvertisementDetailed(real);
      expect(r.failure, isNull, reason: r.failure?.reason ?? '');
      final facts = r.facts!;
      expect(facts.markerOffset, 7);
      expect(facts.deviceCode, 'ilynse');
      expect(facts.protocolVersion, 24);
      expect(facts.abilityMask, 0xF2460000);
      expect(facts.sku, 'L1');
      // 厂商 AAR 在同一张卡上 hasAbility() 实测返回这 8 项，一位不多一位不少
      expect(facts.declaredAbilities.toSet(), {
        'storage', 'wifi', 'meetingRecording', 'callRecording',
        'rtc', 'wifiV2', 'recordingMark', 'pauseResume',
      });
      // 表不全时 rtc(25) 会被静默丢掉，报出 7 项 —— 这条就是钉住那个 bug
      expect(facts.declaredAbilities.length, 8);
      // 缺席位对应的接口实测确实不通（flashNote 无回包），别把声明写上去
      expect(facts.declaredAbilities, isNot(contains('flashNote')));
      expect(facts.declaredAbilities, isNot(contains('meetingNoiseCancellation')));
      // 能力位全表 ≠ 我们声明的子集：差集检查靠这个差值才有效
      expect(NewviewRaw.abilityNames.length, 15);
      expect(
        NewviewRaw.knownCapabilityMask & ~facts.abilityMask,
        isNot(0),
        reason: 'SDK 声明了 mediaRecording(24)，本机没这位，必须被差集指出来',
      );
    });

    test('掩码差集能指出 SDK 写死的声明与本机不符', () {
      final facts = NewviewRaw.parseAdvertisement(ad(mask: 0x00400000))!;
      // 本机只有 wifiV2 一位；KNOWN_CAPABILITY_MASK 里的 storage/wifi/录音位都不该在
      expect(facts.hasAbility(NewviewRaw.abilityNames.keys.first), isFalse);
      final missing = NewviewRaw.knownCapabilityMask & ~facts.abilityMask;
      expect(missing, isNot(0));
    });

    // [真机] 四条设备实际推过的原文：段数判据必须报 PASS，
    // 因为 Kotlin 现在就是按这些段数硬解的（写反了 decode 就会抛 invalidFrame）。
    test('真机推过的四条回包形状都在判据表里，且都是 PASS', () {
      List<String> split(String text) =>
          text.split('#').where((s) => s.isNotEmpty).toList();
      expect(
        NewviewRaw.shapeVerdict('incharge', split('*DEV#incharge#0#0#0#30#')),
        startsWith('PASS'),
      );
      expect(
        NewviewRaw.shapeVerdict('mem', split('*DEV#mem#0#0#')),
        startsWith('PASS'),
      );
      expect(
        NewviewRaw.shapeVerdict('flist', split('*DEV#flist#985#3#')),
        startsWith('PASS'),
      );
      expect(
        NewviewRaw.shapeVerdict('switch', split('*DEV#switch#0#')),
        startsWith('PASS'),
      );
      // 段数变了必须报 MISMATCH（探测台就靠这一句判断「Kotlin 的硬编码过时了」）
      expect(
        NewviewRaw.shapeVerdict('incharge', split('*DEV#incharge#0#0#0#')),
        startsWith('MISMATCH'),
      );
    });

    test('ver>=21 却没有 NV 标记：明确失败原因，不返回半截事实', () {
      final r = NewviewRaw.parseAdvertisementDetailed(ad(tag: 'XX'));
      expect(r.facts, isNull);
      expect(r.failure!.reason, contains('NV'));
    });

    test('没有 NvEasy 标记时给出长度与 hex，供重定偏移', () {
      final r = NewviewRaw.parseAdvertisementDetailed([1, 2, 3, 4, 5]);
      expect(r.facts, isNull);
      expect(r.failure!.reason, contains('无 NvEasy 标记'));
      expect(r.failure!.hex, '01 02 03 04 05');
    });
  });

  group('实时推流头（Kotlin beginAudioFrame 取前 4 个 #）', () {
    test('total 与 frame 落在第 2/3 段之间', () {
      final head = utf8Bytes('*DEV#stream#1200#40#');
      final h = NewviewRaw.parseStreamHeader([...head, ...List.filled(1200, 0x00)]);
      expect(h.total, 1200);
      expect(h.frame, 40);
      expect(h.reason, startsWith('PASS'));
      expect(h.headerBytes, head.length);
      expect(h.total % h.frame, 0, reason: 'Kotlin finishAudioIfComplete 的整除判据');
    });

    test('不足 4 个分隔位要报出来，不能默默凑', () {
      final h = NewviewRaw.parseStreamHeader(utf8Bytes('*DEV#stream#1200#'));
      expect(h.reason, contains('不足 4 个'));
    });
  });
}

List<int> utf8Bytes(String s) => s.codeUnits;
