// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seat_package_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SeatPackageModel _$SeatPackageModelFromJson(Map<String, dynamic> json) =>
    SeatPackageModel(
      id: json['id'] as String,
      teamSeatPackageCode: json['teamSeatPackageCode'] as String,
      teamSeatAmount: (json['teamSeatAmount'] as num?)?.toInt(),
      discountRate: (json['discountRate'] as num?)?.toDouble(),
      discountPrice: (json['discountPrice'] as num?)?.toDouble(),
      originalPrice: (json['originalPrice'] as num?)?.toDouble(),
      status: (json['status'] as num?)?.toInt(),
      sortOrder: (json['sortOrder'] as num?)?.toInt(),
    );

Map<String, dynamic> _$SeatPackageModelToJson(SeatPackageModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'teamSeatPackageCode': instance.teamSeatPackageCode,
      'teamSeatAmount': instance.teamSeatAmount,
      'originalPrice': instance.originalPrice,
      'discountRate': instance.discountRate,
      'discountPrice': instance.discountPrice,
      'status': instance.status,
      'sortOrder': instance.sortOrder,
    };
