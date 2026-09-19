// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sts_credential_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StsCredentialModel _$StsCredentialModelFromJson(Map<String, dynamic> json) =>
    StsCredentialModel(
      bucket: json['bucket'] as String,
      fileId: json['fileId'] as String,
      objectKey: json['objectKey'] as String,
      accessKeyId: json['accessKeyId'] as String,
      accessKeySecret: json['accessKeySecret'] as String,
      securityToken: json['securityToken'] as String,
      expiration: json['expiration'] as String,
      endpoint: json['endpoint'] as String?,
    );

Map<String, dynamic> _$StsCredentialModelToJson(StsCredentialModel instance) =>
    <String, dynamic>{
      'bucket': instance.bucket,
      'fileId': instance.fileId,
      'objectKey': instance.objectKey,
      'accessKeyId': instance.accessKeyId,
      'accessKeySecret': instance.accessKeySecret,
      'securityToken': instance.securityToken,
      'expiration': instance.expiration,
      'endpoint': instance.endpoint,
    };
