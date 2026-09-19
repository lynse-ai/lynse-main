// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'edit_trans_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EditTransModel _$EditTransModelFromJson(Map<String, dynamic> json) =>
    EditTransModel(
      recordId: json['recordId'] as String?,
      speakerId: json['speakerId'] as String?,
      speakerName: json['speakerName'] as String?,
      endTime: (json['endTime'] as num?)?.toInt(),
      text: json['text'] as String?,
    );

Map<String, dynamic> _$EditTransModelToJson(EditTransModel instance) =>
    <String, dynamic>{
      'recordId': instance.recordId,
      'speakerId': instance.speakerId,
      'speakerName': instance.speakerName,
      'endTime': instance.endTime,
      'text': instance.text,
    };
