import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:wallet/appstate_container.dart';
import 'package:wallet/ui/widgets/auto_resize_text.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wallet/styles.dart';

class AppShareCard extends StatefulWidget {
  final GlobalKey sharedKey;
  final Widget avatarSvg;

  AppShareCard(this.sharedKey, this.avatarSvg);

  @override
  _AppShareCardState createState() => _AppShareCardState(sharedKey, avatarSvg);
}

class _AppShareCardState extends State<AppShareCard> {
  GlobalKey globalKey;
  Widget avatarSvg;

  _AppShareCardState(this.globalKey, this.avatarSvg);

  @override
  Widget build(BuildContext context) {
    Color color = StateContainer.of(context).curTheme.primary;
    double padding = 12.5;
    return RepaintBoundary(
      key: globalKey,
      child: Container(
        height: 125,
        width: 241,
        decoration: BoxDecoration(
          color: StateContainer.of(context).curTheme.backgroundDark,
          borderRadius: BorderRadius.circular(padding),
        ),
        child: Container(
          margin: EdgeInsets.only(left: padding, right: padding, top: padding),
          constraints: BoxConstraints.expand(),
          // The main row that holds qrScanGuide, logo, the address, ticker and the website text
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // A container for qrScanGuide
              Container(
                margin: EdgeInsets.only(bottom: padding),
                width: 105,
                height: 100.0,
                child: Stack(
                  children: <Widget>[
                    // Background/border part of qrScanGuide
                    Center(
                      child: Container(
                        width: 105,
                        height: 100.0,
                        child: avatarSvg,
                      ),
                    ),
                    // Actual QR part of the qrScanGuide
                    Center(
                      child: Container(
                        margin: EdgeInsets.only(top: 0),
                        child: QrImage(
                          padding: EdgeInsets.all(0.0),
                          size: 50,
                          data: StateContainer.of(context).wallet.address,
                          version: 6,
                          errorCorrectionLevel: QrErrorCorrectLevel.Q,
                          gapless: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // A column for logo, address, ticker and website text
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  // Logo
                  Container(
                    width: 97,
                    child: AutoSizeText.rich(
                      TextSpan(
                        children: [
                          // Currency Icon
                          TextSpan(
                            text: ' ',
                            style: TextStyle(
                              color: color,
                              fontFamily: 'AppIcons',
                              fontWeight: FontWeight.w500,
                              fontSize: 50,
                            ),
                          ),
                          TextSpan(
                            text: 'LIBRA',
                            style: TextStyle(
                              color: color,
                              fontFamily: 'NeueHansKendrick',
                              fontWeight: FontWeight.w500,
                              fontSize: 49,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      stepGranularity: 0.1,
                      minFontSize: 1,
                      style: TextStyle(
                        fontFamily: 'NeueHansKendrick',
                        fontSize: 50,
                      ),
                    ),
                  ),
                  // Address
                  Container(
                    padding: Platform.isIOS
                        ? EdgeInsets.only(bottom: 6)
                        : EdgeInsets.zero,
                    child: Column(
                      children: <Widget>[
                        // First row of the address
                        Container(
                          width: 97,
                          child: AutoSizeText.rich(
                              TextSpan(
                                children: [
                                  // Primary part of the first row
                                  TextSpan(
                                      text: StateContainer.of(context)
                                          .wallet
                                          .address
                                          .substring(0, 11),
                                      style: AppStyles.textStyleSharePrimary(
                                          context)),
                                  TextSpan(
                                      text: StateContainer.of(context)
                                          .wallet
                                          .address
                                          .substring(11, 16),
                                      style: AppStyles.textStyleShare(context)),
                                ],
                              ),
                              maxLines: 1,
                              stepGranularity: 0.1,
                              minFontSize: 1,
                              style: AppStyles.textStyleShare(context)),
                        ),
                        // Second row of the address
                        Container(
                          width: 97,
                          child: AutoSizeText(
                              StateContainer.of(context)
                                  .wallet
                                  .address
                                  .substring(16, 32),
                              minFontSize: 1.0,
                              stepGranularity: 0.1,
                              maxFontSize: 50,
                              maxLines: 1,
                              style: AppStyles.textStyleShare(context)),
                        ),
                        // Third row of the address
                        Container(
                          width: 97,
                          child: AutoSizeText(
                              StateContainer.of(context)
                                  .wallet
                                  .address
                                  .substring(32, 48),
                              minFontSize: 1.0,
                              stepGranularity: 0.1,
                              maxFontSize: 50,
                              maxLines: 1,
                              style: AppStyles.textStyleShare(context)),
                        ),
                        // Fourth(last) row of the address
                        Container(
                          width: 97,
                          child: AutoSizeText.rich(
                              TextSpan(
                                children: [
                                  // Text colored part of the last row
                                  TextSpan(
                                      text: StateContainer.of(context)
                                          .wallet
                                          .address
                                          .substring(48, 58),
                                      style: AppStyles.textStyleShare(context)),
                                  // Primary colored part of the last row
                                  TextSpan(
                                      text: StateContainer.of(context)
                                          .wallet
                                          .address
                                          .substring(58, 64),
                                      style: AppStyles.textStyleSharePrimary(
                                          context)),
                                ],
                              ),
                              maxLines: 1,
                              stepGranularity: 0.1,
                              minFontSize: 1,
                              style: AppStyles.textStyleShare(context)),
                        ),
                      ],
                    ),
                  ),
                  // Ticker & Website
                  Container(
                    width: 97,
                    margin: EdgeInsets.only(bottom: 12),
                    child: AutoSizeText(
                      '\$LIBRA      LIBRA.CC',
                      minFontSize: 1.0,
                      stepGranularity: 0.1,
                      maxLines: 1,
                      style: TextStyle(
                        color: color,
                        fontFamily: 'NeueHansKendrick',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
