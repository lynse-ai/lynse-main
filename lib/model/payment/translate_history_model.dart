import 'package:json_annotation/json_annotation.dart';

part 'translate_history_model.g.dart';

@JsonSerializable()
class TranslateHistoryModel {
  String? translateTaskId;
  String? sourceLanguage;
  String? targetLanguage;
  String? translateText;
  String? translateStatus;
  String? createTime;
  String? updateTime;

  TranslateHistoryModel();

  factory TranslateHistoryModel.fromJson(Map<String, dynamic> json) =>
      _$TranslateHistoryModelFromJson(json);

  Map<String, dynamic> toJson() => _$TranslateHistoryModelToJson(this);
}
