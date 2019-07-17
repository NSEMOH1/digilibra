import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:decimal/decimal.dart';
import 'package:barcode_scan/barcode_scan.dart';
import 'package:intl/intl.dart';
import 'package:wallet/appstate_container.dart';
import 'package:wallet/dimens.dart';
import 'package:wallet/localization.dart';
import 'package:wallet/service_locator.dart';
import 'package:wallet/app_icons.dart';
import 'package:wallet/model/address.dart';
import 'package:wallet/model/db/contact.dart';
import 'package:wallet/model/db/appdb.dart';
import 'package:wallet/styles.dart';
import 'package:wallet/ui/send/send_confirm_sheet.dart';
import 'package:wallet/ui/widgets/auto_resize_text.dart';
import 'package:wallet/ui/widgets/buttons.dart';
import 'package:wallet/ui/widgets/sheets.dart';
import 'package:wallet/ui/util/formatters.dart';
import 'package:wallet/ui/util/ui_util.dart';
import 'package:wallet/util/numberutil.dart';
import 'package:wallet/util/caseconverter.dart';

class AppSendSheet {
  FocusNode _sendAddressFocusNode;
  TextEditingController _sendAddressController;
  FocusNode _sendAmountFocusNode;
  TextEditingController _sendAmountController;

  // States
  var _sendAddressStyle;
  var _amountHint;
  var _addressHint;
  var _amountValidationText = '';
  var _addressValidationText = '';
  List<Contact> _contacts;
  // Used to replace address textfield with colorized TextSpan
  bool _addressValidAndUnfocused = false;
  // Set to true when a contact is being entered
  bool _isContact = false;
  // Buttons States (Used because we hide the buttons under certain conditions)
  bool _pasteButtonVisible = true;
  bool _showContactButton = true;
  // Local currency mode/fiat conversion
  bool _localCurrencyMode = false;
  String _lastLocalCurrencyAmount = '';
  String _lastCryptoAmount = '';
  NumberFormat _localCurrencyFormat;

  Contact contact;
  String address;
  String quickSendAmount;

  String _rawAmount;

  AppSendSheet({this.contact, this.address, this.quickSendAmount});

  // A method for deciding if 1 or 3 line address text should be used
  _oneOrthreeLineAddressText(BuildContext context) {
    if (MediaQuery.of(context).size.height < 667)
      return sl.get<UIUtil>().oneLineAddressText(
            context,
            StateContainer.of(context).wallet.address,
            type: OneLineAddressTextType.PRIMARY60,
          );
    else
      return sl.get<UIUtil>().threeLineAddressText(
            context,
            StateContainer.of(context).wallet.address,
            type: ThreeLineAddressTextType.PRIMARY60,
          );
  }

