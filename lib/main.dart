import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/supabase_service.dart';
import 'shared/widgets/app_feedback.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bắt lỗi không được xử lý để app luôn phản hồi bằng UI tiếng Việt.
  FlutterError.onError = AppFeedback.handleFlutterError;
  PlatformDispatcher.instance.onError = AppFeedback.handlePlatformError;

  // SupabaseService sẽ load .env, validate biến môi trường và khởi tạo client.
  await SupabaseService.instance.initialize();

  runApp(const ProviderScope(child: ThuChiApp()));
}
