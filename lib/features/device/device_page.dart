/// 设备屏（Phase 4 正式版）：状态卡 / 录音控制卡 / 传输进度 / 文件列表
/// + 添加设备流程（厂商选择 → 扫描 → 连接）。
///
/// 全部订阅 DeviceSessionController，样式为新设计系统。
library;

import 'package:dting/core/hardware/hardware_kit.dart';
import 'package:dting/core/services/device_session_controller.dart';
import 'package:dting/ui/components.dart';
import 'package:dting/ui/glass.dart';
import 'package:dting/ui/tokens.dart';
import 'package:dting/utils/local_database.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DevicePage extends StatelessWidget {
  const DevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = DeviceSessionController.instance;
    return ListView(
      padding: const EdgeInsets.fromLTRB(LSpacing.xl, 4, LSpacing.xl, 24),
      children: [
        // ---- 1. 设备状态卡 ----
        Obx(() => _StatusCard(
              connected: c.connectedDevice.value,
              phase: c.connectionPhase.value,
              battery: c.battery.value,
              info: c.deviceInfo.value,
              onAddDevice: () => _showAddDeviceSheet(context),
              onRefresh: c.queryDeviceInfo,
            )),
        const SizedBox(height: 12),

        // ---- 2. 录音控制卡 ----
        Obx(() => _RecordControlCard(
              connected: c.connectionPhase.value.isUsable && c.connectedDevice.value != null,
              recordState: c.recordState.value,
              onStart: c.startRecording,
              onPause: c.pauseRecording,
              onResume: c.resumeRecording,
              onStop: c.stopRecording,
            )),
        const SizedBox(height: 12),

        // ---- 3. 传输进度卡 ----
        Obx(() {
          final p = c.transferProgress.value;
          if (p == null || p.state == TransferState.idle) {
            return const SizedBox.shrink();
          }
          return _TransferCard(progress: p, onCancel: c.cancelTransfer);
        }),
        // ---- 3b. 快传建链阶段提示（无字节进度时）----
        Obx(() {
          final st = c.wifiStatus.value;
          final building = st == WifiTransferStatus.opening ||
              st == WifiTransferStatus.opened ||
              st == WifiTransferStatus.connecting;
          if (!building && st != WifiTransferStatus.stopping) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: LCard(
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      switch (st) {
                        WifiTransferStatus.opening => '正在让设备开启 WiFi 热点…',
                        WifiTransferStatus.opened => '热点已开启，正在连接设备热点…',
                        WifiTransferStatus.connecting => '已连上热点，正在建立快传通道…',
                        _ => '正在关闭快传链路…',
                      },
                      style: LType.body,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        // ---- 3c. 固件升级进度 ----
        Obx(() {
          final f = c.firmwareEvent.value;
          if (f == null ||
              (f.state != FirmwareState.progress && f.state != FirmwareState.started)) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: const LCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LSectionHeading(label: '固件升级中'),
                  SizedBox(height: 8),
                  LinearProgressIndicator(),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),

        // ---- 4. 文件列表卡 ----
        // deviceFiles 必须在 Obx 闭包内读取（toList）：只传引用不会建立
        // 订阅，列表更新时卡片永远不刷新（联调实测的"列表解析了但 UI 空"）
        Obx(() {
          final files = c.deviceFiles.toList();
          return _FileListCard(
            files: files,
            empty: !c.connectionPhase.value.isUsable,
            isDownloaded: c.isDownloaded,
            onRefresh: c.refreshFiles,
            // 行点默认走蓝牙下载（实测稳定）；"快传"按钮走 WiFi 热点+TCP
            onDownload: (f) => c.downloadDeviceFile(f, useWifi: false),
            onQuickTransfer: (f) => c.downloadAllOverWifi(f),
            quickTransferEnabled: c.active?.capabilities
                    .supports(HardwareCapability.wifiTransfer) ??
                false,
          );
        }),
      ],
    );
  }

  void _showAddDeviceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // 透明交给 LGlass 做模糊面；showModalBottomSheet 自身没有 blur 开关，
      // 留实色底就会把身后的光斑挡掉，玻璃感全无
      backgroundColor: Colors.transparent,
      barrierColor: LColors.modalShade,
      builder: (_) => SafeArea(
        top: false,
        child: LGlass(
          strong: true,
          radius: 0,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(LRadius.sheet)),
          child: const _AddDeviceSheet(),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------
// 1. 状态卡
// --------------------------------------------------------------------

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.connected,
    required this.phase,
    required this.battery,
    required this.info,
    required this.onAddDevice,
    required this.onRefresh,
  });

  final DiscoveredDevice? connected;
  final ConnectionPhase phase;
  final BatteryStatus? battery;
  final DeviceHardwareInfo? info;
  final VoidCallback onAddDevice;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final isConnected = connected != null && phase.isUsable;
    return LCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LIconButton(
                icon: isConnected ? Icons.headphones : Icons.bluetooth_disabled,
                tint: isConnected ? LColors.blue : LColors.secondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  connected?.name ?? '未连接设备',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LType.heading,
                ),
              ),
              LChip(
                label: isConnected ? '已连接' : '未连接',
                tint: isConnected ? LColors.green : LColors.canvas,
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20, color: LColors.muted),
                onPressed: isConnected ? () => onRefresh() : null,
              ),
            ],
          ),
          if (isConnected) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                _Metric(
                  icon: Icons.battery_charging_full_outlined,
                  label: '电量',
                  value: battery == null ? '--' : '${battery!.levelPercent}%',
                ),
                _Metric(
                  icon: Icons.storage_outlined,
                  label: '固件',
                  value: info?.firmwareVersion ?? '--',
                ),
                _Metric(
                  icon: Icons.tag_outlined,
                  label: 'SN',
                  value: _shortSn(info?.serialNumber),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: LButton(
                label: '添加设备',
                icon: Icons.add,
                primary: true,
                onPressed: onAddDevice,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _shortSn(String? sn) {
    if (sn == null || sn.isEmpty) return '--';
    return sn.length <= 10 ? sn : '${sn.substring(0, 10)}…';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: LColors.muted),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LType.muted.copyWith(fontWeight: FontWeight.w600, color: LColors.text),
          ),
          Text(label, style: LType.small),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------
// 2. 录音控制卡
// --------------------------------------------------------------------

class _RecordControlCard extends StatelessWidget {
  const _RecordControlCard({
    required this.connected,
    required this.recordState,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final bool connected;
  final RecordState recordState;
  final ValueChanged<RecordScene> onStart;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    final recording = recordState == RecordState.recording;
    final paused = recordState == RecordState.paused;
    return LCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LSectionHeading(
            label: '录音控制',
            trailing: recording
                ? LChip(
                    label: paused ? '已暂停' : '录音中',
                    tint: paused ? LColors.orange : LColors.dangerBg,
                  )
                : null,
          ),
          const SizedBox(height: 12),
          if (!recording && !paused)
            Row(
              children: [
                Expanded(
                  child: LButton(
                    label: '会议录音',
                    icon: Icons.groups,
                    primary: true,
                    onPressed: connected ? () => onStart(RecordScene.meeting) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LButton(
                    label: '通话录音',
                    icon: Icons.call,
                    onPressed: connected ? () => onStart(RecordScene.call) : null,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: LButton(
                    label: paused ? '继续' : '暂停',
                    icon: paused ? Icons.play_arrow : Icons.pause,
                    onPressed: paused ? () => onResume() : () => onPause(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LButton(
                    label: '停止',
                    icon: Icons.stop,
                    onPressed: () => onStop(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------
// 3. 传输进度卡
// --------------------------------------------------------------------

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.progress, required this.onCancel});

  final TransferProgress progress;
  final VoidCallback onCancel;

  static String _fmtSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  /// 传输条那一行的文案。**只有厂商真报了字节数才配说 KB**：
  /// Neview 的 `didUpdateDownloadFileProgress` 只给包号（`receivedBytes`/`totalBytes`
  /// 恒为 null），之前一律按 0 渲染就显示成「0 KB / 0 KB · 37%」——百分比是对的，
  /// 字节却是编出来的，看着像传输根本没动。没数就照实说包数，不猜每包多大
  /// （每包尺寸要等 `opusfile` 首包才知道，且按固件不同会变）。
  /// 百分比两种情况下都留着：它来自包号，本来就可信。
  String _progressLabel() {
    final total = progress.totalBytes;
    final amount = total != null && total > 0
        ? '${_fmtSize(progress.receivedBytes ?? 0)} / ${_fmtSize(total)}'
        : progress.totalPacket > 1 || progress.currentPacket > 0
            ? '第 ${progress.currentPacket}/${progress.totalPacket} 包'
            : null;
    final percent = '${(progress.fraction * 100).toStringAsFixed(0)}%';
    return amount == null ? percent : '$amount · $percent';
  }

  /// 终止态文案：把「链路结束」和「内容完好」区分开说。
  /// 校验不通过的字节不会成为一条录音，用户必须知道它被丢弃了。
  ({String text, Color color, double fill}) _statusOf(TransferProgress p) {
    final integrity = p.integrity;
    return switch (p.state) {
      TransferState.completed => (
          text: switch (integrity) {
            TransferIntegrity.verified => '传输完成，字节校验通过',
            TransferIntegrity.sizeMismatch => '校验未通过，本次内容已丢弃',
            _ => '传输完成（设备未确认大小，未校验）',
          },
          color: integrity == TransferIntegrity.sizeMismatch
              ? LColors.danger
              : LColors.blueDark,
          fill: 1.0,
        ),
      TransferState.failed =>
        (text: '传输中断，可重新下载', color: LColors.danger, fill: p.fraction),
      TransferState.cancelled => (
          text: '已取消，断点已清除',
          color: LColors.muted,
          fill: p.fraction
        ),
      _ => (
          text: '',
          color: LColors.blueDark,
          fill: p.fraction
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusOf(progress);
    final transferring = progress.state == TransferState.transferring;
    return LCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: LSectionHeading(label: '文件传输')),
              if (progress.speedKbps > 0)
                Text('${progress.speedKbps} KB/s', style: LType.small),
              if (transferring) ...[
                const SizedBox(width: 8),
                LButton(label: '取消', small: true, onPressed: onCancel),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: status.fill.clamp(0.0, 1.0),
              backgroundColor: LColors.line,
              color: status.color,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            progress.state == TransferState.failed
                ? '传输失败，请重试'
                : progress.state == TransferState.cancelled
                    ? '传输已取消'
                    : _progressLabel(),
            style: progress.state == TransferState.failed
                ? LType.small.copyWith(color: LColors.danger)
                : LType.small,
          ),
          if (status.text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(status.text,
                style: LType.small.copyWith(color: status.color)),
          ],
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------
// 4. 文件列表卡
// --------------------------------------------------------------------

class _FileListCard extends StatelessWidget {
  const _FileListCard({
    required this.files,
    required this.empty,
    required this.isDownloaded,
    required this.onRefresh,
    required this.onDownload,
    required this.onQuickTransfer,
    required this.quickTransferEnabled,
  });

  final List<RecordingFile> files;
  final bool empty;
  final bool Function(String name) isDownloaded;
  final Future<void> Function() onRefresh;
  final ValueChanged<RecordingFile> onDownload;

  /// WiFi 热点+TCP 快传（整行点击之外的显式按钮）
  final ValueChanged<RecordingFile> onQuickTransfer;

  /// 厂商是否真的支持 WiFi 快传（能力清单说了算）。不支持就不摆按钮——
  /// 摆一个必然失败的「快传」比没有这个入口更糟。
  final bool quickTransferEnabled;

  @override
  Widget build(BuildContext context) {
    return LCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LSectionHeading(
            label: '设备录音文件',
            trailing: IconButton(
              icon: const Icon(Icons.refresh, size: 18, color: LColors.muted),
              onPressed: empty ? null : () => onRefresh(),
            ),
          ),
          const SizedBox(height: 8),
          if (empty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: LEmpty(
                icon: Icons.bluetooth_disabled_outlined,
                title: '连接设备后查看设备内录音',
              ),
            )
          else if (files.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: LEmpty(
                icon: Icons.audio_file_outlined,
                title: '设备内暂无录音文件',
                message: '下拉刷新或先录一段',
              ),
            )
          else
            ...files.map((f) {
              final downloaded = isDownloaded(f.name);
              return LLinkRow(
                icon: downloaded ? Icons.download_done : Icons.audio_file_outlined,
                title: f.name,
                subtitle:
                    '${(f.sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB'
                    '${downloaded ? " · 已下载" : ""}'
                    ' · ${f.scene == RecordScene.call ? '通话' : '会议'}',
                // 整行可点：蓝牙下载（实测稳定路径）；已下载则禁用
                onTap: downloaded ? null : () => onDownload(f),
                trailing: downloaded
                    ? const LChip(label: '已下载', tint: LColors.green)
                    : quickTransferEnabled
                        ? LButton(
                            label: '快传',
                            small: true,
                            onPressed: () => onQuickTransfer(f),
                          )
                        : const SizedBox.shrink(),
              );
            }),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------
// 添加设备流程（厂商选择 → 扫描 → 连接）
// --------------------------------------------------------------------

class _AddDeviceSheet extends StatefulWidget {
  const _AddDeviceSheet();

  @override
  State<_AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends State<_AddDeviceSheet> {
  String? _vendor;
  final _appKeyController = TextEditingController();
  late final DeviceSessionController _c;

  @override
  void initState() {
    super.initState();
    _c = DeviceSessionController.instance;
    /**
     * 回填已保存的 AppKey。之前这里不回填，框里永远是空的：
     * 值其实**已经**存进 Hive（只有「扫描并连接」会顺手 put 一次），
     * 但使用者看不到，也就以为「没有保存按钮 = 没保存成功」——2026-10-23 就是这里卡的。
     */
    final saved = LocalDataBase().basicBox?.get('neview_appkey')?.toString() ?? '';
    if (saved.isNotEmpty) _appKeyController.text = saved;
  }

  /// 显式保存：不靠「扫描并连接」的副作用，也别在这里碰设备。
  Future<void> _saveAppKey() async {
    final key = _appKeyController.text.trim();
    if (key.isEmpty) {
      Get.snackbar('未保存', 'AppKey 是空的');
      return;
    }
    await LocalDataBase().basicBox!.put('neview_appkey', key);
    if (mounted) Get.snackbar('已保存', 'AppKey 已存进本机（下次连接自动带上）');
  }

  @override
  void dispose() {
    _appKeyController.dispose();
    _c.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: LSpacing.xl,
          right: LSpacing.xl,
          top: LSpacing.xl,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.62,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LSectionHeading(label: '添加设备'),
              const SizedBox(height: 12),
              Row(
                children: [
                  _VendorChip(
                    label: 'Neview 录音背夹',
                    selected: _vendor == HardwareVendor.neview,
                    onTap: () => setState(() => _vendor = HardwareVendor.neview),
                  ),
                  const SizedBox(width: 10),
                  _VendorChip(
                    label: 'Xyrix',
                    selected: _vendor == HardwareVendor.xyrix,
                    onTap: () => setState(() => _vendor = HardwareVendor.xyrix),
                  ),
                ],
              ),
              if (_vendor == HardwareVendor.neview) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _appKeyController,
                        obscureText: true,
                        decoration: const InputDecoration(hintText: '请输入 16 位 AppKey（厂商码）'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    LButton(
                      label: '保存',
                      icon: Icons.lock_outline,
                      // 不是 primary：主按钮仍然是下面那条「扫描并连接」
                      primary: false,
                      onPressed: _saveAppKey,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: LButton(
                  label: '扫描并连接',
                  icon: Icons.bluetooth_searching,
                  primary: true,
                  onPressed: _vendor == null ? null : _startScanAndConnect,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Obx(() {
                  if (_c.scanning.value && _c.discoveredDevices.isEmpty) {
                    return const LEmpty(icon: Icons.bluetooth_searching, title: '正在扫描设备…');
                  }
                  if (_c.discoveredDevices.isEmpty) {
                    return const LEmpty(
                      icon: Icons.bluetooth_disabled_outlined,
                      title: '未发现设备',
                      message: '请确认设备已开机并靠近手机',
                    );
                  }
                  return ListView.builder(
                    itemCount: _c.discoveredDevices.length,
                    itemBuilder: (_, i) {
                      final d = _c.discoveredDevices[i];
                      return LLinkRow(
                        icon: Icons.bluetooth,
                        title: d.name,
                        subtitle: d.deviceId,
                        onTap: () => _connect(d),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startScanAndConnect() async {
    if (_vendor == HardwareVendor.neview && _appKeyController.text.isNotEmpty) {
      LocalDataBase().basicBox!.put('neview_appkey', _appKeyController.text);
    }
    _c.activeVendor.value = _vendor;
    await _c.startScan();
  }

  Future<void> _connect(DiscoveredDevice device) async {
    await _c.stopScan();
    final key = _vendor == HardwareVendor.neview ? _appKeyController.text.trim() : null;
    try {
      await _c.connect(device, authKey: (key == null || key.isEmpty) ? null : key);
      if (mounted) {
        Get.back();
        Get.snackbar('已连接', device.name);
      }
    } catch (e) {
      Get.snackbar('连接失败', '$e');
    }
  }
}

class _VendorChip extends StatelessWidget {
  const _VendorChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? LColors.blue : LColors.card,
            borderRadius: BorderRadius.circular(LRadius.button),
            border: Border.all(
              color: selected ? LColors.blueDark : LColors.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? LColors.blueDark : LColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
