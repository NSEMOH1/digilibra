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
  static String seedToPrivate(Map<dynamic, dynamic> params) {
    int index = params['index'];
    assert(index >= 0);
    String seed = params['seed'];
    String mnemonic = Mnemonic.entropyToMnemonic(seed).join(' ');
    LibraWallet libraWallet = new LibraWallet(mnemonic: mnemonic);
    LibraAccount libraAccount = libraWallet.generateAccount(index);
    return LibraHelpers.byteToHex(libraAccount.keyPair.getPrivateKey());
  }

  static Future<String> seedToPrivateInIsolate(String seed, int index) async {
    return await compute(
        LibraUtil.seedToPrivate, {'seed': seed, 'index': index});
  }

  static String seedToAddress(Map<dynamic, dynamic> params) {
    int index = params['index'];
    assert(index >= 0);
    String seed = params['seed'];
    String mnemonic = Mnemonic.entropyToMnemonic(seed).join(' ');
    LibraWallet libraWallet = new LibraWallet(mnemonic: mnemonic);
    LibraAccount libraAccount = libraWallet.generateAccount(index);
    return libraAccount.getAddress();
  }

  static Future<String> seedToAddressInIsolate(String seed, int index) async {
    return await compute(
        LibraUtil.seedToAddress, {'seed': seed, 'index': index});
  }

  static Future<void> loginAccount(BuildContext context) async {
    Account selectedAcct = await sl.get<DBHelper>().getSelectedAccount();
    if (selectedAcct == null) {
      selectedAcct = Account(
          index: 0,
          lastAccess: 0,
          name: AppLocalization.of(context).defaultAccountName,
          selected: true);
      await sl.get<DBHelper>().saveAccount(selectedAcct);
    }
    StateContainer.of(context).updateWallet(account: selectedAcct);
  }
}
