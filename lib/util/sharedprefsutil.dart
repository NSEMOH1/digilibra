import 'dart:async';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet/model/available_themes.dart';
import 'package:wallet/model/authentication_method.dart';
import 'package:wallet/model/available_currency.dart';
import 'package:wallet/model/available_language.dart';
import 'package:wallet/model/device_lock_timeout.dart';

/// Price conversion preference values
enum PriceConversion { BTC, NONE }

/// Singleton wrapper for shared preferences
class SharedPrefsUtil {
  // Keys
  static const String seed_backed_up_key = 'flibra_seed_backup';
  static const String app_uuid_key = 'flibra_app_uuid';
  static const String price_conversion = 'flibra_price_conversion_pref';
  static const String auth_method = 'flibra_auth_method';
  static const String cur_currency = 'flibra_currency_pref';
  static const String cur_language = 'flibra_language_pref';
  static const String cur_theme = 'flibra_theme_pref';
  static const String firstcontact_added = 'flibra_first_c_added';
  static const String lock_libra = 'flibra_lock_dev';
  static const String libra_lock_timeout = 'flibra_lock_timeout';
  // For maximum pin attempts
  static const String pin_attempts = 'flibra_pin_attempts';
  static const String pin_lock_until = 'flibra_lock_duraton';
  // For certain keystore incompatible androids
  static const String use_legacy_storage = 'flibra_legacy_storage';

  // For plain-text data
  Future<void> set(String key, value) async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    if (value is bool) {
      sharedPreferences.setBool(key, value);
    } else if (value is String) {
      sharedPreferences.setString(key, value);
    } else if (value is double) {
      sharedPreferences.setDouble(key, value);
    } else if (value is int) {
      sharedPreferences.setInt(key, value);
    }
  }

  Future<dynamic> get(String key, {dynamic defaultValue}) async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    return await sharedPreferences.get(key) ?? defaultValue;
  }

  // Key-specific helpers
  Future<void> setSeedBackedUp(bool value) async {
    return await set(seed_backed_up_key, value);
  }

  Future<bool> getSeedBackedUp() async {
    return await get(seed_backed_up_key, defaultValue: false);
  }

  Future<void> setFirstContactAdded(bool value) async {
    return await set(firstcontact_added, value);
  }

  Future<bool> getFirstContactAdded() async {
    return await get(firstcontact_added, defaultValue: false);
  }

  Future<void> setPriceConversion(PriceConversion conversion) async {
    return await set(price_conversion, conversion.index);
  }

  Future<PriceConversion> getPriceConversion() async {
    return PriceConversion.values[
        await get(price_conversion, defaultValue: PriceConversion.BTC.index)];
  }

  Future<void> setAuthMethod(AuthenticationMethod method) async {
    return await set(auth_method, method.getIndex());
  }

  Future<AuthenticationMethod> getAuthMethod() async {
    return AuthenticationMethod(AuthMethod.values[
        await get(auth_method, defaultValue: AuthMethod.BIOMETRICS.index)]);
  }

  Future<void> setCurrency(AvailableCurrency currency) async {
    return await set(cur_currency, currency.getIndex());
  }

  Future<AvailableCurrency> getCurrency(Locale deviceLocale) async {
    return AvailableCurrency(AvailableCurrencyEnum.values[await get(
        cur_currency,
        defaultValue:
            AvailableCurrency.getBestForLocale(deviceLocale).currency.index)]);
  }

  Future<void> setLanguage(LanguageSetting language) async {
    return await set(cur_language, language.getIndex());
  }

  Future<LanguageSetting> getLanguage() async {
    return LanguageSetting(AvailableLanguage.values[await get(cur_language,
        defaultValue: AvailableLanguage.DEFAULT.index)]);
  }

  Future<ThemeSetting> getTheme() async {
    return ThemeSetting(ThemeOptions
        .values[await get(cur_theme, defaultValue: ThemeOptions.LIBRA.index)]);
  }

  Future<void> setLock(bool value) async {
    return await set(lock_libra, value);
  }

  Future<bool> getLock() async {
    return await get(lock_libra, defaultValue: false);
  }

  Future<void> setLockTimeout(LockTimeoutSetting setting) async {
    return await set(libra_lock_timeout, setting.getIndex());
  }

  Future<LockTimeoutSetting> getLockTimeout() async {
    return LockTimeoutSetting(LockTimeoutOption.values[await get(
        libra_lock_timeout,
        defaultValue: LockTimeoutOption.ONE.index)]);
  }

  // Locking out when max pin attempts exceeded
  Future<int> getLockAttempts() async {
    return await get(pin_attempts, defaultValue: 0);
  }

  Future<void> incrementLockAttempts() async {
    await set(pin_attempts, await getLockAttempts() + 1);
  }

  Future<void> resetLockAttempts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(pin_attempts);
    await prefs.remove(pin_lock_until);
  }

  Future<bool> shouldLock() async {
    if (await get(pin_lock_until) != null || await getLockAttempts() >= 5) {
      return true;
    }
    return false;
  }

  Future<bool> useLegacyStorage() async {
    return await get(use_legacy_storage, defaultValue: false);
  }

  Future<void> setUseLegacyStorage() async {
    await set(use_legacy_storage, true);
  }

  Future<void> updateLockDate() async {
    int attempts = await getLockAttempts();
    if (attempts >= 20) {
      // 4+ failed attempts
      await set(
          pin_lock_until,
          DateFormat.yMd()
              .add_jms()
              .format(DateTime.now().toUtc().add(Duration(hours: 24))));
    } else if (attempts >= 15) {
      // 3 failed attempts
      await set(
          pin_lock_until,
          DateFormat.yMd()
              .add_jms()
              .format(DateTime.now().toUtc().add(Duration(minutes: 15))));
    } else if (attempts >= 10) {
      // 2 failed attempts
      await set(
          pin_lock_until,
          DateFormat.yMd()
              .add_jms()
              .format(DateTime.now().toUtc().add(Duration(minutes: 5))));
    } else if (attempts >= 5) {
      await set(
          pin_lock_until,
          DateFormat.yMd()
              .add_jms()
              .format(DateTime.now().toUtc().add(Duration(minutes: 1))));
    }
  }

  Future<DateTime> getLockDate() async {
    String lockDateStr = await get(pin_lock_until);
    if (lockDateStr == null) {
      return null;
    }
    return DateFormat.yMd().add_jms().parseUtc(lockDateStr);
  }

  // For logging out
  Future<void> deleteAll() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(seed_backed_up_key);
    await prefs.remove(app_uuid_key);
    await prefs.remove(price_conversion);
    await prefs.remove(cur_currency);
    await prefs.remove(auth_method);
    await prefs.remove(lock_libra);
    await prefs.remove(pin_attempts);
    await prefs.remove(pin_lock_until);
    await prefs.remove(libra_lock_timeout);
  }
}
