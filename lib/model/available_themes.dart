import 'package:flutter/material.dart';
import 'package:wallet/themes.dart';
import 'package:wallet/model/setting_item.dart';

enum ThemeOptions { LIBRA }

class ThemeSetting extends SettingSelectionItem {
  ThemeOptions theme;

  ThemeSetting(this.theme);

  String getDisplayName(BuildContext context) {
    switch (theme) {
      case ThemeOptions.LIBRA:
      default:
        return 'Libra';
    }
  }

  BaseTheme getTheme() {
    switch (theme) {
      case ThemeOptions.LIBRA:
      default:
        return LibraTheme();
    }
  }

  // For saving to shared prefs
  int getIndex() {
    return theme.index;
  }
}
