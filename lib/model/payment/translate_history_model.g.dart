// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'translate_history_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TranslateHistoryModel _$TranslateHistoryModelFromJson(
  Map<String, dynamic> json,
) =>
    TranslateHistoryModel()
      ..translateTaskId = json['translateTaskId'] as String?
      ..sourceLanguage = json['sourceLanguage'] as String?
      ..targetLanguage = json['targetLanguage'] as String?
      ..translateText = json['translateText'] as String?
      ..translateStatus = json['translateStatus'] as String?
      ..createTime = json['createTime'] as String?
      ..updateTime = json['updateTime'] as String?;

Map<String, dynamic> _$TranslateHistoryModelToJson(
  TranslateHistoryModel instance,
) => <String, dynamic>{
  'translateTaskId': instance.translateTaskId,
  'sourceLanguage': instance.sourceLanguage,
  'targetLanguage': instance.targetLanguage,
  'translateText': instance.translateText,
  'translateStatus': instance.translateStatus,
  'createTime': instance.createTime,
  'updateTime': instance.updateTime,
};
