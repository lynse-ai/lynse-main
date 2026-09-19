/// 设备 tab：状态卡 / 录音控制卡 / 传输进度卡 / 文件列表卡 + 添加设备流程
/// （对照 lynse-desktop devices/devices-page.tsx 四卡结构）。
library;

import 'package:dting/controller/device_session_controller.dart';
import 'package:dting/hardware/hardware_kit.dart';
import 'package:dting/pages/lynse/lynse_widgets.dart';
import 'package:dting/styles/theme.dart';
import 'package:dting/utils/local_database.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LynseDevicesTab extends StatefulWidget {
  const LynseDevicesTab({super.key});

  @override
  State<LynseDevicesTab> createState() => _LynseDevicesTabState();
}

class _LynseDevicesTabState extends State<LynseDevicesTab> {
  @override
  Widget build(BuildContext context) {
    final c = DeviceSessionController.instance;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // ---- 1. 设备状态卡 ----
        Obx(() => _StatusCard(
              connected: c.connectedDevice.value,
              phase: c.connectionPhase.value,
              battery: c.battery.value,
              info: c.deviceInfo.value,
              onAddDevice: _showAddDeviceSheet,
              onRefresh: c.queryDeviceInfo,
            )),
        const SizedBox(height: 12),

        // ---- 2. 录音控制卡 ----
        Obx(() => _RecordControlCard(
              connected:
                  c.connectionPhase.value.isUsable &&
                      c.connectedDevice.value != null,
              recordState: c.recordState.value,
              scene: c.recordScene.value,
              onStart: (mode) => c.startRecording(mode),
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
        Obx(() {
          final f = c.firmwareEvent.value;
          if (f == null ||
              (f.state != FirmwareState.progress &&
                  f.state != FirmwareState.started)) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: LynseCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: '固件升级中'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: f.progressPercent / 100),
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
              onDownload: (f) => c.downloadDeviceFile(f),
            )),
      ],
    );
  }

  void _showAddDeviceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddDeviceSheet(),
    );
  }
}

// --------------------------------------------------------------------
// 1. 状态卡
// --------------------------------------------------------------------

class _StatusCard extends StatelessWidget {
  final DiscoveredDevice? connected;
  final ConnectionPhase phase;
  final BatteryStatus? battery;
  final DeviceHardwareInfo? info;
  final VoidCallback onAddDevice;
  final Future<void> Function() onRefresh;

  const _StatusCard({
    required this.connected,
    required this.phase,
    required this.battery,
    required this.info,
    required this.onAddDevice,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.lynse;
    final isConnected = connected != null && phase.isUsable;
    return LynseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isConnected ? Icons.headphones : Icons.bluetooth_disabled,
                size: 20,
                color: isConnected ? s.brand : s.mutedForeground,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  connected?.name ?? '未连接设备',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: s.foreground,
                  ),
                ),
              ),
              StatusPill(
                label: isConnected ? '已连接' : '未连接',
                color: isConnected ? LynseColors.success : s.mutedForeground,
              ),
              IconButton(
                icon: Icon(Icons.refresh, size: 20, color: s.mutedForeground),
                onPressed: isConnected ? () => onRefresh() : null,
              ),
            ],
          ),
          if (isConnected) ...[
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAddDevice,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加设备'),
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
  final IconData icon;
  final String label;
  final String value;

  const _Metric({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final s = context.lynse;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: s.mutedForeground),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: s.foreground,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: s.mutedForeground)),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------
// 2. 录音控制卡
// --------------------------------------------------------------------

class _RecordControlCard extends StatelessWidget {
  final bool connected;
  final RecordState recordState;
  final RecordScene scene;
  final ValueChanged<RecordScene> onStart;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;
  final Future<void> Function() onStop;

