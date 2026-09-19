// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page_size_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PageSizeModel _$PageSizeModelFromJson(Map<String, dynamic> json) =>
    PageSizeModel(
      page: (json['page'] as num).toInt(),
      size: (json['size'] as num).toInt(),
    );

Map<String, dynamic> _$PageSizeModelToJson(PageSizeModel instance) =>
    <String, dynamic>{'page': instance.page, 'size': instance.size};
