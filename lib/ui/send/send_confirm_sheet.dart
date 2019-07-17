import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wallet/appstate_container.dart';
import 'package:wallet/dimens.dart';
import 'package:wallet/styles.dart';
import 'package:wallet/localization.dart';
import 'package:wallet/service_locator.dart';
import 'package:wallet/ui/widgets/buttons.dart';
import 'package:wallet/ui/widgets/dialog.dart';
import 'package:wallet/ui/widgets/sheets.dart';
import 'package:wallet/ui/util/ui_util.dart';
import 'package:wallet/util/numberutil.dart';
import 'package:wallet/util/sharedprefsutil.dart';
import 'package:wallet/util/biometrics.dart';
import 'package:wallet/util/hapticutil.dart';
import 'package:wallet/util/caseconverter.dart';
import 'package:wallet/model/authentication_method.dart';
import 'package:wallet/model/vault.dart';
import 'package:wallet/ui/widgets/security.dart';

class AppSendConfirmSheet {
  String _amount;
  String _amountRaw;
  String _destination;
  String _contactName;
  String _localCurrency;
  bool animationOpen = false;

  AppSendConfirmSheet(String amount, String destinaton,
      {bool maxSend = false, String contactName, String localCurrencyAmount}) {
    _amountRaw = amount;
    // Indicate that this is a special amount if some digits are not displayed
    if (sl
            .get<NumberUtil>()
            .getRawAsUsableString(_amountRaw)
            .replaceAll(',', '') ==
        sl.get<NumberUtil>().getRawAsUsableDecimal(_amountRaw).toString()) {
      _amount = sl.get<NumberUtil>().getRawAsUsableString(_amountRaw);
    } else {
      _amount = sl
              .get<NumberUtil>()
              .truncateDecimal(
                  sl.get<NumberUtil>().getRawAsUsableDecimal(_amountRaw),
                  digits: 6)
              .toStringAsFixed(6) +
          '~';
    }
    _destination = destinaton;
    _contactName = contactName;
    _localCurrency = localCurrencyAmount;
  }

  Future<bool> _onWillPop() async {
    return true;
  }

