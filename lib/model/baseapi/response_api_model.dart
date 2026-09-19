import 'package:json_annotation/json_annotation.dart';

part 'response_api_model.g.dart';

@JsonSerializable()
class ResponseApiModel {
  int? total;
  int code;
  String msg;
  dynamic data;

  factory ResponseApiModel.genDefualt() {
    return ResponseApiModel(code: -1, msg: '', data: null);
  }

  ResponseApiModel({
    required this.code,
    this.total,
    required this.msg,
    required this.data,
  });

  factory ResponseApiModel.fromJson(Map<String, dynamic> json) =>
      _$ResponseApiModelFromJson(json);
  Map<String, dynamic> toJson() => _$ResponseApiModelToJson(this);
}
