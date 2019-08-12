import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_libra_core/flutter_libra_core.dart';
import 'package:wallet/service_locator.dart';
import 'package:wallet/model/db/appdb.dart';
import 'package:wallet/model/db/account.dart';
import 'package:wallet/appstate_container.dart';
import 'package:wallet/localization.dart';

class LibraUtil {
  static LibraAccount _seedToAccount(Map<dynamic, dynamic> params) {
    int index = params['index'];
    assert(index >= 0);
    String seed = params['seed'];
    String mnemonic = Mnemonic.entropyToMnemonic(seed).join(' ');
    LibraWallet libraWallet = new LibraWallet(mnemonic: mnemonic);
    return libraWallet.generateAccount(index);
  }

  static Future<LibraAccount> seedToAccountInIsolate(
      String seed, int index) async {
    return await compute(
        LibraUtil._seedToAccount, {'seed': seed, 'index': index});
  }

  static String _seedToAddress(Map<dynamic, dynamic> params) {
    int index = params['index'];
    assert(index >= 0);
    String seed = params['seed'];
    String mnemonic = Mnemonic.entropyToMnemonic(seed).join(' ');
    LibraWallet libraWallet = new LibraWallet(mnemonic: mnemonic);
    LibraAccount libraAccount = libraWallet.generateAccount(index);
    return libraAccount.getAddress();
  }

  static Future<String> seedToAddressInIsolate(String seed, {int index}) async {
    if (index == null) {
      index = 0;
    }
    return await compute(
        LibraUtil._seedToAddress, {'seed': seed, 'index': index});
  }

  static Future<void> loginAccount(BuildContext context, String seed) async {
    Account selectedAcct = await sl.get<DBHelper>().getSelectedAccount();
    if (selectedAcct == null) {
      int defaultIndex = 0;
      String address =
          await LibraUtil.seedToAddressInIsolate(seed, index: defaultIndex);
      selectedAcct = Account(
          index: defaultIndex,
          lastAccess: 0,
          name: AppLocalization.of(context).defaultAccountName,
          selected: true,
          address: address);
      await sl.get<DBHelper>().saveAccount(selectedAcct);
    }
    StateContainer.of(context).updateWallet(account: selectedAcct);
  }

  static Future<List<LibraAccountState>> _getStates(
      Map<dynamic, dynamic> params) async {
    String addressVal = params['addresses'];
    List<String> addresses = addressVal.split(';');
    LibraClient client = new LibraClient();
    return await client.getAccountStates(addresses);
  }

  static Future<List<LibraAccountState>> getStatesInIsolate(
      List<String> addresses) async {
    if (addresses.length <= 0) {
      return [];
    }
    String addressVal = addresses.join(';');
    return await compute(LibraUtil._getStates, {'addresses': addressVal});
  }
}
