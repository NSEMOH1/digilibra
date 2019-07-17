import 'package:event_taxi/event_taxi.dart';

class SendCompleteEvent implements Event {
  final String from;
  final String to;
  final String amount;
  SendCompleteEvent({this.from, this.to, this.amount});
}
