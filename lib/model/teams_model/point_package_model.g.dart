// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'point_package_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PointPackageModel _$PointPackageModelFromJson(Map<String, dynamic> json) =>
    PointPackageModel(
      id: json['id'] as String,
      pointsPackageCode: json['pointsPackageCode'] as String,
      pointsPackageName: json['pointsPackageName'] as String?,
      pointsAmount: (json['pointsAmount'] as num?)?.toInt(),
      discountRate: (json['discountRate'] as num?)?.toDouble(),
      originalPrice: (json['originalPrice'] as num).toDouble(),
      discountPrice: (json['discountPrice'] as num?)?.toDouble(),
      pointsPackageType: json['pointsPackageType'] as String?,
      channel: json['channel'] as String?,
      status: (json['status'] as num?)?.toInt(),
      sort: (json['sort'] as num?)?.toInt(),
    );

Map<String, dynamic> _$PointPackageModelToJson(PointPackageModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'pointsPackageCode': instance.pointsPackageCode,
      'pointsPackageName': instance.pointsPackageName,
      'pointsAmount': instance.pointsAmount,
      'discountRate': instance.discountRate,
      'originalPrice': instance.originalPrice,
      'discountPrice': instance.discountPrice,
      'pointsPackageType': instance.pointsPackageType,
      'channel': instance.channel,
      'status': instance.status,
      'sort': instance.sort,
    };
