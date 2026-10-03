/// 通用轮询任务（PRD-02 F2-5 统一轮询状态机的心跳引擎）。
///
/// - 固定间隔探测 [probe]，返回 true 表示完成；抛异常计入连续失败，
///   连续失败达 [maxConsecutiveFailures] 次后退避到 [backoffInterval]。
/// - [pause]/[resume] 供 App 生命周期挂接（后台暂停、回前台恢复）。
/// - [dispose] 后不再触发任何回调，实例不可复用。
/// - 纯 Dart 逻辑（仅依赖 dart:async），可用 fakeAsync 单测。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

class PollingTask {
  PollingTask({
    required Future<bool> Function() probe,
    this.interval = const Duration(seconds: 5),
    this.backoffInterval = const Duration(seconds: 15),
    this.maxConsecutiveFailures = 3,
    this.onComplete,
    this.onError,
  }) : _probe = probe;

  final Future<bool> Function() _probe;
  final Duration interval;
  final Duration backoffInterval;
  final int maxConsecutiveFailures;
  final VoidCallback? onComplete;
  final void Function(Object error)? onError;

  Timer? _timer;
  bool _disposed = false;
  bool _stopped = false;
  bool _inFlight = false;
  int _consecutiveFailures = 0;

  bool get isDisposed => _disposed;
  bool get isRunning => !_disposed && !_stopped && _timer != null;

  /// 开始轮询；对已 dispose 的实例是空操作，对已停止的实例会重启。
  void start() {
    if (_disposed) return;
    if (_timer != null) return;
    _schedule(interval);
  }

  /// 暂停（App 退后台）；进行中的一次探测不受影响。
  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  /// 恢复（App 回前台）。
  void resume() => start();

  /// 停止并释放；之后不可再用。
  void dispose() {
    _disposed = true;
    _stopped = true;
    _timer?.cancel();
    _timer = null;
  }

  void _schedule(Duration delay) {
    if (_disposed || _stopped) return;
    _timer = Timer(delay, _tick);
  }

  Future<void> _tick() async {
    _timer = null;
    if (_disposed || _stopped) return;
    // 上一轮探测尚未返回时跳过本轮，避免请求堆积。
    if (_inFlight) {
      _schedule(interval);
      return;
    }
    _inFlight = true;
    try {
      final done = await _probe();
      _inFlight = false;
      if (_disposed || _stopped) return;
      if (done) {
        _consecutiveFailures = 0;
        _timer?.cancel();
        _timer = null;
        _stopped = true;
        onComplete?.call();
        return;
      }
      _consecutiveFailures = 0;
      _schedule(interval);
    } catch (e) {
      _inFlight = false;
      if (_disposed || _stopped) return;
      _consecutiveFailures++;
      onError?.call(e);
      _schedule(
        _consecutiveFailures >= maxConsecutiveFailures
            ? backoffInterval
            : interval,
      );
    }
  }
}
