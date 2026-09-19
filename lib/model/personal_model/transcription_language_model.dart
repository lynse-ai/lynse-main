import 'package:json_annotation/json_annotation.dart';

part 'transcription_language_model.g.dart';

@JsonSerializable()
class TranscriptionLanguageModel {
  @JsonKey(name: 'id')
  String? id;
  @JsonKey(name: 'dictType')
  String? dictType;
  @JsonKey(name: 'dictValue')
  String? dictValue;
  @JsonKey(name: 'sortOrder')
  int? sortOrder;
  @JsonKey(name: 'isTranslated')
  bool? isTranslated;
  @JsonKey(name: 'remark')
  String? remark;

  TranscriptionLanguageModel({
    this.id,
    this.dictType,
    this.dictValue,
    this.sortOrder,
    this.isTranslated,
    this.remark,
  });

  factory TranscriptionLanguageModel.fromJson(Map<String, dynamic> json) =>
      _$TranscriptionLanguageModelFromJson(json);

  Map<String, dynamic> toJson() => _$TranscriptionLanguageModelToJson(this);
}
