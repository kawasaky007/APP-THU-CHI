import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

class AppFeedback {
  AppFeedback._();

  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  static final navigatorKey = GlobalKey<NavigatorState>();

  static void showSnackBar(String message, {bool isError = false}) {
    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) {
      return;
    }

    _runAfterBuild(() {
      final messenger = scaffoldMessengerKey.currentState;
      if (messenger == null) {
        return;
      }

      final context = scaffoldMessengerKey.currentContext;
      final colorScheme = context == null || !context.mounted
          ? null
          : Theme.of(context).colorScheme;

      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(cleanMessage),
            backgroundColor: isError ? colorScheme?.error : null,
            behavior: SnackBarBehavior.fixed,
          ),
        );
    });
  }

  static Future<void> showErrorDialog({
    String title = 'Có lỗi xảy ra',
    required String message,
  }) async {
    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) {
      return;
    }

    final completer = Completer<void>();
    _runAfterBuild(() async {
      try {
        final context = navigatorKey.currentContext;
        if (context == null || !context.mounted) {
          showSnackBar(cleanMessage, isError: true);
          return;
        }

        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              icon: const Icon(Icons.error_outline),
              title: Text(title),
              content: Text(cleanMessage),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đã hiểu'),
                ),
              ],
            );
          },
        );
      } finally {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    return completer.future;
  }

  static void handleFlutterError(FlutterErrorDetails details) {
    FlutterError.presentError(details);
  }

  static bool handlePlatformError(Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      debugPrint('Unhandled platform error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    return true;
  }
}

class GlobalAppFeedback extends ConsumerStatefulWidget {
  const GlobalAppFeedback({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<GlobalAppFeedback> createState() => _GlobalAppFeedbackState();
}

class _GlobalAppFeedbackState extends ConsumerState<GlobalAppFeedback> {
  late final ProviderSubscription<SupabaseService> _serviceSubscription;
  SupabaseService? _service;
  SupabaseServiceException? _lastServiceError;

  @override
  void initState() {
    super.initState();
    _serviceSubscription = ref.listenManual<SupabaseService>(
      supabaseServiceProvider,
      (previous, next) => _attachService(next),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _serviceSubscription.close();
    _detachService();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(supabaseServiceProvider);
    final authLoading = ref.watch(
      authControllerProvider.select((state) => state.isLoading),
    );

    return ValueListenableBuilder<bool>(
      valueListenable: service.loadingListenable,
      builder: (context, serviceLoading, child) {
        final showLoading = serviceLoading || authLoading;
        final content = child ?? const SizedBox.shrink();

        return Stack(
          children: [content, if (showLoading) const _LoadingOverlay()],
        );
      },
      child: widget.child,
    );
  }

  void _attachService(SupabaseService service) {
    if (identical(_service, service)) {
      return;
    }

    _detachService();
    _service = service;
    service.errorListenable.addListener(_handleServiceError);
  }

  void _detachService() {
    final service = _service;
    if (service == null) {
      return;
    }
    service.errorListenable.removeListener(_handleServiceError);
    _service = null;
  }

  void _handleServiceError() {
    final error = _service?.lastError;
    if (error == null || identical(error, _lastServiceError)) {
      return;
    }

    _lastServiceError = error;
    AppFeedback.showSnackBar(
      '${error.actionName}: ${error.message}',
      isError: true,
    );
  }
}

void _runAfterBuild(VoidCallback callback) {
  final binding = WidgetsBinding.instance;
  binding.addPostFrameCallback((_) => callback());
  binding.ensureVisualUpdate();
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.16),
          child: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.6),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Đang xử lý...',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
