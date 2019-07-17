import 'package:event_taxi/event_taxi.dart';
import 'package:wallet/network/model/response/transactions_response.dart';

class HistoryEvent implements Event {
  final TransactionsResponse response;

  HistoryEvent({this.response});
}
