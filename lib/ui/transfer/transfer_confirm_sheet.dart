import 'dart:async';
import 'package:flutter/material.dart';
import 'package:event_taxi/event_taxi.dart';
import 'package:flutter_libra_core/flutter_libra_core.dart';
import 'package:wallet/appstate_container.dart';
import 'package:wallet/localization.dart';
import 'package:wallet/dimens.dart';
import 'package:wallet/service_locator.dart';
import 'package:wallet/bus/events.dart';
import 'package:wallet/ui/widgets/auto_resize_text.dart';
import 'package:wallet/ui/widgets/sheets.dart';
import 'package:wallet/ui/widgets/buttons.dart';
import 'package:wallet/ui/widgets/dialog.dart';
import 'package:wallet/util/numberutil.dart';
import 'package:wallet/util/caseconverter.dart';
import 'package:wallet/styles.dart';

class AppTransferConfirmSheet {
  Map<String, LibraAccountState> libraAccountStateMap = Map();
  Map<String, LibraAccount> libraAccountMap = Map();

  // accounts that have all been pocketed and ready to send
  Map<String, LibraAccountState> readyToSendMap = Map();
  // Total amount there is to transfer
  BigInt totalToTransfer = BigInt.zero;
  String totalAsReadableAmount = '';
  // Total amount transferred in raw
  BigInt totalTransferred = BigInt.zero;
  // Whether we finished transfer and are ready to start pocketing
  bool finished = false;
  // Whether animation overlay is open
  bool animationOpen = false;

  Function errorCallback;

  AppTransferConfirmSheet(
      this.libraAccountStateMap, this.libraAccountMap, this.errorCallback);

  StreamSubscription<TransferProcessEvent> _processSub;
  StreamSubscription<TransferErrorEvent> _errorSub;

  Future<bool> _onWillPop() async {
    if (_processSub != null) {
      _processSub.cancel();
    }
    if (_errorSub != null) {
      _errorSub.cancel();
    }
    EventTaxiImpl.singleton().fire(UnlockCallbackEvent());
    return true;
  }

