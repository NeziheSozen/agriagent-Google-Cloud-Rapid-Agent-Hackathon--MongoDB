import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'shared_prefs_provider.g.dart';

/// SharedPreferences instance — overridden in main() with the real value.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) {
  throw UnimplementedError();
}
