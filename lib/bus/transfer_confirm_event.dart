import 'package:event_taxi/event_taxi.dart';
import 'package:flutter_libra_core/flutter_libra_core.dart';

class TransferConfirmEvent implements Event {
  final Map<String, LibraAccountState> libraAccountStateMap;
  final Map<String, LibraAccount> libraAccountMap;

  TransferConfirmEvent({this.libraAccountStateMap, this.libraAccountMap});
}
