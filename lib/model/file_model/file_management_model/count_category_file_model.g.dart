// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'count_category_file_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FileCountByCategoryModel _$FileCountByCategoryModelFromJson(
  Map<String, dynamic> json,
) => FileCountByCategoryModel(
  all: (json['all'] as num).toInt(),
  unclassified: (json['unclassified'] as num).toInt(),
  folderStats:
      (json['folderStats'] as List<dynamic>?)
          ?.map((e) => FileCountModel.fromJson(e as Map<String, dynamic>))
          .toList(),
  classified: (json['classified'] as num).toInt(),
);

Map<String, dynamic> _$FileCountByCategoryModelToJson(
  FileCountByCategoryModel instance,
) => <String, dynamic>{
  'all': instance.all,
  'unclassified': instance.unclassified,
  'folderStats': instance.folderStats,
  'classified': instance.classified,
};
