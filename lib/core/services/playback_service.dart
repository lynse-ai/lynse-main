/// 播放服务：just_audio 封装，全局单份播放器状态。
///
/// 详情页/录音列表/助手卡片都订阅本服务；播放进度同时驱动转写
/// segment 高亮（由 UI 层用 positionMs 匹配段落的 begin/end）。
library;

import 'dart:async';

import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

class PlaybackService extends GetxController {
  PlaybackService._();

  static PlaybackService get instance => Get.find<PlaybackService>();

  static PlaybackService init() {
    if (Get.isRegistered<PlaybackService>()) return Get.find<PlaybackService>();
    final c = PlaybackService._();
    Get.put(c, permanent: true);
    return c;
  }

  late final AudioPlayer _player = AudioPlayer();

  /// 当前播放的本地文件路径（null = 未加载）
  final currentPath = Rxn<String>();

  /// 当前播放的展示标题
  final currentTitle = Rxn<String>();

  final isPlaying = false.obs;
  final isBuffering = false.obs;
  final positionMs = 0.obs;
  final durationMs = 0.obs;
  final rate = 1.0.obs;
  final lastError = Rxn<String>();

  static const _rateCycle = [1.0, 1.5, 2.0, 0.5];

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  /// 加载并播放（同一文件则视为继续/暂停切换）
  Future<void> play(String path, {String? title}) async {
    lastError.value = null;
    if (currentPath.value == path) {
      await toggle();
      return;
    }
    try {
      currentPath.value = path;
      currentTitle.value = title ?? path.split('/').last;
      await _player.setAudioSource(AudioSource.uri(Uri.file(path)));
      await _player.setSpeed(rate.value);
      await _player.play();
    } catch (e) {
      lastError.value = '无法播放该文件：$e';
      currentPath.value = null;
    }
  }

  Future<void> toggle() async {
    if (currentPath.value == null) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> seek(int ms) async {
    await _player.seek(Duration(milliseconds: ms));
  }

  /// 1.0 → 1.5 → 2.0 → 0.5 循环
  Future<void> cycleRate() async {
    final next = _rateCycle[(_rateCycle.indexOf(rate.value) + 1) % _rateCycle.length];
    rate.value = next;
    await _player.setSpeed(next);
  }

  Future<void> stop() async {
    await _player.stop();
    currentPath.value = null;
    currentTitle.value = null;
    positionMs.value = 0;
    durationMs.value = 0;
  }

  void _wire() {
    _posSub = _player.positionStream.listen((p) => positionMs.value = p.inMilliseconds);
    _durSub = _player.durationStream.listen((d) => durationMs.value = d?.inMilliseconds ?? 0);
    _stateSub = _player.playerStateStream.listen((s) {
      isPlaying.value = s.playing;
      isBuffering.value = s.processingState == ProcessingState.loading ||
          s.processingState == ProcessingState.buffering;
    });
  }

  /// 首次 init 后接线（构造后立刻调用）
  PlaybackService boot() {
    _wire();
    return this;
  }

  @override
  void onClose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.onClose();
  }
}
