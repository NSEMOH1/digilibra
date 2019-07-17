// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_response_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TransactionResponseItem _$TransactionResponseItemFromJson(
    Map<String, dynamic> json) {
  return TransactionResponseItem(
    json['version'] as String,
    json['expirationTime'] as String,
    json['publicKey'] as String,
    json['from'] as String,
    json['senderSignature'] as String,
    json['to'] as String,
    json['type'] as String,
    json['value'] as String,
    json['gasUnitPrice'] as String,
    json['maxGasAmount'] as String,
    json['sequenceNumber'] as String,
    json['gasUsed'] as String,
    json['signedTransactionHash'] as String,
    json['stateRootHash'] as String,
    json['eventRootHash'] as String,
  );
}

Map<String, dynamic> _$TransactionResponseItemToJson(
        TransactionResponseItem instance) =>
    <String, dynamic>{
      'version': instance.version,
      'expirationTime': instance.expirationTime,
      'publicKey': instance.publicKey,
      'from': instance.from,
      'senderSignature': instance.senderSignature,
      'to': instance.to,
      'type': instance.type,
      'value': instance.value,
      'gasUnitPrice': instance.gasUnitPrice,
      'maxGasAmount': instance.maxGasAmount,
      'sequenceNumber': instance.sequenceNumber,
      'gasUsed': instance.gasUsed,
      'signedTransactionHash': instance.signedTransactionHash,
      'stateRootHash': instance.stateRootHash,
      'eventRootHash': instance.eventRootHash,
    };
