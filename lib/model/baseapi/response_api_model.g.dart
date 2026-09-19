// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'response_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResponseApiModel _$ResponseApiModelFromJson(Map<String, dynamic> json) =>
    ResponseApiModel(
      code: (json['code'] as num).toInt(),
      total: (json['total'] as num?)?.toInt(),
      msg: json['msg'] as String,
      data: json['data'],
    );

Map<String, dynamic> _$ResponseApiModelToJson(ResponseApiModel instance) =>
    <String, dynamic>{
      'total': instance.total,
      'code': instance.code,
      'msg': instance.msg,
      'data': instance.data,
    };
