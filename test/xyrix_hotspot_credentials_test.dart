/// XyrixHotspotCredentials.parse 单元测试：
/// 0x21 热点凭证帧格式厂商未定死，解析器按宽松 ASCII 分词实现，
/// 真机联调确认格式后收严——这些用例锁定当前行为。
library;

import 'dart:convert';

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
}