  mainBottomSheet(BuildContext context) {
    _sendAmountFocusNode = new FocusNode();
    _sendAddressFocusNode = new FocusNode();
    _sendAmountController = new TextEditingController();
    _sendAddressController = new TextEditingController();
    _sendAddressStyle = AppStyles.textStyleAddressText60(context);
    if (quickSendAmount != null &&
        StateContainer.of(context).wallet.accountBalance >=
            BigInt.parse(quickSendAmount)) {
      _sendAmountController.text = sl
          .get<NumberUtil>()
          .getRawAsUsableString(quickSendAmount)
          .replaceAll(',', '');
    }
    _contacts = List();
    if (contact != null) {
      // Setup initial state for contact pre-filled
      _sendAddressController.text = contact.name;
      _isContact = true;
      _showContactButton = false;
      _pasteButtonVisible = false;
      _sendAddressStyle = AppStyles.textStyleAddressPrimary(context);
    } else if (address != null) {
      // Setup initial state with prefilled address
      _sendAddressController.text = address;
      _showContactButton = false;
      _pasteButtonVisible = false;
      _sendAddressStyle = AppStyles.textStyleAddressText90(context);
      _addressValidAndUnfocused = true;
    }
    _amountHint = AppLocalization.of(context).enterAmount;
    _addressHint = AppLocalization.of(context).addressHint;
    String locale = StateContainer.of(context).currencyLocale;
    switch (locale) {
      case 'es_VE':
        _localCurrencyFormat =
            NumberFormat.currency(locale: locale, symbol: 'Bs.S');
        break;
      case 'tr_TR':
        _localCurrencyFormat =
            NumberFormat.currency(locale: locale, symbol: '₺');
        break;
      default:
        _localCurrencyFormat = NumberFormat.simpleCurrency(locale: locale);
        break;
    }
    AppSheets.showAppHeightNineSheet(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            // On amount focus change
            _sendAmountFocusNode.addListener(() {
              if (_sendAmountFocusNode.hasFocus) {
                if (_rawAmount != null) {
                  setState(() {
                    _sendAmountController.text = sl
                        .get<NumberUtil>()
                        .getRawAsUsableString(_rawAmount)
                        .replaceAll(',', '');
                    _rawAmount = null;
                  });
                }
                if (quickSendAmount != null) {
                  _sendAmountController.text = '';
                  setState(() {
                    quickSendAmount = null;
                  });
                }
                setState(() {
                  _amountHint = '';
                });
              } else {
                setState(() {
                  _amountHint = AppLocalization.of(context).enterAmount;
                });
              }
            });
            // On address focus change
            _sendAddressFocusNode.addListener(() {
              if (_sendAddressFocusNode.hasFocus) {
                setState(() {
                  _addressHint = '';
                  _addressValidAndUnfocused = false;
                });
                _sendAddressController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _sendAddressController.text.length));
                if (_sendAddressController.text.startsWith('@')) {
                  sl
                      .get<DBHelper>()
                      .getContactsWithNameLike(_sendAddressController.text)
                      .then((contactList) {
                    setState(() {
                      _contacts = contactList;
                    });
                  });
                }
              } else {
                setState(() {
                  _addressHint = AppLocalization.of(context).addressHint;
                  _contacts = [];
                  if (Address(_sendAddressController.text).isValid()) {
                    _addressValidAndUnfocused = true;
                  }
                });
                if (_sendAddressController.text.trim() == '@') {
                  _sendAddressController.text = '';
                  setState(() {
                    _showContactButton = true;
                  });
                }
              }
            });
            // The main column that holds everything
            return SafeArea(
              minimum: EdgeInsets.only(
                  bottom: MediaQuery.of(context).size.height * 0.035),
              child: Column(
                children: <Widget>[
                  // A row for the header of the sheet, balance text and close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      //Empty SizedBox
                      SizedBox(
                        width: 60,
                        height: 60,
                      ),

                      // Container for the header, address and balance text and sheet handle
                      Column(
                        children: <Widget>[
                          // Sheet handle
                          Container(
                            margin: EdgeInsets.only(top: 10),
                            height: 5,
                            width: MediaQuery.of(context).size.width * 0.15,
                            decoration: BoxDecoration(
                              color: StateContainer.of(context).curTheme.text10,
                              borderRadius: BorderRadius.circular(100.0),
                            ),
                          ),
                          Container(
                            margin: EdgeInsets.only(top: 15.0),
                            constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width - 140),
                            child: Column(
                              children: <Widget>[
                                // Header
                                AutoSizeText(
                                  CaseChange.toUpperCase(
                                      AppLocalization.of(context).sendFrom,
                                      context),
                                  style: AppStyles.textStyleHeader(context),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  stepGranularity: 0.1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      //Empty SizedBox
                      SizedBox(
                        width: 60,
                        height: 60,
                      ),
                    ],
                  ),
                  // Address Text
                  Container(
                    margin: EdgeInsets.only(top: 10.0, left: 30, right: 30),
                    child: _oneOrthreeLineAddressText(context),
                  ),
                  // A main container that holds everything
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(top: 5, bottom: 5),
                      child: Stack(
                        children: <Widget>[
                          GestureDetector(
                            onTap: () {
                              // Clear focus of our fields when tapped in this empty space
                              _sendAddressFocusNode.unfocus();
                              _sendAmountFocusNode.unfocus();
                            },
                            child: Container(
                              color: Colors.transparent,
                              child: SizedBox.expand(),
                              constraints: BoxConstraints.expand(),
                            ),
                          ),
                          // A column for Enter Amount, Enter Address, Error containers and the pop up list
                          Column(
                            children: <Widget>[
                              Stack(
                                children: <Widget>[
                                  // Column for Balance Text, Enter Amount container + Enter Amount Error container
                                  Column(
                                    children: <Widget>[
                                      // Balance Text
                                      Container(
                                        child: RichText(
                                          textAlign: TextAlign.start,
                                          text: TextSpan(
                                            text: '',
                                            children: [
                                              TextSpan(
                                                text: '(',
                                                style: TextStyle(
                                                  color:
                                                      StateContainer.of(context)
                                                          .curTheme
                                                          .primary60,
                                                  fontSize: 14.0,
                                                  fontWeight: FontWeight.w100,
                                                  fontFamily: 'NunitoSans',
                                                ),
                                              ),
                                              TextSpan(
                                                text: _localCurrencyMode
                                                    ? StateContainer.of(context)
                                                        .wallet
                                                        .getLocalCurrencyPrice(
                                                            locale: StateContainer
                                                                    .of(context)
                                                                .currencyLocale)
                                                    : StateContainer.of(context)
                                                        .wallet
                                                        .getAccountBalanceDisplay(),
                                                style: TextStyle(
                                                  color:
                                                      StateContainer.of(context)
                                                          .curTheme
                                                          .primary60,
                                                  fontSize: 14.0,
                                                  fontWeight: FontWeight.w700,
                                                  fontFamily: 'NunitoSans',
                                                ),
                                              ),
                                              TextSpan(
                                                text: _localCurrencyMode
                                                    ? ')'
                                                    : ' LIBRA)',
                                                style: TextStyle(
                                                  color:
                                                      StateContainer.of(context)
                                                          .curTheme
                                                          .primary60,
                                                  fontSize: 14.0,
                                                  fontWeight: FontWeight.w100,
                                                  fontFamily: 'NunitoSans',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // ******* Enter Amount Container ******* //
                                      getEnterAmountContainer(
                                          context, setState),
                                      // ******* Enter Amount Container End ******* //

                                      // ******* Enter Amount Error Container ******* //
                                      Container(
                                        alignment: AlignmentDirectional(0, 0),
                                        margin: EdgeInsets.only(top: 3),
                                        child: Text(_amountValidationText,
                                            style: TextStyle(
                                              fontSize: 14.0,
                                              color: StateContainer.of(context)
                                                  .curTheme
                                                  .primary,
                                              fontFamily: 'NunitoSans',
                                              fontWeight: FontWeight.w600,
                                            )),
                                      ),
                                      // ******* Enter Amount Error Container End ******* //
                                    ],
                                  ),

                                  // Column for Enter Address container + Enter Address Error container
                                  Column(
                                    children: <Widget>[
                                      Container(
                                        alignment: Alignment.bottomCenter,
                                        child: Stack(
                                          alignment: Alignment.bottomCenter,
                                          children: <Widget>[
                                            Container(
                                              margin: EdgeInsets.only(
                                                  left: MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      0.105,
                                                  right: MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      0.105),
                                              alignment: Alignment.bottomCenter,
                                              constraints: BoxConstraints(
                                                  maxHeight: 174, minHeight: 0),
                                              // ********************************************* //
                                              // ********* The pop-up Contacts List ********* //
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(25),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            25),
                                                    color: StateContainer.of(
                                                            context)
                                                        .curTheme
                                                        .backgroundDarkest,
                                                  ),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              25),
                                                    ),
                                                    margin: EdgeInsets.only(
                                                        bottom: 50),
                                                    child: ListView.builder(
                                                      shrinkWrap: true,
                                                      padding: EdgeInsets.only(
                                                          bottom: 0, top: 0),
                                                      itemCount:
                                                          _contacts.length,
                                                      itemBuilder:
                                                          (context, index) {
                                                        return _buildContactItem(
                                                            context,
                                                            setState,
                                                            _contacts[index]);
                                                      },
                                                    ), // ********* The pop-up Contacts List End ********* //
                                                    // ************************************************** //
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // ******* Enter Address Container ******* //
                                            getEnterAddressContainer(
                                                context, setState),
                                            // ******* Enter Address Container End ******* //
                                          ],
                                        ),
                                      ),

                                      // ******* Enter Address Error Container ******* //
                                      Container(
                                        alignment: AlignmentDirectional(0, 0),
                                        margin: EdgeInsets.only(top: 3),
                                        child: Text(_addressValidationText,
                                            style: TextStyle(
                                              fontSize: 14.0,
                                              color: StateContainer.of(context)
                                                  .curTheme
                                                  .primary,
                                              fontFamily: 'NunitoSans',
                                              fontWeight: FontWeight.w600,
                                            )),
                                      ),
                                      // ******* Enter Address Error Container End ******* //
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  //A column with 'Scan QR Code' and 'Send' buttons
                  Container(
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            // Send Button
                            AppButton.buildAppButton(
                                context,
                                AppButtonType.PRIMARY,
                                AppLocalization.of(context).send,
                                Dimens.BUTTON_TOP_DIMENS, onPressed: () {
                              bool validRequest =
                                  _validateRequest(context, setState);
                              if (_sendAddressController.text.startsWith('@') &&
                                  validRequest) {
                                // Need to make sure its a valid contact
                                sl
                                    .get<DBHelper>()
                                    .getContactWithName(
                                        _sendAddressController.text)
                                    .then((contact) {
                                  if (contact == null) {
                                    setState(() {
                                      _addressValidationText =
                                          AppLocalization.of(context)
                                              .contactInvalid;
                                    });
                                  } else {
                                    AppSendConfirmSheet(
                                            _localCurrencyMode
                                                ? sl
                                                    .get<NumberUtil>()
                                                    .getAmountAsRaw(
                                                        _convertLocalCurrencyToCrypto(
                                                            context))
                                                : _rawAmount == null
                                                    ? sl
                                                        .get<NumberUtil>()
                                                        .getAmountAsRaw(
                                                            _sendAmountController
                                                                .text)
                                                    : _rawAmount,
                                            contact.address,
                                            contactName: contact.name,
                                            maxSend: _isMaxSend(context),
                                            localCurrencyAmount:
                                                _localCurrencyMode
                                                    ? _sendAmountController.text
                                                    : null)
                                        .mainBottomSheet(context);
                                  }
                                });
                              } else if (validRequest) {
                                AppSendConfirmSheet(
                                        _localCurrencyMode
                                            ? sl.get<NumberUtil>().getAmountAsRaw(
                                                _convertLocalCurrencyToCrypto(
                                                    context))
                                            : _rawAmount == null
                                                ? sl
                                                    .get<NumberUtil>()
                                                    .getAmountAsRaw(
                                                        _sendAmountController
                                                            .text)
                                                : _rawAmount,
                                        _sendAddressController.text,
                                        maxSend: _isMaxSend(context),
                                        localCurrencyAmount: _localCurrencyMode
                                            ? _sendAmountController.text
                                            : null)
                                    .mainBottomSheet(context);
                              }
                            }),
                          ],
                        ),
                        Row(
                          children: <Widget>[
                            // Scan QR Code Button
                            AppButton.buildAppButton(
                                context,
                                AppButtonType.PRIMARY_OUTLINE,
                                AppLocalization.of(context).scanQrCode,
                                Dimens.BUTTON_BOTTOM_DIMENS, onPressed: () {
                              try {
                                sl.get<UIUtil>().cancelLockEvent();
                                BarcodeScanner.scan(StateContainer.of(context)
                                        .curTheme
                                        .qrScanTheme)
                                    .then((value) {
                                  Address address = Address(value);
                                  if (!address.isValid()) {
                                    sl.get<UIUtil>().showSnackbar(
                                        AppLocalization.of(context)
                                            .qrInvalidAddress,
                                        context);
                                  } else {
                                    sl
                                        .get<DBHelper>()
                                        .getContactWithAddress(address.address)
                                        .then((contact) {
                                      if (contact == null) {
                                        setState(() {
                                          _isContact = false;
                                          _addressValidationText = '';
                                          _sendAddressStyle =
                                              AppStyles.textStyleAddressText90(
                                                  context);
                                          _pasteButtonVisible = false;
                                          _showContactButton = false;
                                        });
                                        _sendAddressController.text =
                                            address.address;
                                        _sendAddressFocusNode.unfocus();
                                        setState(() {
                                          _addressValidAndUnfocused = true;
                                        });
                                      } else {
                                        // Is a contact
                                        setState(() {
                                          _isContact = true;
                                          _addressValidationText = '';
                                          _sendAddressStyle =
                                              AppStyles.textStyleAddressPrimary(
                                                  context);
                                          _pasteButtonVisible = false;
                                          _showContactButton = false;
                                        });
                                        _sendAddressController.text =
                                            contact.name;
                                      }
                                      // Fill amount
                                      if (address.amount != null) {
                                        if (_localCurrencyMode) {
                                          toggleLocalCurrency(
                                              context, setState);
                                          _sendAmountController.text = sl
                                              .get<NumberUtil>()
                                              .getRawAsUsableString(
                                                  address.amount);
                                        } else {
                                          setState(() {
                                            _rawAmount = address.amount;
                                            // Indicate that this is a special amount if some digits are not displayed
                                            if (sl
                                                    .get<NumberUtil>()
                                                    .getRawAsUsableString(
                                                        _rawAmount)
                                                    .replaceAll(',', '') ==
                                                sl
                                                    .get<NumberUtil>()
                                                    .getRawAsUsableDecimal(
                                                        _rawAmount)
                                                    .toString()) {
                                              _sendAmountController.text = sl
                                                  .get<NumberUtil>()
                                                  .getRawAsUsableString(
                                                      _rawAmount)
                                                  .replaceAll(',', '');
                                            } else {
                                              _sendAmountController.text = sl
                                                      .get<NumberUtil>()
                                                      .truncateDecimal(
                                                          sl
                                                              .get<NumberUtil>()
                                                              .getRawAsUsableDecimal(
                                                                  address
                                                                      .amount),
                                                          digits: 6)
                                                      .toStringAsFixed(6) +
                                                  '~';
                                            }
                                          });
                                        }
                                      }
                                    });
                                    _sendAddressFocusNode.unfocus();
                                  }
                                });
                              } catch (e) {
                                if (e.code ==
                                    BarcodeScanner.CameraAccessDenied) {
                                  // TODO - Permission Denied to use camera
                                } else {
                                  // UNKNOWN ERROR
                                }
                              }
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          });
        });
  }

  String _convertLocalCurrencyToCrypto(BuildContext context) {
    String convertedAmt = _sendAmountController.text.replaceAll(',', '.');
    convertedAmt = sl.get<NumberUtil>().sanitizeNumber(convertedAmt);
    if (convertedAmt.isEmpty) {
      return '';
    }
    Decimal valueLocal = Decimal.parse(convertedAmt);
    Decimal conversion = Decimal.parse(
        StateContainer.of(context).wallet.localCurrencyConversion);
    return sl
        .get<NumberUtil>()
        .truncateDecimal(valueLocal / conversion)
        .toString();
  }

  String _convertCryptoToLocalCurrency(BuildContext context) {
    String convertedAmt =
        sl.get<NumberUtil>().sanitizeNumber(_sendAmountController.text);
    if (convertedAmt.isEmpty) {
      return '';
    }
    Decimal valueCrypto = Decimal.parse(convertedAmt);
    Decimal conversion = Decimal.parse(
        StateContainer.of(context).wallet.localCurrencyConversion);
    convertedAmt = sl
        .get<NumberUtil>()
        .truncateDecimal(valueCrypto * conversion)
        .toString();
    convertedAmt =
        convertedAmt.replaceAll('.', _localCurrencyFormat.symbols.DECIMAL_SEP);
    convertedAmt = _localCurrencyFormat.currencySymbol + convertedAmt;
    return convertedAmt;
  }

  // Determine if this is a max send or not by comparing balances
  bool _isMaxSend(BuildContext context) {
    // Sanitize commas
    if (_sendAmountController.text.isEmpty) {
      return false;
    }
    try {
      String textField = _sendAmountController.text;
      String balance;
      if (_localCurrencyMode) {
        balance = StateContainer.of(context).wallet.getLocalCurrencyPrice(
            locale: StateContainer.of(context).currencyLocale);
      } else {
        balance = StateContainer.of(context)
            .wallet
            .getAccountBalanceDisplay()
            .replaceAll(r',', '');
      }
      // Convert to Integer representations
      int textFieldInt;
      int balanceInt;
      if (_localCurrencyMode) {
        // Sanitize currency values into plain integer representations
        textField = textField.replaceAll(',', '.');
        String sanitizedTextField =
            sl.get<NumberUtil>().sanitizeNumber(textField);
        balance =
            balance.replaceAll(_localCurrencyFormat.symbols.GROUP_SEP, '');
        balance = balance.replaceAll(',', '.');
        String sanitizedBalance = sl.get<NumberUtil>().sanitizeNumber(balance);
        textFieldInt =
            (Decimal.parse(sanitizedTextField) * Decimal.fromInt(100)).toInt();
        balanceInt =
            (Decimal.parse(sanitizedBalance) * Decimal.fromInt(100)).toInt();
      } else {
        textField = textField.replaceAll(',', '');
        textFieldInt =
            (Decimal.parse(textField) * Decimal.fromInt(100)).toInt();
        balanceInt = (Decimal.parse(balance) * Decimal.fromInt(100)).toInt();
      }
      return textFieldInt == balanceInt;
    } catch (e) {
      return false;
    }
  }

  void toggleLocalCurrency(BuildContext context, StateSetter setState) {
    // Keep a cache of previous amounts because, it's kinda nice to see approx what libra is worth
    // this way you can tap button and tap back and not end up with X.9993451 LIBRA
    if (_localCurrencyMode) {
      // Switching to crypto-mode
      String cryptoAmountStr;
      // Check out previous state
      if (_sendAmountController.text == _lastLocalCurrencyAmount) {
        cryptoAmountStr = _lastCryptoAmount;
      } else {
        _lastLocalCurrencyAmount = _sendAmountController.text;
        _lastCryptoAmount = _convertLocalCurrencyToCrypto(context);
        cryptoAmountStr = _lastCryptoAmount;
      }
      setState(() {
        _localCurrencyMode = false;
      });
      Future.delayed(Duration(milliseconds: 50), () {
        _sendAmountController.text = cryptoAmountStr;
        _sendAmountController.selection = TextSelection.fromPosition(
            TextPosition(offset: cryptoAmountStr.length));
      });
    } else {
      // Switching to local-currency mode
      String localAmountStr;
      // Check our previous state
      if (_sendAmountController.text == _lastCryptoAmount) {
        localAmountStr = _lastLocalCurrencyAmount;
      } else {
        _lastCryptoAmount = _sendAmountController.text;
        _lastLocalCurrencyAmount = _convertCryptoToLocalCurrency(context);
        localAmountStr = _lastLocalCurrencyAmount;
      }
      setState(() {
        _localCurrencyMode = true;
      });
      Future.delayed(Duration(milliseconds: 50), () {
        _sendAmountController.text = localAmountStr;
        _sendAmountController.selection = TextSelection.fromPosition(
            TextPosition(offset: localAmountStr.length));
      });
    }
  }

  // Build contact items for the list
  Widget _buildContactItem(
      BuildContext context, StateSetter setState, Contact contact) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          height: 42,
          width: double.infinity - 5,
          child: FlatButton(
            onPressed: () {
              _sendAddressController.text = contact.name;
              _sendAddressFocusNode.unfocus();
              setState(() {
                _isContact = true;
                _showContactButton = false;
                _pasteButtonVisible = false;
                _sendAddressStyle = AppStyles.textStyleAddressPrimary(context);
              });
            },
            child: Text(contact.name,
                textAlign: TextAlign.center,
                style: AppStyles.textStyleAddressPrimary(context)),
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 25),
          height: 1,
          color: StateContainer.of(context).curTheme.text03,
        ),
      ],
    );
  }

  /// Validate form data to see if valid
  /// @returns true if valid, false otherwise
  bool _validateRequest(BuildContext context, StateSetter setState) {
    bool isValid = true;
    _sendAmountFocusNode.unfocus();
    _sendAddressFocusNode.unfocus();
    // Validate amount
    if (_sendAmountController.text.trim().isEmpty) {
      isValid = false;
      setState(() {
        _amountValidationText = AppLocalization.of(context).amountMissing;
      });
    } else {
      String libraAmount = _localCurrencyMode
          ? _convertLocalCurrencyToCrypto(context)
          : _rawAmount == null
              ? _sendAmountController.text
              : sl.get<NumberUtil>().getRawAsUsableString(_rawAmount);
      BigInt balanceRaw = StateContainer.of(context).wallet.accountBalance;
      BigInt sendAmount =
          BigInt.tryParse(sl.get<NumberUtil>().getAmountAsRaw(libraAmount));
      if (sendAmount == null || sendAmount == BigInt.zero) {
        isValid = false;
        setState(() {
          _amountValidationText = AppLocalization.of(context).amountMissing;
        });
      } else if (sendAmount > balanceRaw) {
        isValid = false;
        setState(() {
          _amountValidationText =
              AppLocalization.of(context).insufficientBalance;
        });
      }
    }
    // Validate address
    bool isContact = _sendAddressController.text.startsWith('@');
    if (_sendAddressController.text.trim().isEmpty) {
      isValid = false;
      setState(() {
        _addressValidationText = AppLocalization.of(context).addressMising;
        _pasteButtonVisible = true;
      });
    } else if (!isContact && !Address(_sendAddressController.text).isValid()) {
      isValid = false;
      setState(() {
        _addressValidationText = AppLocalization.of(context).invalidAddress;
        _pasteButtonVisible = true;
      });
    } else if (!isContact) {
      setState(() {
        _addressValidationText = '';
        _pasteButtonVisible = false;
      });
      _sendAddressFocusNode.unfocus();
    }
    return isValid;
  }

  //************ Enter Amount Container Method ************//
  //*******************************************************//
  getEnterAmountContainer(BuildContext context, StateSetter setState) {
    return Container(
      margin: EdgeInsets.only(
        left: MediaQuery.of(context).size.width * 0.105,
        right: MediaQuery.of(context).size.width * 0.105,
        top: 30,
      ),
      width: double.infinity,
      decoration: BoxDecoration(
        color: StateContainer.of(context).curTheme.backgroundDarkest,
        borderRadius: BorderRadius.circular(25),
      ),
      // Amount Text Field
      child: TextField(
        focusNode: _sendAmountFocusNode,
        controller: _sendAmountController,
        cursorColor: StateContainer.of(context).curTheme.primary,
        inputFormatters: _rawAmount == null
            ? [
                LengthLimitingTextInputFormatter(13),
                _localCurrencyMode
                    ? CurrencyFormatter(
                        decimalSeparator:
                            _localCurrencyFormat.symbols.DECIMAL_SEP,
                        commaSeparator: _localCurrencyFormat.symbols.GROUP_SEP)
                    : CurrencyFormatter(),
                LocalCurrencyFormatter(
                    active: _localCurrencyMode,
                    currencyFormat: _localCurrencyFormat)
              ]
            : [LengthLimitingTextInputFormatter(13)],
        onChanged: (text) {
          // Always reset the error message to be less annoying
          setState(() {
            _amountValidationText = '';
            // Reset the raw amount
            _rawAmount = null;
          });
        },
        textInputAction: TextInputAction.next,
        maxLines: null,
        autocorrect: false,
        decoration: InputDecoration(
          hintText: _amountHint,
          border: InputBorder.none,
          hintStyle: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w100,
            fontFamily: 'NunitoSans',
            color: StateContainer.of(context).curTheme.text60,
          ),
          // Currency Switch Button - TODO
          prefixIcon: Container(
            width: 48,
            height: 48,
            child: _rawAmount == null
                ? FlatButton(
                    padding: EdgeInsets.all(14.0),
                    highlightColor:
                        StateContainer.of(context).curTheme.primary15,
                    splashColor: StateContainer.of(context).curTheme.primary30,
                    onPressed: () {
                      toggleLocalCurrency(context, setState);
                    },
                    child: Icon(AppIcons.swapcurrency,
                        size: 20,
                        color: StateContainer.of(context).curTheme.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(200.0)),
                  )
                : SizedBox(),
          ), // MAX Button
          suffixIcon: AnimatedCrossFade(
            duration: Duration(milliseconds: 100),
            firstChild: Container(
              width: 48,
              height: 48,
              child: FlatButton(
                highlightColor: StateContainer.of(context).curTheme.primary15,
                splashColor: StateContainer.of(context).curTheme.primary30,
                padding: EdgeInsets.all(12.0),
                onPressed: () {
                  if (_isMaxSend(context)) {
                    return;
                  }
                  if (!_localCurrencyMode) {
                    _sendAmountController.text = StateContainer.of(context)
                        .wallet
                        .getAccountBalanceDisplay()
                        .replaceAll(r',', '');
                    _sendAddressController.selection =
                        TextSelection.fromPosition(TextPosition(
                            offset: _sendAddressController.text.length));
                  } else {
                    String localAmount = StateContainer.of(context)
                        .wallet
                        .getLocalCurrencyPrice(
                            locale: StateContainer.of(context).currencyLocale);
                    localAmount = localAmount.replaceAll(
                        _localCurrencyFormat.symbols.GROUP_SEP, '');
                    localAmount = localAmount.replaceAll(
                        _localCurrencyFormat.symbols.DECIMAL_SEP, '.');
                    localAmount = sl
                        .get<NumberUtil>()
                        .sanitizeNumber(localAmount)
                        .replaceAll(
                            '.', _localCurrencyFormat.symbols.DECIMAL_SEP);
                    _sendAmountController.text =
                        _localCurrencyFormat.currencySymbol + localAmount;
                    _sendAddressController.selection =
                        TextSelection.fromPosition(TextPosition(
                            offset: _sendAddressController.text.length));
                  }
                },
                child: Icon(AppIcons.max,
                    size: 24,
                    color: StateContainer.of(context).curTheme.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(200.0)),
              ),
            ),
            secondChild: SizedBox(),
            crossFadeState: _isMaxSend(context)
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
          ),
        ),
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16.0,
          color: StateContainer.of(context).curTheme.primary,
          fontFamily: 'NunitoSans',
        ),
        onSubmitted: (text) {
          if (!Address(_sendAddressController.text).isValid()) {
            FocusScope.of(context).requestFocus(_sendAddressFocusNode);
          }
        },
      ),
    );
  } //************ Enter Address Container Method End ************//
  //*************************************************************//

  //************ Enter Address Container Method ************//
  //*******************************************************//
  getEnterAddressContainer(BuildContext context, StateSetter setState) {
    return Container(
      margin: EdgeInsets.only(
        left: MediaQuery.of(context).size.width * 0.105,
        right: MediaQuery.of(context).size.width * 0.105,
        top: 124,
      ),
      padding: _addressValidAndUnfocused
          ? EdgeInsets.symmetric(horizontal: 25.0, vertical: 15.0)
          : EdgeInsets.zero,
      width: double.infinity,
      decoration: BoxDecoration(
        color: StateContainer.of(context).curTheme.backgroundDarkest,
        borderRadius: BorderRadius.circular(25),
      ),
      // Enter Address Text field
      child: !_addressValidAndUnfocused
          ? TextField(
              textAlign:
                  _isContact && false ? TextAlign.start : TextAlign.center,
              focusNode: _sendAddressFocusNode,
              controller: _sendAddressController,
              cursorColor: StateContainer.of(context).curTheme.primary,
              keyboardAppearance: Brightness.dark,
              inputFormatters: [
                _isContact
                    ? LengthLimitingTextInputFormatter(20)
                    : LengthLimitingTextInputFormatter(64),
              ],
              textInputAction: TextInputAction.done,
              maxLines: null,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: _addressHint,
                border: InputBorder.none,
                hintStyle: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w100,
                  fontFamily: 'NunitoSans',
                  color: StateContainer.of(context).curTheme.text60,
                ),
                // @ Button
                prefixIcon: AnimatedCrossFade(
                  duration: Duration(milliseconds: 100),
                  firstChild: Container(
                    width: 48.0,
                    height: 48.0,
                    child: FlatButton(
                      highlightColor:
                          StateContainer.of(context).curTheme.primary15,
                      splashColor:
                          StateContainer.of(context).curTheme.primary30,
                      padding: EdgeInsets.all(14.0),
                      onPressed: () {
                        if (_showContactButton && _contacts.length == 0) {
                          // Show menu
                          FocusScope.of(context)
                              .requestFocus(_sendAddressFocusNode);
                          if (_sendAddressController.text.length == 0) {
                            _sendAddressController.text = '@';
                            _sendAddressController.selection =
                                TextSelection.fromPosition(TextPosition(
                                    offset:
                                        _sendAddressController.text.length));
                          }
                          sl.get<DBHelper>().getContacts().then((contactList) {
                            setState(() {
                              _contacts = contactList;
                            });
                          });
                        }
                      },
                      child: Icon(AppIcons.at,
                          size: 20,
                          color: StateContainer.of(context).curTheme.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(200.0)),
                    ),
                  ),
                  secondChild: SizedBox(),
                  crossFadeState: _showContactButton && _contacts.length == 0
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                ),
                // Paste Button
                suffixIcon: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 100),
                  firstChild: Container(
                    width: 48.0,
                    height: 48.0,
                    child: FlatButton(
                      highlightColor:
                          StateContainer.of(context).curTheme.primary15,
                      splashColor:
                          StateContainer.of(context).curTheme.primary30,
                      padding: EdgeInsets.all(14.0),
                      onPressed: () {
                        if (!_pasteButtonVisible) {
                          return;
                        }
                        Clipboard.getData('text/plain')
                            .then((ClipboardData data) {
                          if (data == null || data.text == null) {
                            return;
                          }
                          Address address = new Address(data.text);
                          if (address.isValid()) {
                            sl
                                .get<DBHelper>()
                                .getContactWithAddress(address.address)
                                .then((contact) {
                              if (contact == null) {
                                setState(() {
                                  _isContact = false;
                                  _addressValidationText = '';
                                  _sendAddressStyle =
                                      AppStyles.textStyleAddressText90(context);
                                  _pasteButtonVisible = false;
                                  _showContactButton = false;
                                });
                                _sendAddressController.text = address.address;
                                _sendAddressFocusNode.unfocus();
                                setState(() {
                                  _addressValidAndUnfocused = true;
                                });
                              } else {
                                // Is a contact
                                setState(() {
                                  _isContact = true;
                                  _addressValidationText = '';
                                  _sendAddressStyle =
                                      AppStyles.textStyleAddressPrimary(
                                          context);
                                  _pasteButtonVisible = false;
                                  _showContactButton = false;
                                });
                                _sendAddressController.text = contact.name;
                              }
                            });
                          }
                        });
                      },
                      child: Icon(AppIcons.paste,
                          size: 20,
                          color: StateContainer.of(context).curTheme.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(200.0)),
                    ),
                  ),
                  secondChild: SizedBox(),
                  crossFadeState: _pasteButtonVisible
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                ),
              ),
              style: _sendAddressStyle,
              onChanged: (text) {
                if (text.length > 0) {
                  setState(() {
                    _showContactButton = false;
                  });
                } else {
                  setState(() {
                    _showContactButton = true;
                  });
                }
                bool isContact = text.startsWith('@');
                // Switch to contact mode if starts with @
                if (isContact) {
                  setState(() {
                    _isContact = true;
                  });
                  sl
                      .get<DBHelper>()
                      .getContactsWithNameLike(text)
                      .then((matchedList) {
                    setState(() {
                      _contacts = matchedList;
                    });
                  });
                } else {
                  setState(() {
                    _isContact = false;
                    _contacts = [];
                  });
                }
                // Always reset the error message to be less annoying
                setState(() {
                  _addressValidationText = '';
                });
                if (!isContact && Address(text).isValid()) {
                  _sendAddressFocusNode.unfocus();
                  setState(() {
                    _sendAddressStyle =
                        AppStyles.textStyleAddressText90(context);
                    _addressValidationText = '';
                    _pasteButtonVisible = false;
                  });
                } else if (!isContact) {
                  setState(() {
                    _sendAddressStyle =
                        AppStyles.textStyleAddressText60(context);
                    _pasteButtonVisible = true;
                  });
                } else {
                  sl.get<DBHelper>().getContactWithName(text).then((contact) {
                    if (contact == null) {
                      setState(() {
                        _sendAddressStyle =
                            AppStyles.textStyleAddressText60(context);
                      });
                    } else {
                      setState(() {
                        _pasteButtonVisible = false;
                        _sendAddressStyle =
                            AppStyles.textStyleAddressPrimary(context);
                      });
                    }
                  });
                }
              },
            )
          : GestureDetector(
              onTap: () {
                setState(() {
                  _addressValidAndUnfocused = false;
                });
                Future.delayed(Duration(milliseconds: 50), () {
                  FocusScope.of(context).requestFocus(_sendAddressFocusNode);
                });
              },
              child: sl
                  .get<UIUtil>()
                  .threeLineAddressText(context, _sendAddressController.text),
            ),
    );
  } //************ Enter Address Container Method End ************//
  //*************************************************************//
}
