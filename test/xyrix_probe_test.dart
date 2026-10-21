/// 2026-10-05 真机取证结果的回归属测试：
/// - 0x2E 存储响应字节布局（`[4B 总KB][4B 剩余KB]` 大端）
/// - 出现实时音频流之后，通知边界上的控制帧仍要能被解析
///   （此前路由器在见到 0x54 后永久放弃按帧解码，导致录音之后的查询「无响应」）
/// - 探测台的等级过滤（隔离实验的前提）
library;

import 'dart:typed_data';

import 'package:dting/config/config.dart';
import 'package:dting/core/hardware/models.dart';
import 'package:dting/core/hardware/xyrix/xyrix_commands.dart';
import 'package:dting/core/hardware/xyrix/xyrix_frame_codec.dart';
import 'package:dting/core/hardware/xyrix/xyrix_probe.dart';
import 'package:dting/core/hardware/xyrix/xyrix_stream_parsers.dart';
import 'package:flutter_test/flutter_test.dart';

/// 只记录不行动的真机替身
class _FakeHost implements XyrixProbeHost {
  final List<int> sent = [];
  final List<String> lines = [];
  List<XyrixFrame> respondWith = const [];

  @override
  Future<XyrixFrame?> exchange(int command, List<int> data,
      {int? expect, Duration timeout = const Duration(seconds: 3)}) async {
    sent.add(command);
    return respondWith.isEmpty ? null : respondWith.first;
  }

  @override
  Future<List<RecordingFile>> listFiles() async => const [
        RecordingFile(sn: 0, name: 'a.wav', sizeBytes: 10),
      ];

  @override
  Future<String> runBleDownload() async => 'fake 下载完成';

  @override
  Future<String> runWifiDownload() async => 'fake 快传完成';

  @override
  Future<String> runTextCommandProbe() async => 'fake 文本命令面探测完成';

  @override
  Future<String> runRecordLifecycle() async => 'fake 生命周期 推流+120 文件 3→4';

  @override
  Future<String> runGattSurvey() async => 'S=180A C=6e400002[N]';

  /// 热点加入的实测结论，测试里改它来模拟「连上了 / 没连上」
  String joinOutcome = '未连上（仍在 sh560F767C）';
  final List<String> joinAttempts = [];

  @override
  Future<String> joinHotspot(String ssid, String password, int seconds) async {
    joinAttempts.add(ssid);
    return joinOutcome;
  }

  @override
  Future<void> hold(int seconds, String why) async {}

  @override
  void log(String line) => lines.add(line);
}

