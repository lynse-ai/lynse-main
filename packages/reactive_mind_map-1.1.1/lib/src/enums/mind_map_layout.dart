/// 마인드맵 레이아웃 방향을 정의하는 열거형
enum MindMapLayout {
  /// 오른쪽으로만 확장 (기본값)
  right,

  /// 왼쪽으로만 확장
  left,

  /// 위쪽으로만 확장
  top,

  /// 아래쪽으로만 확장
  bottom,

  /// 모든 방향으로 확장 (원형)
  radial,

  /// 양쪽으로 확장 (좌우)
  horizontal,

  /// 양쪽으로 확장 (상하)
  vertical,
}
