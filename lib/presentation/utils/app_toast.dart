import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:smart_rice_warehouse/presentation/routes/app_routes.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';
import 'package:toastification/toastification.dart';

abstract final class AppToast {
  static void success(BuildContext? context, String message) => _show(
        context,
        message: message,
        type: ToastificationType.success,
        color: AppTheme.successColor,
      );

  static void error(BuildContext? context, String message) => _show(
        context,
        message: message,
        type: ToastificationType.error,
        color: AppTheme.dangerColor,
        duration: const Duration(seconds: 4),
      );

  static void warning(BuildContext? context, String message) => _show(
        context,
        message: message,
        type: ToastificationType.warning,
        color: AppTheme.warningColor,
        duration: const Duration(seconds: 4),
      );

  static void info(BuildContext? context, String message) => _show(
        context,
        message: message,
        type: ToastificationType.info,
        color: AppTheme.infoColor,
      );

  static BuildContext? get _currentRouteContext {
    BuildContext? current;
    AppRoutes.navigatorKey.currentState?.popUntil((route) {
      if (route is ModalRoute) {
        current = route.subtreeContext;
      }
      return true;
    });
    return current;
  }

  static void _show(
    BuildContext? context, {
    required String message,
    required ToastificationType type,
    required Color color,
    Duration duration = const Duration(seconds: 3),
  }) {
    void display() {
      final effectiveContext = AppRoutes.navigatorKey.currentContext ??
          ((context != null && context.mounted)
              ? context
              : _currentRouteContext);

      if (effectiveContext == null) return;

      toastification.show(
        context: effectiveContext,
        type: type,
        style: ToastificationStyle.minimal,
        title: Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.textPrimaryColor(effectiveContext),
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        alignment: Alignment.topCenter,
        autoCloseDuration: duration,
        animationDuration: const Duration(milliseconds: 280),
        primaryColor: color,
        backgroundColor: AppTheme.cardBg(effectiveContext),
        foregroundColor: AppTheme.textPrimaryColor(effectiveContext),
        borderRadius: BorderRadius.circular(14),
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        showProgressBar: false,
        closeOnClick: true,
        dragToClose: true,
        pauseOnHover: true,
        boxShadow: AppTheme.isDark(effectiveContext)
            ? AppTheme.darkCardShadow
            : const [
                BoxShadow(
                  color: Color(0x1A17251F),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
      );
    }

    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      display();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => display());
    }
  }
}
