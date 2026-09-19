// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcription_language_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TranscriptionLanguageModel _$TranscriptionLanguageModelFromJson(
  Map<String, dynamic> json,
) => TranscriptionLanguageModel(
  id: json['id'] as String?,
  dictType: json['dictType'] as String?,
  dictValue: json['dictValue'] as String?,
  sortOrder: (json['sortOrder'] as num?)?.toInt(),
  isTranslated: json['isTranslated'] as bool?,
  remark: json['remark'] as String?,
);

Map<String, dynamic> _$TranscriptionLanguageModelToJson(
  TranscriptionLanguageModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'dictType': instance.dictType,
  'dictValue': instance.dictValue,
  'sortOrder': instance.sortOrder,
  'isTranslated': instance.isTranslated,
  'remark': instance.remark,
};
