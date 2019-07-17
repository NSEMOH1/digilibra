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
      var state = event.libraAccountState;
      var authenticationKey = LibraHelpers.byteToHex(state.authenticationKey);
      if (authenticationKey == wallet.address) {
        setState(() {
          wallet.accountBalance = BigInt.from(state.balance);
          wallet.loading = false;
          wallet.localCurrencyPrice = '1';
          wallet.btcPrice = '1';
        });
      }
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
    super.dispose();
  }

  // Update the global wallet instance with a new address
  Future<void> updateWallet({Account account}) async {
    String seed = await sl.get<Vault>().getSeed();
    String address =
        await LibraUtil.seedToAddressInIsolate(seed, account.index);
    account.address = address;
    selectedAccount = account;
    setState(() {
      wallet = AppWallet(address: address, loading: true);
    });
    await updateRecentlyUsedAccounts();
    await updateTnxs(address);
    await updateBalances();
  }

  Future<void> updateTnxs(String address) async {
    var resp = await fetchTnxs(address);
    EventTaxiImpl.singleton().fire(HistoryEvent(response: resp));
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

  /// Create a tnx send request
  Future<void> requestSend(String to, String amount) async {
    String seed = await sl.get<Vault>().getSeed();
    var list = Mnemonic.entropyToMnemonic(seed);
    LibraWallet libraWallet = new LibraWallet(mnemonic: list.join(' '));
    LibraAccount libraAccount = libraWallet.generateAccount(0);
    LibraClient client = new LibraClient();
    await client.transferCoins(libraAccount, to, int.parse(amount));
    String from = libraAccount.getAddress();
    LibraAccountState fromState = await client.getAccountState(from);
    fromState = await client.getAccountState(from);
    //print('after balance: ${fromState.balance}, sq: ${fromState.sequenceNumber}');
    EventTaxiImpl.singleton()
        .fire(SendCompleteEvent(from: from, to: to, amount: amount));
    EventTaxiImpl.singleton().fire(AccountStateEvent(fromState));
    await updateTnxs(from);
  }

  /// Create a tnx receive request
  Future<void> requestReceive(String previous, String source, String balance,
      {String privKey, String account}) async {}

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

  // Update accounts states from local db
  Future<void> updateBalances() async {
    sl.get<DBHelper>().getAccounts().then((accounts) {
      accounts.forEach((account) async {
        LibraAccountState libraAccountState = await getState(account.address);
        if (BigInt.from(libraAccountState.balance) != wallet.accountBalance) {
          EventTaxiImpl.singleton().fire(AccountStateEvent(libraAccountState));
        }
        sl.get<DBHelper>().updateAccountBalance(
            account, libraAccountState.balance.toString());
      });
    });
  }

  static Future<LibraAccountState> _getState(Map<String, String> params) async {
    LibraClient client = new LibraClient();
    return await client.getAccountState(params['address']);
  }

  Future<LibraAccountState> getState(String address) async {
    return await compute(_getState, {'address': address});
  }
}
