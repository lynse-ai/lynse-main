import 'package:json_annotation/json_annotation.dart';

part 'check_wechat_model.g.dart';

@JsonSerializable()
class CheckWechatModel {
  String signature;
  String timestamp;
  String nonce;
  String echostr;

  CheckWechatModel({
    required this.signature,
    required this.timestamp,
    required this.nonce,
    required this.echostr,
  });

  factory CheckWechatModel.fromJson(Map<String, dynamic> json) =>
      _$CheckWechatModelFromJson(json);
  Map<String, dynamic> toJson() => _$CheckWechatModelToJson(this);
}
