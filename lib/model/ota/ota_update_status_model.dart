import 'package:json_annotation/json_annotation.dart';

part 'ota_update_status_model.g.dart';

//   STARTED(0),
//   PROGRESS(1),
//   SUCCESS(2),
//   FAILED(3)
enum OtaUpdateStatus {
  init(0),
  progress(1),
  success(2),
  failed(3);

  final int value;
  const OtaUpdateStatus(this.value);

  static OtaUpdateStatus fromValue(int value) {
    return values.firstWhere(
      (e) => e.value == value,
      orElse:
          () =>
              throw ArgumentError(
                '======Invalid OtaUpdateStatus value: $value',
              ),
    );
  }
}

@JsonSerializable()
class OtaUpdateStatusModel {
  @JsonKey(fromJson: OtaUpdateStatus.fromValue)
  final OtaUpdateStatus status;
  final int progress;
  final int upgradedSize;
  final String? error;

  OtaUpdateStatusModel(
    this.status,
    this.progress,
    this.upgradedSize,
    this.error,
  );

  factory OtaUpdateStatusModel.fromJson(Map<String, dynamic> json) =>
      _$OtaUpdateStatusModelFromJson(json);

  Map<String, dynamic> toJson() => _$OtaUpdateStatusModelToJson(this);
}
