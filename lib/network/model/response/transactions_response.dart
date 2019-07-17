import 'package:json_annotation/json_annotation.dart';

import 'package:wallet/network/model/response/transaction_response_item.dart';

part 'transactions_response.g.dart';

/// For running in an isolate, needs to be top-level function
TransactionsResponse transactionsResponseFromJson(Map<dynamic, dynamic> json) {
  return TransactionsResponse.fromJson(json);
}

@JsonSerializable()
class TransactionsResponse {
  @JsonKey(name: 'result')
  List<TransactionResponseItem> result;

  TransactionsResponse({List<TransactionResponseItem> result}) {
    this.result = result.reversed.toList();
  }

  factory TransactionsResponse.fromJson(Map<String, dynamic> json) =>
      _$TransactionsResponseFromJson(json);
  Map<String, dynamic> toJson() => _$TransactionsResponseToJson(this);
}
