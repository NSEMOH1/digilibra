import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barcode_scan/barcode_scan.dart';
import 'package:local_auth/local_auth.dart';

class AppColors {
  // Some constants not themed
  static const overlay70 = Color(0xB3000000);
  static const overlay85 = Color(0xD9000000);
}

abstract class BaseTheme {
  Color primary;
  Color primary60;
  Color primary45;
  Color primary30;
  Color primary20;
  Color primary15;
  Color primary10;

  Color success;
  Color success60;
  Color success30;
  Color success15;
  Color successDark;
  Color successDark30;

  Color background;
  Color background40;
  Color background00;

  Color backgroundDark;
  Color backgroundDark00;

  Color backgroundDarkest;

  Color text;
  Color text60;
  Color text45;
  Color text30;
  Color text20;
  Color text15;
  Color text10;
  Color text5;
  Color text03;

  Color overlay90;
  Color overlay85;
  Color overlay80;
  Color overlay70;
  Color overlay50;
  Color overlay30;
  Color overlay20;

  Color animationOverlayMedium;
  Color animationOverlayStrong;

  Brightness brightness;
  SystemUiOverlayStyle statusBar;

  BoxShadow boxShadow;
  BoxShadow boxShadowButton;

  // QR scanner theme
  OverlayTheme qrScanTheme;
  // FP Dialog theme (android-only)
  FPDialogTheme fpTheme;
  // App icon (iOS only)
  AppIconEnum appIcon;
}

class LibraTheme extends BaseTheme {
  static const purple = Color(0xFF42318C);

  static const green = Color(0xFF66BB6A);

  static const greenLight = Color(0xFF94CF97);

  static const white = Color(0xFFFFFFFF);

  static const grey = Color(0xFF454350);

  static const black = Color(0xFF000000);

  static const veryDarkPurple = Color(0xFF1D135C);

  Color primary = purple;
  Color primary60 = purple.withOpacity(0.6);
  Color primary45 = purple.withOpacity(0.45);
  Color primary30 = purple.withOpacity(0.3);
  Color primary20 = purple.withOpacity(0.2);
  Color primary15 = purple.withOpacity(0.15);
  Color primary10 = purple.withOpacity(0.1);

  Color success = green;
  Color success60 = green.withOpacity(0.6);
  Color success30 = green.withOpacity(0.3);
  Color success15 = green.withOpacity(0.15);

  Color successDark = greenLight;
  Color successDark30 = greenLight.withOpacity(0.3);

  Color background = white;
  Color background40 = white.withOpacity(0.4);
  Color background00 = white.withOpacity(0.0);

  Color backgroundDark = white;
  Color backgroundDark00 = white.withOpacity(0.0);

  Color backgroundDarkest = Color(0xFFE6E6E6);

  Color text = grey.withOpacity(0.9);
  Color text60 = grey.withOpacity(0.6);
  Color text45 = grey.withOpacity(0.45);
  Color text30 = grey.withOpacity(0.3);
  Color text20 = grey.withOpacity(0.2);
  Color text15 = grey.withOpacity(0.15);
  Color text10 = grey.withOpacity(0.1);
  Color text05 = grey.withOpacity(0.05);
  Color text03 = grey.withOpacity(0.03);

  Color overlay90 = black.withOpacity(0.9);
  Color overlay85 = black.withOpacity(0.85);
  Color overlay80 = black.withOpacity(0.8);
  Color overlay70 = black.withOpacity(0.7);
  Color overlay50 = black.withOpacity(0.5);
  Color overlay30 = black.withOpacity(0.3);
  Color overlay20 = black.withOpacity(0.2);

  Color animationOverlayMedium = white.withOpacity(0.7);
  Color animationOverlayStrong = white.withOpacity(0.85);

  Brightness brightness = Brightness.light;
  SystemUiOverlayStyle statusBar =
      SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent);

  BoxShadow boxShadow = BoxShadow(
      color: veryDarkPurple.withOpacity(0.1),
      offset: Offset(0, 5),
      blurRadius: 15);
  BoxShadow boxShadowButton = BoxShadow(
      color: veryDarkPurple.withOpacity(0.2),
      offset: Offset(0, 5),
      blurRadius: 15);

  OverlayTheme qrScanTheme = OverlayTheme.LIBRA;
  FPDialogTheme fpTheme = FPDialogTheme.LIBRA;
  AppIconEnum appIcon = AppIconEnum.LIBRA;
}

enum AppIconEnum { LIBRA }

class AppIcon {
  static const _channel = const MethodChannel('fappchannel');

  static Future<void> setAppIcon(AppIconEnum iconToChange) async {
    if (!Platform.isIOS) {
      return null;
    }
    String iconStr = 'libra';
    switch (iconToChange) {
      case AppIconEnum.LIBRA:
      default:
        iconStr = 'libra';
        break;
    }
    final Map<String, dynamic> params = <String, dynamic>{
      'icon': iconStr,
    };
    return await _channel.invokeMethod('changeIcon', params);
  }
}
