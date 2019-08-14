import 'dart:async';
import 'package:wallet/model/wallet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:wallet/themes.dart';
import 'package:wallet/service_locator.dart';
import 'package:wallet/model/available_themes.dart';
import 'package:wallet/model/available_currency.dart';
import 'package:wallet/model/available_language.dart';
import 'package:wallet/network/model/response/transactions_response.dart';
import 'package:wallet/model/vault.dart';
import 'package:wallet/model/db/appdb.dart';
import 'package:wallet/model/db/account.dart';
import 'package:wallet/util/sharedprefsutil.dart';
import 'package:wallet/util/librautil.dart';
import 'package:flutter_libra_core/flutter_libra_core.dart';
import 'package:wallet/bus/events.dart';
import 'package:event_taxi/event_taxi.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

class _InheritedStateContainer extends InheritedWidget {
  // Data is your entire state. In our case just 'User'
  final StateContainerState data;

  // You must pass through a child and your state.
  _InheritedStateContainer({
    Key key,
    @required this.data,
    @required Widget child,
  }) : super(key: key, child: child);

  // This is a built in method which you can use to check if
  // any state has changed. If not, no reason to rebuild all the widgets
  // that rely on your state.
  @override
  bool updateShouldNotify(_InheritedStateContainer old) => true;
}

class StateContainer extends StatefulWidget {
  // You must pass through a child.
  final Widget child;

  StateContainer({@required this.child});

  // This is the secret sauce. Write your own 'of' method that will behave
  // Exactly like MediaQuery.of and Theme.of
  // It basically says 'get the data from the widget of this type.
  static StateContainerState of(BuildContext context) {
    return (context.inheritFromWidgetOfExactType(_InheritedStateContainer)
            as _InheritedStateContainer)
        .data;
  }

  @override
  StateContainerState createState() => StateContainerState();
}

/// App InheritedWidget
/// This is where we handle the global state and also where
/// we interact with the server and make requests/handle+propagate responses
///
/// Basically the central hub behind the entire app
class StateContainerState extends State<StateContainer> {
  final Logger log = Logger('StateContainerState');
  // Minimum receive = 0.01 LIBRA
  String receiveMinimum = BigInt.from(10).pow(27).toString();

  AppWallet wallet;
  String currencyLocale;
  Locale deviceLocale = Locale('en', 'US');
  AvailableCurrency curCurrency = AvailableCurrency(AvailableCurrencyEnum.USD);
  LanguageSetting curLanguage = LanguageSetting(AvailableLanguage.DEFAULT);
  BaseTheme curTheme = LibraTheme();
  // Currently selected account
  Account selectedAccount =
      Account(id: 1, name: 'AB', index: 0, lastAccess: 0, selected: true);
  // Two most recently used accounts
  Account recentLast;
  Account recentSecondLast;

  // If callback is locked
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    // Register RxBus
    _registerBus();

    // Set currency locale here for the UI to access
    sl.get<SharedPrefsUtil>().getCurrency(deviceLocale).then((currency) {
      setState(() {
        currencyLocale = currency.getLocale().toString();
        curCurrency = currency;
      });
    });
    // Get default language setting
    sl.get<SharedPrefsUtil>().getLanguage().then((language) {
      setState(() {
        curLanguage = language;
      });
    });
    // Get theme default
    sl.get<SharedPrefsUtil>().getTheme().then((theme) {
      updateTheme(theme, setIcon: false);
    });
  }

