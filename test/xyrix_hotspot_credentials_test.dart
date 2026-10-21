/// XyrixHotspotCredentials.parse 单元测试：
/// 0x21 热点凭证帧格式厂商未定死，解析器按宽松 ASCII 分词实现，
/// 真机联调确认格式后收严——这些用例锁定当前行为。
library;

import 'dart:convert';

import 'package:dting/core/hardware/xyrix/hotspot_connector.dart';
import 'package:dting/core/hardware/xyrix/xyrix_wifi_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('XyrixHotspotCredentials.parse', () {
    test('纯 SSID + 密码', () {
      final c =
          XyrixHotspotCredentials.parse(utf8.encode('XYRIX_260626 xy123456'));
      expect(c, isNotNull);
      expect(c!.ssid, 'XYRIX_260626');
      expect(c.password, 'xy123456');
      expect(c.ip, isNull);
      expect(c.port, isNull);
    });

    test('SSID + 密码 + IP + 端口', () {
      final c = XyrixHotspotCredentials.parse(
          utf8.encode('XYRIX_260626 xy123456 192.168.4.1 8080'));
      expect(c!.ssid, 'XYRIX_260626');
      expect(c.password, 'xy123456');
      expect(c.ip, '192.168.4.1');
      expect(c.port, 8080);
    });

    test('首尾非打印噪声字节 + 逗号分隔', () {
      // 适配器只传 frame.data（不含帧头）；真实数据可能带填充/回车噪声
      final bytes = [
        0x00, 0x0D, 0x0A,
        ...utf8.encode('XYRIX,pwd123,192.168.4.1,8080'),
        0x00,
      ];
      final c = XyrixHotspotCredentials.parse(bytes);
      expect(c!.ssid, 'XYRIX');
      expect(c.password, 'pwd123');
      expect(c.ip, '192.168.4.1');
      expect(c.port, 8080);
    });

    test('开放网络：只有 SSID + 端口，密码为空', () {
      final c = XyrixHotspotCredentials.parse(utf8.encode('XYRIX 8080'));
      expect(c!.ssid, 'XYRIX');
      expect(c.password, isEmpty);
      expect(c.port, 8080);
    });

    test('端口号 > 65535 视为密码', () {
      final c = XyrixHotspotCredentials.parse(utf8.encode('XYRIX 99999'));
      expect(c!.ssid, 'XYRIX');
      expect(c.password, '99999');
      expect(c.port, isNull);
    });

    test('纯数字 SSID 不会被误判为端口', () {
      final c = XyrixHotspotCredentials.parse(utf8.encode('12345678 pwd'));
      expect(c!.ssid, '12345678');
      expect(c.password, 'pwd');
    });

    test('空数据返回 null', () {
      expect(XyrixHotspotCredentials.parse(const []), isNull);
      expect(XyrixHotspotCredentials.parse([0x00, 0xFF]), isNull);
    });
  });

  group('normalizeSsid', () {
    // 真机踩过的坑：手机已经在卡的 AP 上，App 却判成没连上，
    // 因为 WifiInfo.getSsid() 带首尾双引号，比相等必然失败。
    test('剥掉 Android 返回的双引号包装', () {
      expect(normalizeSsid('"AP_0000000000000000"'), 'AP_0000000000000000');
      // 归一化之后才允许跟设备热点名比相等
      expect(normalizeSsid('"AP_0000000000000000"') == 'AP_0000000000000000',
          isTrue);
    });

    test('unknown ssid 归一为空串（不能当成「连上了某个网」）', () {
      expect(normalizeSsid('<unknown ssid>'), '');
      expect(normalizeSsid('"<unknown ssid>"'), '');
    });

    test('干净值与 null 原样通过', () {
      expect(normalizeSsid('sherrymm-5G'), 'sherrymm-5G');
      expect(normalizeSsid('  Xyrix  '), 'Xyrix');
      expect(normalizeSsid(null), '');
      expect(normalizeSsid('"'), '"'); // 单个引号不构成包装，别把内容吃掉
    });
  });

  group('parseApParams（带外热点参数）', () {
    test('按第一个冒号切分，口令里的冒号原样保留', () {
      final c = XyrixHotspotCredentials.parseApParams('AP_TEST:12:34:56');
      expect(c!.ssid, 'AP_TEST');
      expect(c.password, '12:34:56');
    });

    test('没有冒号 = 开放网络', () {
      final c = XyrixHotspotCredentials.parseApParams('AP_TEST');
      expect(c!.ssid, 'AP_TEST');
      expect(c.password, isEmpty);
    });

    test('空串/只有冒号 = 没配参数，返回 null 让调用方明确报错', () {
      expect(XyrixHotspotCredentials.parseApParams(''), isNull);
      expect(XyrixHotspotCredentials.parseApParams('   '), isNull);
      expect(XyrixHotspotCredentials.parseApParams(':pw-with-colon'), isNull);
    });
  });
}
