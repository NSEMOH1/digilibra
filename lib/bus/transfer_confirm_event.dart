import 'package:event_taxi/event_taxi.dart';
import 'package:wallet/network/model/response/account_state_item.dart';

class TransferConfirmEvent implements Event {
  final Map<String, AccountStateItem> balMap;

  TransferConfirmEvent({this.balMap});
}