  mainBottomSheet(BuildContext context) {
    // Transaction callback responses
    StateContainer.of(context).lockCallback();
    // See how much we have to transfer and separate accounts with pendings
    List<String> accountsToRemove = List();
    libraAccountStateMap
        .forEach((String address, LibraAccountState accoutState) {
      totalToTransfer += accoutState.balance;
      if (accoutState.balance > BigInt.zero) {
        readyToSendMap.putIfAbsent(address, () => accoutState);
        accountsToRemove.add(address);
      } else if (accoutState.balance == BigInt.zero) {
        accountsToRemove.add(address);
      }
    });
    accountsToRemove.forEach((account) {
      libraAccountStateMap.remove(account);
    });
    totalAsReadableAmount =
        sl.get<NumberUtil>().getRawAsUsableString(totalToTransfer.toString());

    // Process response
    _processSub = EventTaxiImpl.singleton()
        .registerTo<TransferProcessEvent>()
        .listen((event) {
      LibraAccountState updated = event.libraAccountState;
      String address = LibraHelpers.byteToHex(updated.authenticationKey);
      // A paper wallet account
      LibraAccountState libraAccountState =
          libraAccountStateMap.remove(address);
      if (libraAccountState != null) {
        libraAccountStateMap[address] = event.libraAccountState;
        // Process next item
      } else {
        libraAccountState = readyToSendMap.remove(event.libraAccountState);
        if (libraAccountState == null) {
          errorCallback();
        }
        totalTransferred += libraAccountState.balance;
        startProcessing(context);
      }
    });

    // Error response
    _errorSub = EventTaxiImpl.singleton()
        .registerTo<TransferErrorEvent>()
        .listen((event) {
      if (animationOpen) {
        Navigator.of(context).pop();
      }
      errorCallback();
    });

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
                      //A container for the header
                      Container(
                        margin: EdgeInsets.only(top: 30.0, left: 70, right: 70),
                        child: AutoSizeText(
                          CaseChange.toUpperCase(
                              AppLocalization.of(context).transferHeader,
                              context),
                          style: AppStyles.textStyleHeader(context),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          stepGranularity: 0.1,
                        ),
                      ),

                      // A container for the paragraphs
                      Expanded(
                        child: Container(
                          margin: EdgeInsets.only(
                              top: MediaQuery.of(context).size.height * 0.1),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                  margin: EdgeInsets.symmetric(
                                      horizontal:
                                          smallScreen(context) ? 35 : 60),
                                  child: Text(
                                    AppLocalization.of(context)
                                        .transferConfirmInfo
                                        .replaceAll(
                                            '%1', totalAsReadableAmount),
                                    style: AppStyles.textStyleParagraphPrimary(
                                        context),
                                    textAlign: TextAlign.start,
                                  )),
                              Container(
                                  margin: EdgeInsets.symmetric(
                                      horizontal:
                                          smallScreen(context) ? 35 : 60),
                                  child: Text(
                                    AppLocalization.of(context)
                                        .transferConfirmInfoSecond,
                                    style:
                                        AppStyles.textStyleParagraph(context),
                                    textAlign: TextAlign.start,
                                  )),
                              Container(
                                  margin: EdgeInsets.symmetric(
                                      horizontal:
                                          smallScreen(context) ? 35 : 60),
                                  child: Text(
                                    AppLocalization.of(context)
                                        .transferConfirmInfoThird,
                                    style:
                                        AppStyles.textStyleParagraph(context),
                                    textAlign: TextAlign.start,
                                  )),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        child: Column(
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                // Send Button
                                AppButton.buildAppButton(
                                    context,
                                    AppButtonType.PRIMARY,
                                    CaseChange.toUpperCase(
                                        AppLocalization.of(context).confirm,
                                        context),
                                    Dimens.BUTTON_TOP_DIMENS, onPressed: () {
                                  animationOpen = true;
                                  Navigator.of(context).push(
                                      AnimationLoadingOverlay(
                                          AnimationType.TRANSFER_TRANSFERRING,
                                          StateContainer.of(context)
                                              .curTheme
                                              .animationOverlayStrong,
                                          StateContainer.of(context)
                                              .curTheme
                                              .animationOverlayMedium,
                                          onPoppedCallback: () {
                                    animationOpen = false;
                                  }));
                                  startProcessing(context);
                                }),
                              ],
                            ),
                            Row(
                              children: <Widget>[
                                // Scan QR Code Button
                                AppButton.buildAppButton(
                                    context,
                                    AppButtonType.PRIMARY_OUTLINE,
                                    AppLocalization.of(context)
                                        .cancel
                                        .toUpperCase(),
                                    Dimens.BUTTON_BOTTOM_DIMENS, onPressed: () {
                                  Navigator.of(context).pop();
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          });
        });
  }

  void startProcessing(BuildContext context) {
    if (libraAccountStateMap.length > 0) {
      //String account = libraAccountStateMap.keys.first;
      //print('account: $account');
      String address = StateContainer.of(context).wallet.address;
      StateContainer.of(context).updateTnxs(address);
    } else if (readyToSendMap.length > 0) {
      // Start requesting sends
      String account = readyToSendMap.keys.first;
      LibraAccountState libraAccountState = readyToSendMap[account];
      LibraAccount libraAccount = libraAccountMap[account];
      String privKey =
          LibraHelpers.byteToHex(libraAccount.keyPair.getPrivateKey());
      StateContainer.of(context).requestReceive(
          StateContainer.of(context).wallet.address,
          libraAccountState.balance.toString(),
          privKey,
          needRefresh: readyToSendMap.length == 1);
    } else {
      finished = true;
      EventTaxiImpl.singleton()
          .fire(TransferCompleteEvent(amount: totalToTransfer));
      if (animationOpen) {
        Navigator.of(context).pop();
      }
      Navigator.of(context).pop();
    }
  }
}