void main() {
  group('parseStorage（0x2E 真机响应）', () {
    test('真机字节 [01 d1 d9 00][01 c3 2b 40] = 29.1GB/28.2GB（KB）', () {
      final r = XyrixFrameCodec.parseStorage(
          [0x01, 0xd1, 0xd9, 0x00, 0x01, 0xc3, 0x2b, 0x40]);
      expect(r, isNotNull);
      expect(r!.totalKb, 30529792); // 29.12 GB
      expect(r.freeKb, 29567808); // 28.20 GB → 占用 939 MB，与卡上 31 个 WAV 对得上
      expect(r.totalKb / 1024 / 1024, greaterThan(28)); // ≈29 GB
    });

    test('长度不足 8 字节不猜', () {
      expect(XyrixFrameCodec.parseStorage([0x01, 0x02]), isNull);
    });

    test('剩余大于总容量 = 字段顺序不对，判未知而不是给错数', () {
      expect(
          XyrixFrameCodec.parseStorage(
              [0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x09, 0x00]),
          isNull);
    });
  });

  group('音频流之后的控制帧仍可解析', () {
    // [2B 载荷长度][4B 序列号][载荷 N][2B CRC]，N=10 → 通知共 5+18=23B
    final audioPacket = Uint8List.fromList([
      0xff, 0x55, 0xaa, 0x00, 0x54, //
      0x00, 0x0a,
      0x00, 0x00, 0x00, 0x01,
      ...List<int>.filled(10, 0x11),
      0xaa, 0xbb,
    ]);

    test('收到过 0x54 之后，独占通知的 0x21 响应帧仍被解出', () {
      final frames = <XyrixFrame>[];
      final packets = <XyrixOpusPacket>[];
      final router = XyrixStreamRouter(
        onFrame: frames.add,
        onFileList: (_) {},
        onOpusPacket: packets.add,
      );

      router.feed(audioPacket);
      expect(packets, hasLength(1));
      expect(router.sawOpusTraffic, isTrue);

      // 真机实测格式：一条通知里两帧——状态字节 + 通用 ACK
      router.feed(Uint8List.fromList([
        0xff, 0x55, 0xaa, 0x01, XyrixCommands.openHotspotTcp, 0x01,
        0xff, 0x55, 0xaa, 0x00, XyrixCommands.commandAck,
      ]));

      expect(frames.map((f) => f.command),
          containsAll([XyrixCommands.openHotspotTcp, XyrixCommands.commandAck]));
      expect(frames.firstWhere((f) => f.command == XyrixCommands.openHotspotTcp)
          .data, [0x01]);
    });

    test('音频载荷里的假帧头不会被当成控制帧', () {
      final frames = <XyrixFrame>[];
      final router = XyrixStreamRouter(
        onFrame: frames.add,
        onFileList: (_) {},
        onOpusPacket: (_) {},
      );
      router.feed(Uint8List.fromList([0xff, 0x55, 0xaa, 0x00, 0x54]));
      router.feed(Uint8List.fromList(
          List<int>.filled(20, 0x77))); // 无边界帧头：纯载荷尾巴
      expect(frames, isEmpty);
    });
  });

  group('探测台等级隔离', () {
    test('onlyLevel 只跑该等级步骤', () async {
      final host = _FakeHost();
      await XyrixProbe(host, deviceName: 'Xyris').run(4, onlyLevel: 4);
      expect(host.sent, containsAll(<int>[
        XyrixCommands.openHotspot,
        XyrixCommands.openHotspotTcp,
        XyrixCommands.closeWifi,
      ]));
      expect(host.sent, isNot(contains(XyrixCommands.queryBattery)));
      expect(host.sent, isNot(contains(XyrixCommands.recordStart)));
    });

    test('level 3 会跑下载闭环', () async {
      final host = _FakeHost();
      final lines = await XyrixProbe(host).run(3);
      expect(lines.any((l) => l.contains('fake 下载完成')), isTrue);
    });

    test('无响应如实记为 NO_RESPONSE，不谎报成功', () async {
      final host = _FakeHost();
      final lines = await XyrixProbe(host).run(1, onlyLevel: 1);
      expect(lines.where((l) => l.contains('NO_RESPONSE')), isNotEmpty);
    });
  });

  group('热点凭证 hunt 的判据', () {
    // 本固件大量命令不回话却照样生效（录音系列实测全部无 ack），
    // 所以「无回执」不能当失败证据；唯一可信的是手机能不能连上那个 AP。
    test('设备零回执但手机连上了 → 判该编码命中', () async {
      final host = _FakeHost()..joinOutcome = '已连上 LYNSEXY';
      final verdict = await XyrixProbe(host).huntHotspotCredentials();
      expect(verdict, contains('命中'));
      expect(host.joinAttempts, isNotEmpty);
    });

    test('全都连不上 → 如实报失败，不拿回执当结论', () async {
      final host = _FakeHost();
      final verdict = await XyrixProbe(host).huntHotspotCredentials();
      expect(verdict, contains('都没'));
      expect(verdict, isNot(contains('命中')));
      // 每种编码两种发法（4×2）= 8 次
      expect(host.joinAttempts.length, 8);
      // ⛔ 0xF1「设置 WiFi SSID 和密码」属出厂信息写入，写错不可恢复（与 0xF4 写 SN
      // 同一类），2026-10-21 起从 hunt 里移除。这条断言是防止有人再把它加回来。
      expect(host.sent, isNot(contains(XyrixCommands.setWifiCredentials)));
    });

    test('配了带外 AP 参数就不再 hunt（不拿 4 分钟穷举去磨卡的热点名）', () async {
      final host = _FakeHost();
      Config.wifiApCredential = 'AP_TEST:12345678';
      addTearDown(() => Config.wifiApCredential = '');
      final lines = await XyrixProbe(host).run(4, onlyLevel: 4);
      expect(
        lines.firstWhere((l) => l.contains('hotspot凭证hunt')),
        contains('跳过'),
      );
      expect(host.joinAttempts, isEmpty);
    });
  });
}
