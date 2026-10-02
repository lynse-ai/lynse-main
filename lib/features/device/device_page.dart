/// 设备屏（Phase 4 正式版）：状态卡 / 录音控制卡 / 传输进度 / 文件列表
/// + 添加设备流程（厂商选择 → 扫描 → 连接）。
///
/// 全部订阅 DeviceSessionController，样式为新设计系统。
library;

import 'package:dting/core/hardware/hardware_kit.dart';
import 'package:dting/core/services/device_session_controller.dart';
import 'package:dting/ui/components.dart';
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
          return _TransferCard(progress: p);
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
        Obx(() => _FileListCard(
              files: c.deviceFiles,
              empty: !c.connectionPhase.value.isUsable,
              onRefresh: c.refreshFiles,
              onDownload: c.downloadDeviceFile,
            )),
      ],
    );
  }

  void _showAddDeviceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: LColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(LRadius.sheet)),
      ),
      builder: (_) => const _AddDeviceSheet(),
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
  const _TransferCard({required this.progress});

  final TransferProgress progress;

  @override
  Widget build(BuildContext context) {
    return LCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: LSectionHeading(label: '文件传输')),
              if (progress.speedKbps > 0)
                Text('${progress.speedKbps} KB/s', style: LType.small),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.fraction.clamp(0.0, 1.0),
              backgroundColor: LColors.line,
              color: LColors.blueDark,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '第 ${progress.currentFileIndex + 1} 个文件 · '
            '${progress.currentPacket}/${progress.totalPacket} 包',
            style: LType.small,
          ),
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
    required this.onRefresh,
    required this.onDownload,
  });

  final List<RecordingFile> files;
  final bool empty;
  final Future<void> Function() onRefresh;
  final ValueChanged<RecordingFile> onDownload;

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
            ...files.map((f) => LLinkRow(
                  icon: Icons.audio_file_outlined,
                  title: f.name,
                  subtitle:
                      '${(f.sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB'
                      ' · ${f.scene == RecordScene.call ? '通话' : '会议'}',
                  // 整行可点：直接触发音频外传快传（热点 + TCP）
                  onTap: () => onDownload(f),
                  trailing: LButton(label: '快传', small: true, onPressed: () => onDownload(f)),
                )),
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
                TextField(
                  controller: _appKeyController,
                  decoration: const InputDecoration(hintText: '请输入 16 位 AppKey（厂商码）'),
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
