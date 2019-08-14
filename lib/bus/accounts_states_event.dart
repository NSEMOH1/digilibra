import 'package:event_taxi/event_taxi.dart';
import 'package:flutter_libra_core/flutter_libra_core.dart';

class AccountsStatesEvent implements Event {
  final List<LibraAccountState> libraAccountsStates;
  AccountsStatesEvent(this.libraAccountsStates);
}
