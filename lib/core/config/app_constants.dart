import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  AppConstants._();

  static const appName = 'Quản lý Thu Chi Vợ Chồng';
  static const appShortName = 'Thu Chi';
  static const envFileName = '.env';

  static const vietnameseLocale = Locale('vi', 'VN');
  static const supportedLocales = [vietnameseLocale, Locale('en', 'US')];

  static String get supabaseUrl =>
      dotenv.env[EnvironmentKeys.supabaseUrl] ?? '';

  static String get supabaseAnonKey =>
      dotenv.env[EnvironmentKeys.supabaseAnonKey] ?? '';

  /// Dừng app sớm nếu thiếu cấu hình quan trọng trong file .env.
  static void validateEnvironment() {
    final missingKeys = <String>[
      if (supabaseUrl.isEmpty) EnvironmentKeys.supabaseUrl,
      if (supabaseAnonKey.isEmpty) EnvironmentKeys.supabaseAnonKey,
    ];

    if (missingKeys.isNotEmpty) {
      throw StateError(
        'Thiếu biến môi trường: ${missingKeys.join(', ')}. '
        'Hãy tạo file .env từ .env.example.',
      );
    }
  }
}

class EnvironmentKeys {
  EnvironmentKeys._();

  static const supabaseUrl = 'SUPABASE_URL';
  static const supabaseAnonKey = 'SUPABASE_ANON_KEY';
}

class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}
