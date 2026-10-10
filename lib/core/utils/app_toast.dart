import 'package:flutter/material.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:toastification/toastification.dart';

abstract final class AppToast {
  static void success(BuildContext context, String message) => _show(
        context,
        message: message,
        type: ToastificationType.success,
        color: AppTheme.successColor,
      );

  static void error(BuildContext context, String message) => _show(
        context,
        message: message,
        type: ToastificationType.error,
        color: AppTheme.dangerColor,
        duration: const Duration(seconds: 4),
      );

  static void warning(BuildContext context, String message) => _show(
        context,
        message: message,
        type: ToastificationType.warning,
        color: AppTheme.warningColor,
        duration: const Duration(seconds: 4),
      );

  static void info(BuildContext context, String message) => _show(
        context,
        message: message,
        type: ToastificationType.info,
        color: AppTheme.infoColor,
      );

  static void _show(
    BuildContext context, {
    required String message,
    required ToastificationType type,
    required Color color,
    Duration duration = const Duration(seconds: 3),
  }) {
    toastification.dismissAll(delayForAnimation: false);
    toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.minimal,
      title: Text(
        message,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
      alignment: Alignment.topCenter,
      autoCloseDuration: duration,
      animationDuration: const Duration(milliseconds: 280),
      primaryColor: color,
      backgroundColor: AppTheme.cardColor,
      foregroundColor: AppTheme.textPrimary,
      borderRadius: BorderRadius.circular(14),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      showProgressBar: false,
      closeOnClick: true,
      dragToClose: true,
      pauseOnHover: true,
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A17251F),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
    );
  }
}
