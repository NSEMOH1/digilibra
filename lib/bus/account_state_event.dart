import 'package:event_taxi/event_taxi.dart';
import 'package:flutter_libra_core/flutter_libra_core.dart';

class AccountStateEvent implements Event {
  final LibraAccountState libraAccountState;
  AccountStateEvent(this.libraAccountState);
}
