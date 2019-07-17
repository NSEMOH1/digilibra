import 'package:json_annotation/json_annotation.dart';
import 'package:wallet/network/model/request/actions.dart';
import 'package:wallet/network/model/base_request.dart';

part 'subscribe_request.g.dart';

@JsonSerializable()
class SubscribeRequest extends BaseRequest {
  @JsonKey(name: 'action')
  String action;

  @JsonKey(name: 'account', includeIfNull: false)
  String account;

  @JsonKey(name: 'currency', includeIfNull: false)
  String currency;

  @JsonKey(name: 'uuid', includeIfNull: false)
  String uuid;

  SubscribeRequest(
      {this.action = Actions.SUBSCRIBE,
      this.account,
      this.currency,
      this.uuid})
      : super();

  factory SubscribeRequest.fromJson(Map<String, dynamic> json) =>
      _$SubscribeRequestFromJson(json);
  Map<String, dynamic> toJson() => _$SubscribeRequestToJson(this);
}
