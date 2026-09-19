import 'package:json_annotation/json_annotation.dart';

part 'share_model.g.dart';

@JsonSerializable()
class ShareModel {
  String? sharerId;
  String? shareTime;
  String? expirationTime;
  String? shareUrl;
  String? shareTitle;
  String? shareMessage;

  ShareModel({
    this.sharerId,
    this.shareTime,
    this.expirationTime,
    this.shareUrl,
    this.shareTitle,
    this.shareMessage,
  });

  factory ShareModel.fromJson(Map<String, dynamic> json) =>
      _$ShareModelFromJson(json);

  Map<String, dynamic> toJson() => _$ShareModelToJson(this);
}
