import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:wallet/model/setting_item.dart';

enum AvailableCurrencyEnum { USD, CNY, HKD }

/// Represent the available authentication methods our app supports
class AvailableCurrency extends SettingSelectionItem {
  AvailableCurrencyEnum currency;

  AvailableCurrency(this.currency);

  String getIso4217Code() {
    return currency.toString().split('.')[1];
  }

  String getDisplayName(BuildContext context) {
    return getCurrencySymbol() + ' ' + getDisplayNameNoSymbol();
  }

  String getDisplayNameNoSymbol() {
    switch (getIso4217Code()) {
      case 'CNY':
        return 'Chinese Yuan';
      case 'HKD':
        return 'Hong Kong Dollar';
      case 'USD':
      default:
        return 'US Dollar';
    }
  }

  String getCurrencySymbol() {
    switch (getIso4217Code()) {
      case 'CNY':
        return '¥';
      case 'HKD':
        return 'HK\$';
      case 'USD':
      default:
        return '\$';
    }
  }

  Locale getLocale() {
    switch (getIso4217Code()) {
      case 'CNY':
        return Locale('zh', 'CN');
      case 'HKD':
        return Locale('zh', 'HK');
      case 'USD':
      default:
        return Locale('en', 'US');
    }
  }

  // For saving to shared prefs
  int getIndex() {
    return currency.index;
  }

  // Get best currency for a given locale
  // Default to USD
  static AvailableCurrency getBestForLocale(Locale locale) {
    AvailableCurrencyEnum.values.forEach((value) {
      AvailableCurrency currency = AvailableCurrency(value);
      if (locale != null &&
          locale.countryCode == null &&
          currency.getLocale().countryCode.toUpperCase() ==
              locale.countryCode.toUpperCase()) {
        return currency;
      }
    });
    return AvailableCurrency(AvailableCurrencyEnum.USD);
  }
}
