import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:event_taxi/event_taxi.dart';
import 'package:http/http.dart' as http;
import 'package:oktoast/oktoast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wallet/appstate_container.dart';
import 'package:wallet/styles.dart';
import 'package:wallet/localization.dart';
import 'package:wallet/bus/events.dart';
import 'package:wallet/ui/util/exceptions.dart';

enum ThreeLineAddressTextType { PRIMARY60, PRIMARY, SUCCESS, SUCCESS_FULL }
enum OneLineAddressTextType { PRIMARY60, PRIMARY, SUCCESS }

// avatar download job, intended to run in an isolate
Future<File> _downloadOrRetrieveAvatar(Map<String, String> params) async {
  String fileName = params['fileName'];
  Uri url = Uri.parse(params['url']);
  if (await File(fileName).exists()) {
    return File(fileName);
  }
  // Download avatar and return fildownloadOr
  http.Client client = http.Client();
  http.Response res;
  res = await client.get(url);
  var bytes = res.bodyBytes;
  File file = File(fileName);
  await file.writeAsBytes(bytes);
  return file;
}

class UIUtil {
  Widget threeLineAddressText(BuildContext context, String address,
      {ThreeLineAddressTextType type = ThreeLineAddressTextType.PRIMARY,
      String contactName}) {
    String stringPartOne = address.substring(0, 11);
    String stringPartTwo = address.substring(11, 22);
    String stringPartThree = address.substring(22, 44);
    String stringPartFour = address.substring(44, 58);
    String stringPartFive = address.substring(58, 64);
    switch (type) {
      case ThreeLineAddressTextType.PRIMARY60:
        return Column(
          children: <Widget>[
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: '',
                children: [
                  TextSpan(
                    text: stringPartOne,
                    style: AppStyles.textStyleAddressPrimary60(context),
                  ),
                  TextSpan(
                    text: stringPartTwo,
                    style: AppStyles.textStyleAddressText60(context),
                  ),
                ],
              ),
            ),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: '',
                children: [
                  TextSpan(
                    text: stringPartThree,
                    style: AppStyles.textStyleAddressText60(context),
                  ),
                ],
              ),
            ),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: '',
                children: [
                  TextSpan(
                    text: stringPartFour,
                    style: AppStyles.textStyleAddressText60(context),
                  ),
                  TextSpan(
                      text: stringPartFive,
                      style: AppStyles.textStyleAddressPrimary60(context)),
                ],
              ),
            )
          ],
        );
      case ThreeLineAddressTextType.PRIMARY:
        Widget contactWidget = contactName != null
            ? RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                    text: contactName,
                    style: AppStyles.textStyleAddressPrimary(context)))
            : SizedBox();
        return Column(
          children: <Widget>[
            contactWidget,
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: '',
                children: [
                  TextSpan(
                    text: stringPartOne,
                    style: AppStyles.textStyleAddressPrimary(context),
                  ),
                  TextSpan(
                    text: stringPartTwo,
                    style: AppStyles.textStyleAddressText90(context),
                  ),
                ],
              ),
            ),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: '',
                children: [
                  TextSpan(
                    text: stringPartThree,
                    style: AppStyles.textStyleAddressText90(context),
                  ),
                ],
              ),
            ),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: '',
                children: [
                  TextSpan(
                    text: stringPartFour,
                    style: AppStyles.textStyleAddressText90(context),
                  ),
                  TextSpan(
                    text: stringPartFive,
                    style: AppStyles.textStyleAddressPrimary(context),
                  ),
                ],
              ),
            )
          ],
        );
      case ThreeLineAddressTextType.SUCCESS:
        Widget contactWidget = contactName != null
            ? RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                    text: contactName,
                    style: AppStyles.textStyleAddressSuccess(context)))
            : SizedBox();
        return Column(
          children: <Widget>[
            contactWidget,
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: '',
                children: [
                  TextSpan(
                    text: stringPartOne,
                    style: AppStyles.textStyleAddressSuccess(context),
                  ),
                  TextSpan(
                    text: stringPartTwo,
                    style: AppStyles.textStyleAddressText90(context),
                  ),
                ],
              ),
            ),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: '',
                children: [
                  TextSpan(
                    text: stringPartThree,
                    style: AppStyles.textStyleAddressText90(context),
                  ),
                ],
              ),
            ),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: '',
                children: [
                  TextSpan(
                    text: stringPartFour,
                    style: AppStyles.textStyleAddressText90(context),
                  ),
                  TextSpan(
                    text: stringPartFive,
                    style: AppStyles.textStyleAddressSuccess(context),
                  ),
                ],
              ),
            )
          ],
        );
      case ThreeLineAddressTextType.SUCCESS_FULL:
        return Column(
          children: <Widget>[
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: '',
                children: [
                  TextSpan(
                    text: stringPartOne,
                    style: AppStyles.textStyleAddressSuccess(context),
                  ),
                  TextSpan(
                    text: stringPartTwo,
                    style: AppStyles.textStyleAddressSuccess(context),
                  ),
                ],
              ),
            ),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: '',
                children: [
                  TextSpan(
                    text: stringPartThree,
                    style: AppStyles.textStyleAddressSuccess(context),
                  ),
                ],
              ),
            ),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: '',
                children: [
                  TextSpan(
                    text: stringPartFour,
                    style: AppStyles.textStyleAddressSuccess(context),
                  ),
                  TextSpan(
                    text: stringPartFive,
                    style: AppStyles.textStyleAddressSuccess(context),
                  ),
                ],
              ),
            )
          ],
        );
      default:
        throw new UIException('Invalid threeLineAddressText Type $type');
    }
  }

  Widget oneLineAddressText(BuildContext context, String address,
      {OneLineAddressTextType type = OneLineAddressTextType.PRIMARY}) {
    String stringPartOne = address.substring(0, 11);
    String stringPartFive = address.substring(58, 64);
    switch (type) {
      case OneLineAddressTextType.PRIMARY60:
        return Column(
          children: <Widget>[
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: '',
                children: [
                  TextSpan(
                    text: stringPartOne,
                    style: AppStyles.textStyleAddressPrimary60(context),
                  ),
                  TextSpan(
                    text: '...',
                    style: AppStyles.textStyleAddressText60(context),
                  ),
                  TextSpan(
                    text: stringPartFive,
                    style: AppStyles.textStyleAddressPrimary60(context),
                  ),
                ],
              ),
            ),
          ],
        );
      case OneLineAddressTextType.PRIMARY:
        return Column(
          children: <Widget>[
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: '',
                children: [
                  TextSpan(
                    text: stringPartOne,
                    style: AppStyles.textStyleAddressPrimary(context),
                  ),
                  TextSpan(
                    text: '...',
                    style: AppStyles.textStyleAddressText90(context),
                  ),
                  TextSpan(
                    text: stringPartFive,
                    style: AppStyles.textStyleAddressPrimary(context),
                  ),
                ],
              ),
            ),
          ],
        );
      case OneLineAddressTextType.SUCCESS:
        return Column(
          children: <Widget>[
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: '',
                children: [
                  TextSpan(
                    text: stringPartOne,
                    style: AppStyles.textStyleAddressSuccess(context),
                  ),
                  TextSpan(
                    text: '...',
                    style: AppStyles.textStyleAddressText90(context),
                  ),
                  TextSpan(
                    text: stringPartFive,
                    style: AppStyles.textStyleAddressSuccess(context),
                  ),
                ],
              ),
            ),
          ],
        );
      default:
        throw new UIException('Invalid oneLineAddressText Type $type');
    }
  }

  Widget threeLineSeedText(BuildContext context, String address,
      {TextStyle textStyle}) {
    textStyle = textStyle ?? AppStyles.textStyleSeed(context);
    String stringPartOne = address.substring(0, 22);
    String stringPartTwo = address.substring(22, 44);
    String stringPartThree = address.substring(44, 64);
    return Column(
      children: <Widget>[
        Text(
          stringPartOne,
          style: textStyle,
        ),
        Text(
          stringPartTwo,
          style: textStyle,
        ),
        Text(
          stringPartThree,
          style: textStyle,
        ),
      ],
    );
  }

  Widget showExplorerWebview(BuildContext context, String hash) {
    cancelLockEvent();
    return WebviewScaffold(
      url: AppLocalization.of(context).getExplorerUrl(hash),
      appBar: new AppBar(
        backgroundColor: StateContainer.of(context).curTheme.backgroundDark,
        brightness: StateContainer.of(context).curTheme.brightness,
        iconTheme:
            IconThemeData(color: StateContainer.of(context).curTheme.text),
      ),
    );
  }

  Widget showAccountWebview(BuildContext context, String account) {
    cancelLockEvent();
    return WebviewScaffold(
      url: AppLocalization.of(context).getAccountExplorerUrl(account),
      appBar: new AppBar(
        backgroundColor: StateContainer.of(context).curTheme.backgroundDark,
        brightness: StateContainer.of(context).curTheme.brightness,
        iconTheme:
            IconThemeData(color: StateContainer.of(context).curTheme.text),
      ),
    );
  }

  Widget showWebview(BuildContext context, String url) {
    cancelLockEvent();
    return WebviewScaffold(
      url: url,
      appBar: new AppBar(
        backgroundColor: StateContainer.of(context).curTheme.backgroundDark,
        brightness: StateContainer.of(context).curTheme.brightness,
        iconTheme:
            IconThemeData(color: StateContainer.of(context).curTheme.text),
      ),
    );
  }

  Future<File> downloadOrRetrieveAvatar(
      BuildContext context, String address) async {
    // Get expected path
    String dir = (await getApplicationDocumentsDirectory()).path;
    String fileName = '$dir/$address.svg';
    String url = AppLocalization.of(context).getAvatarDownloadUrl(address);
    return await compute(
        _downloadOrRetrieveAvatar, {'fileName': fileName, 'url': url});
  }

  double drawerWidth(BuildContext context) {
    if (MediaQuery.of(context).size.width < 375)
      return MediaQuery.of(context).size.width * 0.94;
    else
      return MediaQuery.of(context).size.width * 0.85;
  }

  void showSnackbar(String content, BuildContext context) {
    showToastWidget(
      Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: EdgeInsets.symmetric(
              vertical: MediaQuery.of(context).size.height * 0.05,
              horizontal: 14),
          padding: EdgeInsets.symmetric(vertical: 15, horizontal: 15),
          width: MediaQuery.of(context).size.width - 30,
          decoration: BoxDecoration(
            color: StateContainer.of(context).curTheme.primary,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: StateContainer.of(context).curTheme.overlay80,
                  offset: Offset(0, 15),
                  blurRadius: 30,
                  spreadRadius: -5),
            ],
          ),
          child: Text(
            content,
            style: AppStyles.textStyleSnackbar(context),
            textAlign: TextAlign.start,
          ),
        ),
      ),
      dismissOtherToast: true,
      duration: Duration(milliseconds: 2500),
    );
  }

  StreamSubscription<dynamic> _lockDisableSub;

  Future<void> cancelLockEvent() async {
    // Cancel auto-lock event, usually if we are launching another intent
    if (_lockDisableSub != null) {
      _lockDisableSub.cancel();
    }
    EventTaxiImpl.singleton().fire(DisableLockTimeoutEvent(disable: true));
    Future<dynamic> delayed = Future.delayed(Duration(seconds: 10));
    delayed.then((_) {
      return true;
    });
    _lockDisableSub = delayed.asStream().listen((_) {
      EventTaxiImpl.singleton().fire(DisableLockTimeoutEvent(disable: false));
    });
  }
}
