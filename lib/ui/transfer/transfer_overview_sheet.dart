import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:barcode_scan/barcode_scan.dart';
import 'package:flutter_libra_core/flutter_libra_core.dart';
import 'package:event_taxi/event_taxi.dart';
import 'package:wallet/service_locator.dart';
import 'package:wallet/localization.dart';
import 'package:wallet/dimens.dart';
import 'package:wallet/appstate_container.dart';
import 'package:wallet/bus/events.dart';
import 'package:wallet/ui/transfer/transfer_manual_entry_sheet.dart';
import 'package:wallet/ui/widgets/auto_resize_text.dart';
import 'package:wallet/ui/widgets/sheets.dart';
import 'package:wallet/ui/widgets/buttons.dart';
import 'package:wallet/ui/widgets/dialog.dart';
import 'package:wallet/ui/util/ui_util.dart';
import 'package:wallet/styles.dart';
import 'package:wallet/util/caseconverter.dart';
import 'package:wallet/util/librautil.dart';

class AppTransferOverviewSheet {
  static const int NUM_SWEEP = 4; // Number of accounts to sweep from a seed

  Map<String, LibraAccountState> libraAccountStateMap = Map();
  Map<String, LibraAccount> libraAccountMap = Map();

  bool _animationOpen = false;

  StreamSubscription<AccountsStatesEvent> _stateSub;

  Future<bool> _onWillPop() async {
    if (_stateSub != null) {
      _stateSub.cancel();
    }
    return true;
  }

