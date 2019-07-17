import 'package:event_taxi/event_taxi.dart';
import 'package:wallet/model/db/contact.dart';

class ContactRemovedEvent implements Event {
  final Contact contact;

  ContactRemovedEvent({this.contact});
}