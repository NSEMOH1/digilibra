import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wallet/appstate_container.dart';
import 'package:event_taxi/event_taxi.dart';
import 'package:wallet/dimens.dart';
import 'package:wallet/app_icons.dart';
import 'package:wallet/styles.dart';
import 'package:wallet/service_locator.dart';
import 'package:wallet/localization.dart';
import 'package:wallet/bus/events.dart';
import 'package:wallet/model/db/account.dart';
import 'package:wallet/model/db/appdb.dart';
import 'package:wallet/ui/util/ui_util.dart';
import 'package:wallet/ui/widgets/auto_resize_text.dart';
import 'package:wallet/ui/widgets/buttons.dart';
import 'package:wallet/ui/widgets/dialog.dart';
import 'package:wallet/ui/widgets/sheets.dart';
import 'package:wallet/util/caseconverter.dart';
import 'package:wallet/util/numberutil.dart';

// Account Details Sheet
class AccountDetailsSheet {
  Account account;
  String originalName;
  TextEditingController _nameController;
  FocusNode _nameFocusNode;
  bool deleted;
  // Address copied or not
  bool _addressCopied;
  // Timer reference so we can cancel repeated events
  Timer _addressCopiedTimer;

  AccountDetailsSheet(this.account) {
    this.originalName = account.name;
    this.deleted = false;
  }

  Future<bool> _onWillPop() async {
    // Update name if changed and valid
    if (originalName != _nameController.text &&
        _nameController.text.trim().length > 0 &&
        !deleted) {
      sl.get<DBHelper>().changeAccountName(account, _nameController.text);
      account.name = _nameController.text;
      EventTaxiImpl.singleton().fire(AccountModifiedEvent(account: account));
    }
    return true;
  }