// Subscriptions
  StreamSubscription<AccountStateEvent> _stateSub;
  StreamSubscription<HistoryEvent> _historyEventSub;

  // Register RX event listenerss
  void _registerBus() {
    // States for accounts
    _stateSub = EventTaxiImpl.singleton()
        .registerTo<AccountStateEvent>()
        .listen((event) {
      String address =
          LibraHelpers.byteToHex(event.libraAccountState.authenticationKey);
      print('receive AccountStateEvent: $address');
      BigInt balance = event.libraAccountState.balance;
      if (address == wallet.address) {
        setState(() {
          wallet.accountBalance = balance;
          wallet.loading = false;
          wallet.localCurrencyPrice = '1';
          wallet.btcPrice = '1';
        });
      }

      sl.get<DBHelper>().getAccount(address).then((account) {
        if (account != null &&
            account.address != null &&
            address == account.address &&
            balance.toString() != account.balance) {
          sl.get<DBHelper>().updateAccountBalance(address, balance.toString());
        }
      });
    });

    _historyEventSub =
        EventTaxiImpl.singleton().registerTo<HistoryEvent>().listen((event) {
      setState(() {
        // TODO: only update diff when ws is ready
        wallet.history = event.response.result;
        wallet.historyLoading = false;
        // Send list to home screen
        EventTaxiImpl.singleton().fire(HistoryHomeEvent(items: wallet.history));
      });
    });
  }

  @override
  void dispose() {
    _destroyBus();
    super.dispose();
  }

  void _destroyBus() {
    if (_stateSub != null) {
      _stateSub.cancel();
    }
    if (_historyEventSub != null) {
      _historyEventSub.cancel();
    }
  }

  // Update the global wallet instance with a new address
  Future<void> updateWallet({Account account}) async {
    String seed = await sl.get<Vault>().getSeed();
    String address = await LibraUtil.seedToAddressInIsolate(seed);
    account.address = address;
    selectedAccount = account;
    setState(() {
      wallet = AppWallet(address: address, loading: true);
    });
    await updateRecentlyUsedAccounts();
    await updateTnxs(address);
    await updateAccountStates();
  }

  Future<TransactionsResponse> updateTnxs(String address) async {
    print('fetching tnx for: $address');
    var resp = await fetchTnxs(address);
    EventTaxiImpl.singleton().fire(HistoryEvent(response: resp));
    return resp;
  }

  static Future<TransactionsResponse> _fetchTnxs(
      Map<String, String> params) async {
    Uri url = Uri.parse(params['url']);
    http.Client client = http.Client();
    http.Response res;
    res = await client.get(url);
    return new TransactionsResponse.fromJson(decodeJson(res.body));
  }

  static Map decodeJson(String src) {
    return json.decode(src);
  }

  Future<TransactionsResponse> fetchTnxs(String address) async {
    return await compute(_fetchTnxs, {
      'url':
          'https://api-test.libexplorer.com/api?module=account&action=txlist&address=$address'
    });
  }

  Future<void> updateRecentlyUsedAccounts() async {
    List<Account> otherAccounts =
        await sl.get<DBHelper>().getRecentlyUsedAccounts();
    if (otherAccounts != null && otherAccounts.length > 0) {
      if (otherAccounts.length > 1) {
        setState(() {
          recentLast = otherAccounts[0];
          recentSecondLast = otherAccounts[1];
        });
      } else {
        setState(() {
          recentLast = otherAccounts[0];
          recentSecondLast = null;
        });
      }
    } else {
      setState(() {
        recentLast = null;
        recentSecondLast = null;
      });
    }
  }

  // Change language
  void updateLanguage(LanguageSetting language) {
    setState(() {
      curLanguage = language;
      deviceLocale = deviceLocale;
    });
  }

  // Change theme
  void updateTheme(ThemeSetting theme, {bool setIcon = true}) {
    setState(() {
      curTheme = theme.getTheme();
    });
    if (setIcon) {
      AppIcon.setAppIcon(theme.getTheme().appIcon);
    }
  }

  void updateDeviceLocale(Locale locale) {
    setState(() {
      deviceLocale = locale;
    });
  }

  void lockCallback() {
    _locked = true;
  }

  void unlockCallback() {
    _locked = false;
  }

  // Update accounts states from db
  Future<void> updateAccountStates() async {
    List<Account> accounts = await sl.get<DBHelper>().getAccounts();
    List<String> addresses = [];
    accounts.forEach((account) {
      if (account != null && account.address != null) {
        addresses.add(account.address);
      }
    });
    List<LibraAccountState> states = await LibraUtil.getStates(addresses);
    states.forEach((s) {
      if (s.balance != wallet.accountBalance) {
        EventTaxiImpl.singleton().fire(AccountStateEvent(s));
      }
    });
  }

  // Request update accounts
  Future<void> requestAccountsStates(List<String> addresses) async {
    List<LibraAccountState> states = await LibraUtil.getStates(addresses);
    EventTaxiImpl.singleton().fire(AccountsStatesEvent(states));
  }

  /// Create a tnx send request
  Future<void> requestSend(String to, String amount,
      {needRefresh = true, String privKey}) async {
    var seed = await sl.get<Vault>().getSeed();
    var list = Mnemonic.entropyToMnemonic(seed);
    LibraWallet libraWallet = new LibraWallet(mnemonic: list.join(' '));
    LibraAccount libraAccount =
        libraWallet.generateAccount(selectedAccount.index);
    LibraClient client = new LibraClient();
    var res = await client.transferCoins(libraAccount, to, int.parse(amount));
    // TODO check res.vmStatus, fire TransferErrorEvent
    String from = libraAccount.getAddress();
    LibraAccountState fromState = await client.getAccountState(from);
    EventTaxiImpl.singleton()
        .fire(SendCompleteEvent(from: from, to: to, amount: amount));
    EventTaxiImpl.singleton().fire(AccountStateEvent(fromState));
    var tnxRes = await updateTnxs(from);
    if (tnxRes.result.length > 0) {
      EventTaxiImpl.singleton().fire(TransferProcessEvent(fromState));
    }
  }

  Future<void> requestReceive(String to, String amount, String privKey,
      {needRefresh = true}) async {
    LibraAccount libraAccount =
        LibraAccount.fromPrivateKey(LibraHelpers.hexToBytes(privKey));
    LibraClient client = new LibraClient();
    var res = await client.transferCoins(libraAccount, to, int.parse(amount));
    // TODO check res.vmStatus, fire TransferErrorEvent
    String from = libraAccount.getAddress();
    LibraAccountState toState = await client.getAccountState(to);
    EventTaxiImpl.singleton()
        .fire(SendCompleteEvent(from: from, to: to, amount: amount));
    EventTaxiImpl.singleton().fire(AccountStateEvent(toState));
    if (needRefresh) {
      var tnxRes = await updateTnxs(to); // update current account tnxs
      if (tnxRes.result.length > 0) {
        EventTaxiImpl.singleton().fire(TransferProcessEvent(toState));
      }
    }
  }

  Future<void> requestUpdate(String address) async {
    await updateTnxs(address);
    await updateAccountStates();
  }

  void logOut() {
    setState(() {
      wallet = AppWallet();
    });
    sl.get<DBHelper>().dropAccounts();
  }

  // Simple build method that just passes this state through
  // your InheritedWidget
  @override
  Widget build(BuildContext context) {
    return _InheritedStateContainer(
      data: this,
      child: widget.child,
    );
  }
}
