import 'package:flutter/material.dart';
import 'package:wallet/localization.dart';
import 'package:wallet/model/setting_item.dart';

enum AvailableLanguage {
  DEFAULT,
  ENGLISH,
  CHINESE_SIMPLIFIED,
  CHINESE_TRADITIONAL
}

/// Represent the available languages our app supports
class LanguageSetting extends SettingSelectionItem {
  AvailableLanguage language;

  LanguageSetting(this.language);

  String getDisplayName(BuildContext context) {
    switch (language) {
      case AvailableLanguage.ENGLISH:
        return 'English (en)';
      case AvailableLanguage.CHINESE_SIMPLIFIED:
        return '简体字 (zh-Hans)';
      case AvailableLanguage.CHINESE_TRADITIONAL:
        return '繁體字 (zh-Hant)';
      default:
        return AppLocalization.of(context).systemDefault;
    }
  }

  String getLocaleString() {
    switch (language) {
      case AvailableLanguage.ENGLISH:
        return 'en';
      case AvailableLanguage.CHINESE_SIMPLIFIED:
        return 'zh-Hans';
      case AvailableLanguage.CHINESE_TRADITIONAL:
        return 'zh-Hant';
      default:
        return 'DEFAULT';
    }
  }

  Locale getLocale() {
    String localeStr = getLocaleString();
    if (localeStr == 'DEFAULT') {
      return Locale('en');
    } else if (localeStr == 'zh-Hans' || localeStr == 'zh-Hant') {
      return Locale.fromSubtags(
          languageCode: 'zh', scriptCode: localeStr.split('-')[1]);
    }
    return Locale(localeStr);
  }

  // For saving to shared prefs
  int getIndex() {
    return language.index;
  }
}
