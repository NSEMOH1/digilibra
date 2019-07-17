import 'package:json_annotation/json_annotation.dart';
import 'package:wallet/model/address.dart';
import 'package:wallet/util/numberutil.dart';
import 'package:wallet/service_locator.dart';
import 'package:wallet/constants.dart';

part 'transaction_response_item.g.dart';

@JsonSerializable()
class TransactionResponseItem {
  @JsonKey(name: 'version')
  String version;

  @JsonKey(name: 'expirationTime')
  String expirationTime;

  @JsonKey(name: 'publicKey')
  String publicKey;

  @JsonKey(name: 'from')
  String from;

  @JsonKey(name: 'senderSignature')
  String senderSignature;

  @JsonKey(name: 'to')
  String to;

  @JsonKey(name: 'type')
  String type;

  @JsonKey(name: 'value')
  String value;

  @JsonKey(name: 'gasUnitPrice')
  String gasUnitPrice;

  @JsonKey(name: 'maxGasAmount')
  String maxGasAmount;

  @JsonKey(name: 'sequenceNumber')
  String sequenceNumber;

  @JsonKey(name: 'gasUsed')
  String gasUsed;

  @JsonKey(name: 'signedTransactionHash')
  String signedTransactionHash;

  @JsonKey(name: 'stateRootHash')
  String stateRootHash;

  @JsonKey(name: 'eventRootHash')
  String eventRootHash;

  TransactionResponseItem(
      this.version,
      this.expirationTime,
      this.publicKey,
      this.from,
      this.senderSignature,
      this.to,
      this.type,
      this.value,
      this.gasUnitPrice,
      this.maxGasAmount,
      this.sequenceNumber,
      this.gasUsed,
      this.signedTransactionHash,
      this.stateRootHash,
      this.eventRootHash);

  String getShortString() {
    if (this.from == MintAccount) {
        return MintDisplayName;
    }
    return new Address(this.from).getShortString();
  }

  String getShorterString() {
    if (this.from == MintAccount) {
        return MintDisplayName;
    }
    return new Address(this.from).getShorterString();
  }

  String getFormattedAmount() {
    return sl.get<NumberUtil>().getRawAsUsableString(value);
  }

  factory TransactionResponseItem.fromJson(Map<String, dynamic> json) =>
      _$TransactionResponseItemFromJson(json);
  Map<String, dynamic> toJson() => _$TransactionResponseItemToJson(this);
}