  mainBottomSheet(BuildContext context) {
    AppSheets.showAppHeightNineSheet(
        context: context,
        onDisposed: _onWillPop,
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            // The main column that holds everything
            return WillPopScope(
              onWillPop: _onWillPop,
              child: SafeArea(
                minimum: EdgeInsets.only(
                    bottom: MediaQuery.of(context).size.height * 0.035),
                child: Column(
                  children: <Widget>[
                    //The main widget that holds the text fields, 'SENDING' and 'TO' texts
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          // 'SENDING' TEXT
                          Container(
                            margin: EdgeInsets.only(bottom: 10.0),
                            child: Column(
                              children: <Widget>[
                                Text(
                                  CaseChange.toUpperCase(
                                      AppLocalization.of(context).sending,
                                      context),
                                  style: AppStyles.textStyleHeader(context),
                                ),
                              ],
                            ),
                          ),
                          // Container for the amount text
                          Container(
                            margin: EdgeInsets.only(
                                left: MediaQuery.of(context).size.width * 0.105,
                                right:
                                    MediaQuery.of(context).size.width * 0.105),
                            padding: EdgeInsets.symmetric(
                                horizontal: 25, vertical: 15),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: StateContainer.of(context)
                                  .curTheme
                                  .backgroundDarkest,
                              borderRadius: BorderRadius.circular(50),
                            ),
                            // Amount text
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                text: '',
                                children: [
                                  TextSpan(
                                    text: '$_amount',
                                    style: TextStyle(
                                      color: StateContainer.of(context)
                                          .curTheme
                                          .primary,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'NunitoSans',
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' LIBRA',
                                    style: TextStyle(
                                      color: StateContainer.of(context)
                                          .curTheme
                                          .primary,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w100,
                                      fontFamily: 'NunitoSans',
                                    ),
                                  ),
                                  TextSpan(
                                    text: _localCurrency != null
                                        ? ' ($_localCurrency)'
                                        : '',
                                    style: TextStyle(
                                      color: StateContainer.of(context)
                                          .curTheme
                                          .primary,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'NunitoSans',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // 'TO' text
                          Container(
                            margin: EdgeInsets.only(top: 30.0, bottom: 10),
                            child: Column(
                              children: <Widget>[
                                Text(
                                  CaseChange.toUpperCase(
                                      AppLocalization.of(context).to, context),
                                  style: AppStyles.textStyleHeader(context),
                                ),
                              ],
                            ),
                          ),
                          // Address text
                          Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 25.0, vertical: 15.0),
                              margin: EdgeInsets.only(
                                  left:
                                      MediaQuery.of(context).size.width * 0.105,
                                  right: MediaQuery.of(context).size.width *
                                      0.105),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: StateContainer.of(context)
                                    .curTheme
                                    .backgroundDarkest,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: sl.get<UIUtil>().threeLineAddressText(
                                  context, _destination,
                                  contactName: _contactName)),
                        ],
                      ),
                    ),

                    //A container for CONFIRM and CANCEL buttons
                    Container(
                      child: Column(
                        children: <Widget>[
                          // A row for CONFIRM Button
                          Row(
                            children: <Widget>[
                              // CONFIRM Button
                              AppButton.buildAppButton(
                                  context,
                                  AppButtonType.PRIMARY,
                                  CaseChange.toUpperCase(
                                      AppLocalization.of(context).confirm,
                                      context),
                                  Dimens.BUTTON_TOP_DIMENS, onPressed: () {
                                // Authenticate
                                sl
                                    .get<SharedPrefsUtil>()
                                    .getAuthMethod()
                                    .then((authMethod) {
                                  sl
                                      .get<BiometricUtil>()
                                      .hasBiometrics()
                                      .then((hasBiometrics) {
                                    if (authMethod.method ==
                                            AuthMethod.BIOMETRICS &&
                                        hasBiometrics) {
                                      sl
                                          .get<BiometricUtil>()
                                          .authenticateWithBiometrics(
                                              context,
                                              AppLocalization.of(context)
                                                  .sendAmountConfirm
                                                  .replaceAll('%1', _amount))
                                          .then((authenticated) {
                                        if (authenticated) {
                                          sl
                                              .get<HapticUtil>()
                                              .fingerprintSucess();
                                          animationOpen = true;
                                          Navigator.of(context).push(
                                              AnimationLoadingOverlay(
                                                  AnimationType.SEND,
                                                  StateContainer.of(context)
                                                      .curTheme
                                                      .animationOverlayStrong,
                                                  StateContainer.of(context)
                                                      .curTheme
                                                      .animationOverlayMedium,
                                                  onPoppedCallback: () =>
                                                      animationOpen = false));
                                          StateContainer.of(context)
                                              .requestSend(
                                                  _destination, _amountRaw);
                                        }
                                      });
                                    } else {
                                      // PIN Authentication
                                      sl
                                          .get<Vault>()
                                          .getPin()
                                          .then((expectedPin) {
                                        Navigator.of(context).push(
                                            MaterialPageRoute(builder:
                                                (BuildContext context) {
                                          return new PinScreen(
                                            PinOverlayType.ENTER_PIN,
                                            (pin) {
                                              Navigator.of(context).pop();
                                              animationOpen = true;
                                              Navigator.of(context).push(
                                                  AnimationLoadingOverlay(
                                                      AnimationType.SEND,
                                                      StateContainer.of(context)
                                                          .curTheme
                                                          .animationOverlayStrong,
                                                      StateContainer.of(context)
                                                          .curTheme
                                                          .animationOverlayMedium,
                                                      onPoppedCallback: () =>
                                                          animationOpen =
                                                              false));
                                              StateContainer.of(context)
                                                  .requestSend(
                                                      _destination, _amountRaw);
                                            },
                                            expectedPin: expectedPin,
                                            description:
                                                AppLocalization.of(context)
                                                    .sendAmountConfirmPin
                                                    .replaceAll('%1', _amount),
                                          );
                                        }));
                                      });
                                    }
                                  });
                                });
                              }),
                            ],
                          ),
                          // A row for CANCEL Button
                          Row(
                            children: <Widget>[
                              // CANCEL Button
                              AppButton.buildAppButton(
                                  context,
                                  AppButtonType.PRIMARY_OUTLINE,
                                  CaseChange.toUpperCase(
                                      AppLocalization.of(context).cancel,
                                      context),
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
            );
          });
        });
  }
}
