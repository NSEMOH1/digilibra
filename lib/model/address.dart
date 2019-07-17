import 'dart:core';

// Object to represent an account address or address URI, and provide useful utilities
class Address {
  String _address;
  String _amount;

  Address(String value) {
    _parseAddressString(value);
  }

  String get address => _address;

  String get amount => _amount;

  String getShortString() {
    if (_address == null || _address.length < 64) return null;
    return _address.substring(0, 11) +
        '...' +
        _address.substring(_address.length - 6);
  }

  String getShorterString() {
    if (_address == null || _address.length < 64) return null;
    return _address.substring(0, 9) +
        '...' +
        _address.substring(_address.length - 4);
  }

  bool isValid() {
    return _address != null;
  }

  void _parseAddressString(String value) {
    if (value != null) {
      value = value.toLowerCase();
      _address = value;
      var split = value.split(':');
      if (split.length > 1) {
        Uri uri = Uri.tryParse(value);
        if (uri != null && uri.queryParameters['amount'] != null) {
          BigInt amount = BigInt.tryParse(uri.queryParameters['amount']);
          if (amount != null) {
            _amount = amount.toString();
          }
        }
      }
    }
  }
}
