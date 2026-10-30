/// 设备命令「单车道」。
///
/// 卡片上的文本协议是**一问一答**的：多条 `*DEV#` 会被合并进同一条 notify，
/// 后一条命令还会打断前一条的会话状态（`filecmd`/`opusfile` 尤其明显）。
/// 之前的实现只有「按命令名配对」和「活动类别互斥」，没有「上一条没回就不发下一条」，
/// 所以并发的调用会同时压在卡上——这条车道就是补这个。
///
/// 语义：
///  * **FIFO**：先到的先发，后来的排队等；
///  * 一条失败/超时**不会**卡死车道——`finally` 里一定放行下一条；
///  * **车道本身不设超时**：放行下一条的前提是「前一条真的结束了」。如果在这里
///    强行超时，设备可能还在处理上一条，下一条就压上去了，正是要避免的情形。
///    所以进车道的每个动作必须**自带超时**（适配器里的命令都已经有了）。
///  * **不许嵌套**：被包的动作里不能再 `run` 一次，否则自锁。现有调用都是扁平的；
///    加 `assert` 在 debug 下把嵌套当场喊出来。
library;

import 'dart:async';

class CommandLane {
  CommandLane({this.label = 'device'});

  /// 日志/诊断用（比如 'neview'）
  final String label;

  Future<void> _tail = Future<void>.value();
  int _waiting = 0;
  String? _inFlight;

  /// 用 Zone 标记「当前动作内部」，这样能区分「外面并发调用（正常排队）」
  /// 和「动作里又调了一次（嵌套，会自锁）」——只看字段是分不出来的。
  static final Object _insideAction = Object();

  /// 正在飞的那条命令名（没有就是 null）
  String? get inFlight => _inFlight;

  /// 还在排队、尚未发出的条数
  int get waiting => _waiting;

  bool get isBusy => _inFlight != null || _waiting > 0;

  /// 把 [action] 排进车道。返回的 future 在它自己跑完时完成。
  ///
  /// [command] 只用于诊断，不发出去。
  Future<T> run<T>(String command, Future<T> Function() action) {
    assert(
      Zone.current[_insideAction] != true,
      'CommandLane($label) 被嵌套调用：$command 正在 $_inFlight 的动作里又进车道——'
      '车道不重入，拆成两段先后 await。',
    );
    final previous = _tail;
    final released = Completer<void>();
    _tail = released.future;
    _waiting++;

    return () async {
      try {
        await previous;
      } finally {
        _waiting--;
      }
      _inFlight = command;
      try {
        return await runZoned(
          action,
          zoneValues: {_insideAction: true},
        );
      } finally {
        _inFlight = null;
        if (!released.isCompleted) released.complete();
      }
    }();
  }
}
