// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'count_file_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FileCountModel _$FileCountModelFromJson(Map<String, dynamic> json) =>
    FileCountModel(
      folderId: json['folderId'] as String?,
      count: (json['count'] as num).toInt(),
    );

Map<String, dynamic> _$FileCountModelToJson(FileCountModel instance) =>
    <String, dynamic>{'folderId': instance.folderId, 'count': instance.count};
