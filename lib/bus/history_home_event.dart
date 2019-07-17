import 'package:event_taxi/event_taxi.dart';
import 'package:wallet/network/model/response/transaction_response_item.dart';

class HistoryHomeEvent implements Event {
  final List<TransactionResponseItem> items;

  HistoryHomeEvent({this.items});
}
