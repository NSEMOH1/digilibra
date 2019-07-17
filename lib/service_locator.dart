import 'package:get_it/get_it.dart';
import 'package:wallet/model/db/appdb.dart';
import 'package:wallet/model/vault.dart';
import 'package:wallet/ui/util/ui_util.dart';
import 'package:wallet/util/numberutil.dart';
import 'package:wallet/util/hapticutil.dart';
import 'package:wallet/util/fileutil.dart';
import 'package:wallet/util/biometrics.dart';
import 'package:wallet/util/sharedprefsutil.dart';

GetIt sl = new GetIt();

void setupServiceLocator() {
  sl.registerLazySingleton(() => DBHelper());
  sl.registerLazySingleton<UIUtil>(() => UIUtil());
  sl.registerLazySingleton<NumberUtil>(() => NumberUtil());
  sl.registerLazySingleton<HapticUtil>(() => HapticUtil());
  sl.registerLazySingleton<FileUtil>(() => FileUtil());
  sl.registerLazySingleton<BiometricUtil>(() => BiometricUtil());
  sl.registerLazySingleton<Vault>(() => Vault());
  sl.registerLazySingleton<SharedPrefsUtil>(() => SharedPrefsUtil());
}