  const _RecordControlCard({
    required this.connected,
    required this.recordState,
    required this.scene,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.lynse;
    final recording = recordState == RecordState.recording;
    final paused = recordState == RecordState.paused;
    return LynseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: '录音控制',
            trailing: recording
                ? StatusPill(
                    label: paused ? '已暂停' : '录音中',
                    color: paused ? LynseColors.warning : LynseColors.danger)
                : null,
          ),
          const SizedBox(height: 12),
          if (!recording && !paused)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        connected ? () => onStart(RecordScene.meeting) : null,
                    child: const Text('开始会议录音'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: s.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: LynseRadius.button),
                      foregroundColor: s.foreground,
                    ),
                    onPressed:
                        connected ? () => onStart(RecordScene.call) : null,
                    child: const Text('开始通话录音'),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: s.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: LynseRadius.button),
                      foregroundColor: s.foreground,
                    ),
                    onPressed: paused ? () => onResume() : () => onPause(),
                    icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                    label: Text(paused ? '继续' : '暂停'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LynseColors.danger,
                    ),
                    onPressed: () => onStop(),
                    icon: const Icon(Icons.stop),
                    label: const Text('停止'),
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
  final TransferProgress progress;

  const _TransferCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final s = context.lynse;
    return LynseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SectionHeader(title: '文件传输'),
              const Spacer(),
              Text(
                progress.speedKbps > 0 ? '${progress.speedKbps} KB/s' : '',
                style: TextStyle(fontSize: 12, color: s.mutedForeground),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.fraction.clamp(0.0, 1.0),
              backgroundColor: s.muted,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '第 ${progress.currentFileIndex + 1} 个文件 · '
            '${progress.currentPacket}/${progress.totalPacket} 包',
            style: TextStyle(fontSize: 12, color: s.mutedForeground),
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
  final List<RecordingFile> files;
  final bool empty;
  final Future<void> Function() onRefresh;
  final ValueChanged<RecordingFile> onDownload;

  const _FileListCard({
    required this.files,
    required this.empty,
    required this.onRefresh,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.lynse;
    return LynseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: '设备录音文件',
            trailing: IconButton(
              icon: Icon(Icons.refresh, size: 18, color: s.mutedForeground),
              onPressed: empty ? null : () => onRefresh(),
            ),
          ),
          const SizedBox(height: 8),
          if (empty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: LynseEmpty(
                icon: Icons.bluetooth_disabled_outlined,
                title: '连接设备后查看设备内录音',
              ),
            )
          else if (files.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: LynseEmpty(
                icon: Icons.audio_file_outlined,
                title: '设备内暂无录音文件',
                subtitle: '下拉刷新或先录一段',
              ),
            )
          else
            ...files.map((f) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(Icons.audio_file_outlined,
                      size: 20, color: s.brand),
                  title: Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: s.foreground),
                  ),
                  subtitle: Text(
                    '${(f.sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB'
                    ' · ${f.scene == RecordScene.call ? '通话' : '会议'}',
                    style: TextStyle(fontSize: 11, color: s.mutedForeground),
                  ),
                  trailing: TextButton(
                    onPressed: () => onDownload(f),
                    child: const Text('下载'),
                  ),
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
    final s = context.lynse;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.62,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: '添加设备'),
              const SizedBox(height: 12),
              Row(
                children: [
                  _VendorChip(
                    label: 'Neview（录音背夹）',
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
                  decoration: const InputDecoration(
                    hintText: '请输入 16 位 AppKey（厂商码）',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _vendor == null ? null : _startScanAndConnect,
                  child: const Text('扫描并连接'),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Obx(() {
                  if (_c.scanning.value && _c.discoveredDevices.isEmpty) {
                    return const LynseEmpty(
                      icon: Icons.bluetooth_searching,
                      title: '正在扫描设备…',
                    );
                  }
                  if (_c.discoveredDevices.isEmpty) {
                    return const LynseEmpty(
                      icon: Icons.bluetooth_disabled_outlined,
                      title: '未发现设备',
                      subtitle: '请确认设备已开机并靠近手机',
                    );
                  }
                  return ListView.builder(
                    itemCount: _c.discoveredDevices.length,
                    itemBuilder: (_, i) {
                      final d = _c.discoveredDevices[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.bluetooth,
                            size: 20, color: s.brand),
                        title: Text(d.name,
                            style: TextStyle(
                                fontSize: 14, color: s.foreground)),
                        subtitle: Text(d.deviceId,
                            style: TextStyle(
                                fontSize: 11,
                                color: s.mutedForeground)),
                        trailing: const Icon(Icons.chevron_right, size: 18),
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
    final key = _vendor == HardwareVendor.neview
        ? _appKeyController.text.trim()
        : null;
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
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _VendorChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.lynse;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? s.brand.withValues(alpha: 0.12) : s.card,
            borderRadius: LynseRadius.button,
            border: Border.all(
              color: selected ? s.brand : s.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? s.brand : s.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
