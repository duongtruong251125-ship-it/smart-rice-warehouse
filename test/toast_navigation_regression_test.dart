import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/presentation/routes/app_routes.dart';
import 'package:smart_rice_warehouse/presentation/utils/app_toast.dart';
import 'package:toastification/toastification.dart';

void main() {
  testWidgets('toast remains safe when its source route is removed',
      (tester) async {
    await tester.pumpWidget(
      ToastificationWrapper(
        config: const ToastificationConfig(
          maxToastLimit: 1,
        ),
        child: MaterialApp(
          navigatorKey: AppRoutes.navigatorKey,
          initialRoute: '/',
          routes: {
            '/': (context) => Scaffold(
                  body: FilledButton(
                    onPressed: () {
                      AppToast.success(context, 'Đăng nhập thành công!');
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/home',
                        (route) => false,
                      );
                    },
                    child: const Text('Đăng nhập'),
                  ),
                ),
            '/home': (context) => const Scaffold(
                  body: Text('Trang chủ'),
                ),
          },
        ),
      ),
    );

    await tester.tap(find.text('Đăng nhập'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Trang chủ'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Chờ autoCloseDuration kết thúc để không còn pending timer
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('rapid replacement notifications do not corrupt the overlay',
      (tester) async {
    await tester.pumpWidget(
      ToastificationWrapper(
        config: const ToastificationConfig(
          maxToastLimit: 1,
        ),
        child: MaterialApp(
          navigatorKey: AppRoutes.navigatorKey,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () {
                  AppToast.info(context, 'Thông báo thứ nhất');
                  AppToast.success(context, 'Thông báo thứ hai');
                },
                child: const Text('Thông báo'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Thông báo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(tester.takeException(), isNull);

    // Chờ autoCloseDuration kết thúc để không còn pending timer
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('toast works safely using global ToastificationWrapper',
      (tester) async {
    await tester.pumpWidget(
      ToastificationWrapper(
        config: const ToastificationConfig(
          maxToastLimit: 1,
        ),
        child: MaterialApp(
          navigatorKey: AppRoutes.navigatorKey,
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () {
                  AppToast.success(context, 'Thông báo toàn cục');
                },
                child: const Text('Bấm thông báo'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Bấm thông báo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(tester.takeException(), isNull);

    // Chờ autoCloseDuration kết thúc để không còn pending timer
    await tester.pump(const Duration(seconds: 4));
  });
}