  mainBottomSheet(BuildContext context) {
    // Handle accounts states change
    _stateSub = EventTaxiImpl.singleton()
        .registerTo<AccountsStatesEvent>()
        .listen((event) {
      if (_animationOpen) {
        Navigator.of(context).pop();
      }
      List<String> addressesToRemove = List();
      event.libraAccountsStates.forEach((s) {
        String address = LibraHelpers.byteToHex(s.authenticationKey);
        print('$address: ${s.balance.toString()}');
        if (s.balance <= BigInt.zero) {
          addressesToRemove.add(address);
        } else {
          libraAccountStateMap[address] = s;
        }
      });
      print('addressesToRemove: $addressesToRemove');
      addressesToRemove.forEach((String address) {
        libraAccountStateMap.remove(address);
        libraAccountMap.remove(address);
      });
      if (libraAccountStateMap.length == 0) {
        sl
            .get<UIUtil>()
            .showSnackbar(AppLocalization.of(context).transferNoFunds, context);
        return;
      }
      // Go to confirmation screen
      EventTaxiImpl.singleton().fire(TransferConfirmEvent(
          libraAccountStateMap: libraAccountStateMap,
          libraAccountMap: libraAccountMap));
      Navigator.of(context).pop();
    });

    void manualEntryCallback(String seed) {
      Navigator.of(context).pop();
      startTransfer(context, seed, manualEntry: true);
    }

    AppSheets.showAppHeightNineSheet(
        context: context,
        onDisposed: _onWillPop,
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return WillPopScope(
              onWillPop: _onWillPop,
              child: SafeArea(
                minimum: EdgeInsets.only(
                  bottom: MediaQuery.of(context).size.height * 0.035,
                ),
                child: Container(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      // A container for the header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Emtpy SizedBox
                          SizedBox(
                            height: 60,
                            width: 60,
                          ),
                          // The header
                          Column(
                            children: <Widget>[
                              // Sheet handle
                              Container(
                                margin: EdgeInsets.only(top: 10),
                                height: 5,
                                width: MediaQuery.of(context).size.width * 0.15,
                                decoration: BoxDecoration(
                                  color: StateContainer.of(context)
                                      .curTheme
                                      .text10,
                                  borderRadius: BorderRadius.circular(100.0),
                                ),
                              ),
                              Container(
                                margin: EdgeInsets.only(top: 15.0),
                                constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width -
                                            140),
                                child: AutoSizeText(
                                  CaseChange.toUpperCase(
                                      AppLocalization.of(context)
                                          .transferHeader,
                                      context),
                                  style: AppStyles.textStyleHeader(context),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  stepGranularity: 0.1,
                                ),
                              ),
                            ],
                          ),
                          // Emtpy SizedBox
                          SizedBox(
                            height: 60,
                            width: 60,
                          ),
                        ],
                      ),

                      // A container for the illustration and paragraphs
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.of(context).size.height * 0.2,
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.6),
                              child: Stack(
                                children: <Widget>[
                                  Center(
                                    child: SvgPicture.asset(
                                        'assets/transferfunds_illustration_start_paperwalletonly.svg',
                                        color: StateContainer.of(context)
                                            .curTheme
                                            .text45,
                                        width:
                                            MediaQuery.of(context).size.width),
                                  ),
                                  Center(
                                    child: SvgPicture.asset(
                                      'assets/transferfunds_illustration_start_librawalletonly.svg',
                                      color: StateContainer.of(context)
                                          .curTheme
                                          .primary,
                                      width: MediaQuery.of(context).size.width,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              alignment: AlignmentDirectional(-1, 0),
                              margin: EdgeInsets.symmetric(
                                  horizontal: smallScreen(context) ? 35 : 50,
                                  vertical: 20),
                              child: AutoSizeText(
                                AppLocalization.of(context)
                                    .transferIntro
                                    .replaceAll('%1',
                                        AppLocalization.of(context).scanQrCode),
                                style: AppStyles.textStyleParagraph(context),
                                textAlign: TextAlign.start,
                                maxLines: 6,
                                stepGranularity: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Row(
                        children: <Widget>[
                          AppButton.buildAppButton(
                            context,
                            AppButtonType.PRIMARY,
                            AppLocalization.of(context).scanQrCode,
                            Dimens.BUTTON_TOP_DIMENS,
                            onPressed: () {
                              sl.get<UIUtil>().cancelLockEvent();
                              BarcodeScanner.scan(StateContainer.of(context)
                                      .curTheme
                                      .qrScanTheme)
                                  .then((value) {
                                if (!Entropy.isValidEntropy(value)) {
                                  sl.get<UIUtil>().showSnackbar(
                                      AppLocalization.of(context).qrInvalidSeed,
                                      context);
                                  return;
                                }
                                startTransfer(context, value);
                              });
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: <Widget>[
                          AppButton.buildAppButton(
                            context,
                            AppButtonType.PRIMARY_OUTLINE,
                            AppLocalization.of(context).manualEntry,
                            Dimens.BUTTON_BOTTOM_DIMENS,
                            onPressed: () {
                              AppTransferManualEntrySheet(manualEntryCallback)
                                  .mainBottomSheet(context);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          });
        });
  }

  void startTransfer(BuildContext context, String seed,
      {bool manualEntry = false}) {
    // Show loading overlay
    _animationOpen = true;
    AnimationType animation = manualEntry
        ? AnimationType.TRANSFER_SEARCHING_MANUAL
        : AnimationType.TRANSFER_SEARCHING_QR;
    Navigator.of(context).push(AnimationLoadingOverlay(
        animation,
        StateContainer.of(context).curTheme.animationOverlayStrong,
        StateContainer.of(context).curTheme.animationOverlayMedium,
        onPoppedCallback: () {
      _animationOpen = false;
    }));
    // Get accounts from seed
    getAccountsFromSeed(context, seed).then((addressesToRequest) {
      StateContainer.of(context).requestAccountsStates(addressesToRequest);
    });
  }

  /// Get NUM_SWEEP accounts from seed to request balances for
  Future<List<String>> getAccountsFromSeed(
      BuildContext context, String seed) async {
    List<String> addressesToRequest = [];
    // Get NUM_SWEEP private keys + accounts from seed
    for (int i = 0; i < NUM_SWEEP; i++) {
      LibraAccount libraAccount =
          await LibraUtil.seedToAccountInIsolate(seed, i);
      String address = libraAccount.getAddress();
      // Don't add this if it is the currently logged in account
      if (address != null && address != StateContainer.of(context).wallet.address) {
        libraAccountMap.putIfAbsent(address, () => libraAccount);
        addressesToRequest.add(address);
      }
    }
    return addressesToRequest;
  }
}
