import 'package:json_annotation/json_annotation.dart';

part 'sts_credential_model.g.dart';

@JsonSerializable(createFactory: true, createToJson: true, includeIfNull: false)
class StsCredentialModel {
  String fileId;
  String bucket;
  String objectKey;
  String accessKeyId;
  String accessKeySecret;
  String securityToken;
  String expiration;
  String? endpoint;

  StsCredentialModel({
    required this.bucket,
    required this.fileId,
    required this.objectKey,
    required this.accessKeyId,
    required this.accessKeySecret,
    required this.securityToken,
    required this.expiration,
    this.endpoint,
  });

  factory StsCredentialModel.fromJson(Map<String, dynamic> json) =>
      _$StsCredentialModelFromJson(json);

  Map<String, dynamic> toJson() => _$StsCredentialModelToJson(this);
}