  mainBottomSheet(BuildContext context) {
    _addressCopied = false;
    _nameController = TextEditingController(text: account.name);
    _nameFocusNode = FocusNode();
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
                        bottom: MediaQuery.of(context).size.height * 0.035),
                    child: Column(
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            // Trashcan Button
                            Container(
                                width: 50,
                                height: 50,
                                margin: EdgeInsetsDirectional.only(
                                    top: 10.0, start: 10.0),
                                child: account.index == 0
                                    ? SizedBox()
                                    : FlatButton(
                                        highlightColor:
                                            StateContainer.of(context)
                                                .curTheme
                                                .text15,
                                        splashColor: StateContainer.of(context)
                                            .curTheme
                                            .text15,
                                        onPressed: () {
                                          AppDialogs.showConfirmDialog(
                                              context,
                                              AppLocalization.of(context)
                                                  .hideAccountHeader,
                                              AppLocalization.of(context)
                                                  .removeAccountText
                                                  .replaceAll(
                                                      '%1',
                                                      AppLocalization.of(
                                                              context)
                                                          .addAccount),
                                              CaseChange.toUpperCase(
                                                  AppLocalization.of(context)
                                                      .yes,
                                                  context), () {
                                            // Remove account
                                            deleted = true;
                                            sl
                                                .get<DBHelper>()
                                                .deleteAccount(account)
                                                .then((id) {
                                              EventTaxiImpl.singleton().fire(
                                                  AccountModifiedEvent(
                                                      account: account,
                                                      deleted: true));
                                              Navigator.of(context).pop();
                                            });
                                          },
                                              cancelText:
                                                  CaseChange.toUpperCase(
                                                      AppLocalization.of(
                                                              context)
                                                          .no,
                                                      context));
                                        },
                                        child: Icon(AppIcons.trashcan,
                                            size: 24,
                                            color: StateContainer.of(context)
                                                .curTheme
                                                .text),
                                        padding: EdgeInsets.all(13.0),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(100.0)),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.padded,
                                      )),
                            // The header of the sheet
                            Container(
                              margin: EdgeInsets.only(top: 25.0),
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width - 140),
                              child: Column(
                                children: <Widget>[
                                  AutoSizeText(
                                    CaseChange.toUpperCase(
                                        AppLocalization.of(context).account,
                                        context),
                                    style: AppStyles.textStyleHeader(context),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    stepGranularity: 0.1,
                                  ),
                                ],
                              ),
                            ),
                            // Search Button
                            SizedBox(height: 50, width: 50),
                          ],
                        ),
                        // Address Text
                        Container(
                          margin: EdgeInsets.only(top: 10.0),
                          child: account.address != null
                              ? sl.get<UIUtil>().threeLineAddressText(
                                  context, account.address,
                                  type: ThreeLineAddressTextType.PRIMARY60)
                              : account.selected
                                  ? sl.get<UIUtil>().threeLineAddressText(
                                      context,
                                      StateContainer.of(context).wallet.address,
                                      type: ThreeLineAddressTextType.PRIMARY60)
                                  : SizedBox(),
                        ),
                        // Balance Text
                        (account.balance != null || account.selected)
                            ? Container(
                                margin: EdgeInsets.only(top: 5.0),
                                child: RichText(
                                  textAlign: TextAlign.start,
                                  text: TextSpan(
                                    text: '',
                                    children: [
                                      TextSpan(
                                          text: '(',
                                          style: AppStyles
                                              .textStyleCurrencyPrimary60(
                                                  context)),
                                      TextSpan(
                                        text: sl
                                            .get<NumberUtil>()
                                            .getRawAsUsableString(
                                                account.balance == null
                                                    ? StateContainer.of(context)
                                                        .wallet
                                                        .accountBalance
                                                        .toString()
                                                    : account.balance),
                                        style: AppStyles
                                            .textStyleCurrencyPrimary60(context,
                                                fontWeight: FontWeight.w700),
                                      ),
                                      TextSpan(
                                          text: ' LIBRA)',
                                          style: AppStyles
                                              .textStyleCurrencyPrimary60(
                                                  context)),
                                    ],
                                  ),
                                ),
                              )
                            : SizedBox(),

                        // The main container that holds Contact Name and Contact Address
                        Expanded(
                            child: Stack(children: <Widget>[
                          GestureDetector(
                            onTap: () {
                              // Clear focus of our fields when tapped in this empty space
                              _nameFocusNode.unfocus();
                            },
                            child: Container(
                              color: Colors.transparent,
                              child: SizedBox.expand(),
                              constraints: BoxConstraints.expand(),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            margin: EdgeInsets.only(
                              top: MediaQuery.of(context).size.width * 0.14,
                              left: MediaQuery.of(context).size.width * 0.105,
                              right: MediaQuery.of(context).size.width * 0.105,
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 30),
                            decoration: BoxDecoration(
                              color: StateContainer.of(context)
                                  .curTheme
                                  .backgroundDarkest,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: TextField(
                              controller: _nameController,
                              focusNode: _nameFocusNode,
                              textAlign: TextAlign.center,
                              cursorColor:
                                  StateContainer.of(context).curTheme.primary,
                              textInputAction: TextInputAction.done,
                              autocorrect: false,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                  fontSize: AppFontSizes.medium,
                                  fontWeight: FontWeight.w100,
                                  fontFamily: 'NunitoSans',
                                  color: StateContainer.of(context)
                                      .curTheme
                                      .text60,
                                ),
                              ),
                              keyboardType: TextInputType.text,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(15),
                              ],
                              style: AppStyles.textStyleParagraphPrimary(
                                  context,
                                  fontWeight: FontWeight.w600),
                              onChanged: (text) {
                                // Will rset validation message here
                              },
                            ),
                          ),
                        ])),
                        Container(
                          child: Column(
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  AppButton.buildAppButton(
                                      context,
                                      // Share Address Button
                                      _addressCopied
                                          ? AppButtonType.SUCCESS
                                          : AppButtonType.PRIMARY,
                                      _addressCopied
                                          ? AppLocalization.of(context)
                                              .addressCopied
                                          : AppLocalization.of(context)
                                              .copyAddress,
                                      Dimens.BUTTON_TOP_DIMENS, onPressed: () {
                                    Clipboard.setData(new ClipboardData(
                                        text: account.address));
                                    setState(() {
                                      // Set copied style
                                      _addressCopied = true;
                                    });
                                    if (_addressCopiedTimer != null) {
                                      _addressCopiedTimer.cancel();
                                    }
                                    _addressCopiedTimer = new Timer(
                                        const Duration(milliseconds: 800), () {
                                      setState(() {
                                        _addressCopied = false;
                                      });
                                    });
                                  }),
                                ],
                              ),
                              Row(
                                children: <Widget>[
                                  // Close Button
                                  AppButton.buildAppButton(
                                      context,
                                      AppButtonType.PRIMARY_OUTLINE,
                                      AppLocalization.of(context).close,
                                      Dimens.BUTTON_BOTTOM_DIMENS,
                                      onPressed: () {
                                    Navigator.pop(context);
                                  }),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    )));
          });
        });
  }
}
