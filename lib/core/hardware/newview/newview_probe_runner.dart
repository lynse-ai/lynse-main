/// Newview 探测台自驱动入口。
///
/// 用法与 Xyrix 那套一致，为的是「出一版包，改一个文件就能换一组实验」：
/// 往 `/sdcard/Android/data/com.lynseai.dting/files/newview_probe.txt`
/// push 一行等级，重启 App 即自动扫描→连接→逐条取证，结论写
/// 同目录的 `newview_probe_report.txt`，原始通知字节写 `newview_raw_*.bin`。
///
/// 首行形如 `1` / `4` / `2 only` / `0`（关）；第二行是运行时参数：
/// `mac=AA:BB:CC:DD:EE:FF` `name=NV12` `all`（不过滤，列出所有候选）
/// `opusfile=1`（显式允许发下载格式选择）。
///
/// 它刻意**不走** `DeviceSessionController`：那条链会起厂商 AAR 的扫描器，
/// 两个 BLE 客户端抢同一张射频，测出来的东西就不可信了。
library;

import 'dart:async';
import 'dart:io';

import 'package:dting/config/config.dart';
import 'package:dting/core/hardware/newview/newview_probe.dart';
import 'package:dting/core/hardware/newview/newview_protocol.dart';
import 'package:dting/core/hardware/newview/newview_raw_client.dart';
import 'package:dting/utils/local_database.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class NewviewProbeRunner {
  static const String planFileName = 'newview_probe.txt';
  static const String reportFileName = 'newview_probe_report.txt';

  static bool _running = false;

  static Future<void> maybeStart() async {
    if (_running) return;
    final plan = await _resolvePlan();
    final level = plan.level;
    if (level == 0 && plan.only == 0) return;
    _running = true;
    final client = NewviewRawClient();
    IOSink? report;
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return;
      final reportFile = File('${dir.path}/$reportFileName');
      report = reportFile.openWrite(mode: FileMode.append);
      final sink = report;
      void log(String line) {
        debugPrint('[Newview][探测] $line');
        sink.writeln('${DateTime.now().toIso8601String()} $line');
      }

      log('===== 计划 level=$level only=${plan.only} '
          'mac=${plan.mac ?? "-"} name=${plan.nameContains ?? "-"} '
          'opusfile=${plan.opusfile} vendor=${plan.vendor} '
          '鉴权钥匙=${Config.newviewAppKey.isEmpty ? "未配（先验不握手那条路）" : "已配 len=${Config.newviewAppKey.length}"} =====');
      final candidates = await client.scan(
        timeout: const Duration(seconds: 15),
        newviewOnly: !plan.listAll,
      );
      log('扫描判据: 插件累积 ${client.rawScanCount} 条、本地判据筛掉 '
          '${client.unattributedCount} 台、候选 ${candidates.length} 台、'
          '插件报错 ${client.scanError ?? "无"}');
      log('候选 ${candidates.length} 台：'
          '${candidates.take(8).map((c) => "${c.name}|${c.remoteId}|rssi=${c.rssi}|广播解析=${c.facts != null}").join(" ; ")}');
      final target = _pick(candidates, plan);
      if (target == null) {
        log('没有匹配的 Newview 设备。'
            '${candidates.isEmpty ? "一个候选都没扫到——先确认机器已开机、没被别的手机连着、且不在配对模式" : "扫到 ${candidates.length} 台但按 mac/name/识别判据都没挑中"}');
        // 未命中时把每台候选的原始厂商数据打出来：parseAdvertisement 的偏移
        // 到底该定在哪，靠这份字节表重定，不靠猜
        for (final c in candidates.take(12)) {
          log('候选 ${c.name}|${c.remoteId}|rssi=${c.rssi} '
              '服务=${c.serviceUuids.join(",")} '
              '厂商数据=${c.manufacturerData.isEmpty ? "无" : NewviewRaw.hex(c.manufacturerData.take(32).toList())}');
        }
        return;
      }
      log('选中 ${target.remoteId} ${target.name} '
          '（广播按 SDK 规则${target.facts == null ? "解不出，需要重定偏移" : "解析成功"}）');
      await client.connect(target);
      log('已连接；GATT 表 ${client.gattSurvey()}');
      await NewviewProbe(
        client: client,
        candidate: target,
        log: log,
        allowOpusFormatSelect: plan.opusfile,
        vendorControl: plan.vendor,
      ).run(level, onlyLevel: plan.only);
    } catch (e, st) {
      debugPrint('[Newview][探测] 整体异常: $e\n$st');
      report?.writeln('整体异常 $e\n$st');
    } finally {
      await client.disconnect();
      try {
        await report?.flush();
        await report?.close();
      } catch (_) {}
      _running = false;
    }
  }

  static NewviewCandidate? _pick(List<NewviewCandidate> list, _Plan plan) {
    if (plan.mac != null) {
      for (final c in list) {
        if (c.remoteId.toUpperCase() == plan.mac!.toUpperCase()) return c;
      }
      return null;
    }
    if (plan.nameContains != null) {
      for (final c in list) {
        if (c.name.contains(plan.nameContains!)) return c;
      }
    }
    // 优先按广播就能按 SDK 规则解析出事实的那台——那才是「我们认识的 Newview」
    for (final c in list) {
      if (c.facts != null) return c;
    }
    for (final c in list) {
      if (c.serviceUuids.contains(NewviewRaw.primaryServiceUuid)) return c;
    }
    // 到这一步一条识别判据都没命中。宁可什么都不连，也不能退到「扫到的第一台」——
    // 那可能是邻居的手机、耳机或手表，而 L2 之后会往链路上写录音与文件命令。
    return null;
  }

  static Future<_Plan> _resolvePlan() async {
    var level = Config.newviewProbeLevel;
    var only = Config.newviewProbeOnly;
    String? mac;
    String? nameContains;
    var opusfile = false;
    var listAll = false;
    var vendor = false;
    if (!Platform.isAndroid) return _Plan(level, only, mac: mac, nameContains: nameContains, opusfile: opusfile, listAll: listAll, vendor: vendor);
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return _Plan(level, only, mac: mac, nameContains: nameContains, opusfile: opusfile, listAll: listAll, vendor: vendor);
      final file = File('${dir.path}/$planFileName');
      if (!await file.exists()) return _Plan(level, only, mac: mac, nameContains: nameContains, opusfile: opusfile, listAll: listAll, vendor: vendor);
      final lines = (await file.readAsString()).split('\n');
      if (lines.length > 1) {
        for (final opt in lines[1].trim().split(RegExp(r'\s+'))) {
          if (opt.startsWith('mac=')) {
            mac = opt.substring(4);
          } else if (opt.startsWith('name=')) {
            nameContains = opt.substring(5);
          } else if (opt.startsWith('appkey=')) {
            // 真值只留在手机内存与那份计划文件里；Config 供探测台取用
            Config.newviewAppKey = opt.substring(7);
            /**
             * 顺手补一处**联调用的落盘**：生产路径读的是 Hive 里的 `neview_appkey`
             * （`device_session_controller` 连接前回落取它），而 UI 那侧此前没有
             * 保存按钮、也没有回填，钥匙在手机上等于只活在计划文件里。
             * 这里在探测台启动时同步一次，省掉「每次重装都要手输一遍」。
             * 仍然是只写本机 Hive，不进仓库、不进日志。
             */
            try {
              LocalDataBase().basicBox?.put('neview_appkey', Config.newviewAppKey);
            } catch (_) {
              // Hive 还没初始化完（首屏更早），下一次启动再补
            }
          } else if (opt == 'vendor=1' || opt == 'vendor') {
            vendor = true;
          } else if (opt.startsWith('opusfile=')) {
            // 'opusfile=' 本身就 9 个字符，写 11 会让 `opusfile=1` 这种 10 字符
            // 的 token 直接 RangeError，整份计划都读不出来。
            opusfile = opt.substring(9) == '1';
          } else if (opt == 'all') {
            listAll = true;
          }
        }
      }
      final parts = lines.first.trim().split(RegExp(r'\s+'));
      final parsed = parts.isEmpty ? null : int.tryParse(parts.first);
      if (parsed == null) return _Plan(level, only, mac: mac, nameContains: nameContains, opusfile: opusfile, listAll: listAll, vendor: vendor);
      if (parsed == 0) return _Plan(0, 0, mac: mac, nameContains: nameContains, opusfile: opusfile, listAll: listAll, vendor: vendor);
      final isOnly = parts.length > 1 && parts[1] == 'only';
      return _Plan(parsed, isOnly ? parsed : 0, mac: mac,
          nameContains: nameContains, opusfile: opusfile, listAll: listAll,
          vendor: vendor);
    } catch (e) {
      debugPrint('[Newview][探测] 读计划失败: $e');
    }
    return _Plan(level, only, mac: mac, nameContains: nameContains, opusfile: opusfile, listAll: listAll, vendor: vendor);
  }
}

/// 探测计划。除 level/only 外全部走具名参数：
/// 上一版是 7 个位置参数，加一个 `vendor` 就得把 8 个调用点全数一遍，
/// 漏一个就是 kernel_snapshot 直接崩——具名参数让漏写变成默认值而不是编译错误。
class _Plan {
  final int level;
  final int only;
  final String? mac;
  final String? nameContains;
  final bool opusfile;
  final bool listAll;
  final bool vendor;
  const _Plan(
    this.level,
    this.only, {
    this.mac,
    this.nameContains,
    this.opusfile = false,
    this.listAll = false,
    this.vendor = false,
  });
}
