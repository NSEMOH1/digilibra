import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:wallet/service_locator.dart';
import 'package:wallet/util/numberutil.dart';
import 'package:wallet/network/model/response/transaction_response_item.dart';

/// Main wallet object that's passed around the app via state
class AppWallet {
  bool _loading; // Whether or not app is initially loading
  bool _historyLoading;
  String _address;
  BigInt _accountBalance;
  String _localCurrencyPrice;
  String _btcPrice;
  List<TransactionResponseItem> _history;

  AppWallet(
      {String address,
      BigInt accountBalance,
      String localCurrencyPrice,
      String btcPrice,
      List<TransactionResponseItem> history,
      bool loading,
      bool historyLoading}) {
    this._address = address;
    this._accountBalance = accountBalance ?? BigInt.zero;
    this._localCurrencyPrice = localCurrencyPrice ?? '0';
    this._btcPrice = btcPrice ?? '0';
    this._loading = loading ?? true;
    this._historyLoading = historyLoading ?? true;
    this._history = history ?? new List<TransactionResponseItem>();
  }

  String get address => _address;

  set address(String address) {
    this._address = address;
  }

  BigInt get accountBalance => _accountBalance;

  set accountBalance(BigInt accountBalance) {
    this._accountBalance = accountBalance;
  }

  // Get pretty account balance version
  String getAccountBalanceDisplay() {
    if (accountBalance == null) {
      return '0';
    }
    return sl
        .get<NumberUtil>()
        .getRawAsUsableString(_accountBalance.toString());
  }

  String getLocalCurrencyPrice({String locale = 'en_US'}) {
    Decimal converted = Decimal.parse(_localCurrencyPrice) *
        sl.get<NumberUtil>().getRawAsUsableDecimal(_accountBalance.toString());
    return NumberFormat.simpleCurrency(locale: locale)
        .format(converted.toDouble());
  }

  set localCurrencyPrice(String value) {
    _localCurrencyPrice = value;
  }

  String get localCurrencyConversion {
    return _localCurrencyPrice;
  }

  String get btcPrice {
    Decimal converted = Decimal.parse(_btcPrice) *
        sl.get<NumberUtil>().getRawAsUsableDecimal(_accountBalance.toString());
    // Show 4 decimal places for BTC price if its >= 0.0001 BTC, otherwise 6 decimals
    if (converted >= Decimal.parse('0.0001')) {
      return new NumberFormat('#,##0.0000', 'en_US')
          .format(converted.toDouble());
    } else {
      return new NumberFormat('#,##0.000000', 'en_US')
          .format(converted.toDouble());
    }
  }

  set btcPrice(String value) {
    _btcPrice = value;
  }

  bool get loading => _loading;

  set loading(bool value) {
    _loading = value;
  }

  bool get historyLoading => _historyLoading;

  set historyLoading(bool value) {
    _historyLoading = value;
  }

  List<TransactionResponseItem> get history => _history;

  set history(List<TransactionResponseItem> value) {
    _history = value;
  }
}
