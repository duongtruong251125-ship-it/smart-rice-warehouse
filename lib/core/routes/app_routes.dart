import 'package:flutter/material.dart';
import 'package:smart_rice_warehouse/screens/alerts/alert_list_screen.dart';
import 'package:smart_rice_warehouse/screens/auth/login_screen.dart';
import 'package:smart_rice_warehouse/screens/batch/batch_list_screen.dart';
import 'package:smart_rice_warehouse/screens/customer/customer_form_screen.dart';
import 'package:smart_rice_warehouse/screens/customer/customer_list_screen.dart';
import 'package:smart_rice_warehouse/screens/export/export_form_screen.dart';
import 'package:smart_rice_warehouse/screens/export/export_list_screen.dart';
import 'package:smart_rice_warehouse/screens/forecast/forecast_screen.dart';
import 'package:smart_rice_warehouse/screens/home/main_screen.dart';
import 'package:smart_rice_warehouse/screens/import/import_form_screen.dart';
import 'package:smart_rice_warehouse/screens/import/import_list_screen.dart';
import 'package:smart_rice_warehouse/screens/inventory/inventory_screen.dart';
import 'package:smart_rice_warehouse/screens/ocr/ocr_prototype_screen.dart';
import 'package:smart_rice_warehouse/screens/profile/profile_tab.dart';
import 'package:smart_rice_warehouse/screens/reports/reports_tab.dart';
import 'package:smart_rice_warehouse/screens/rice/rice_form_screen.dart';
import 'package:smart_rice_warehouse/screens/rice/rice_list_screen.dart';
import 'package:smart_rice_warehouse/screens/splash/splash_screen.dart';
import 'package:smart_rice_warehouse/screens/supplier/supplier_form_screen.dart';
import 'package:smart_rice_warehouse/screens/supplier/supplier_list_screen.dart';

abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String rice = '/rice';
  static const String addRice = '/rice/add';
  static const String editRice = '/rice/edit';
  static const String suppliers = '/suppliers';
  static const String addSupplier = '/suppliers/add';
  static const String editSupplier = '/suppliers/edit';
  static const String customers = '/customers';
  static const String addCustomer = '/customers/add';
  static const String editCustomer = '/customers/edit';
  static const String batches = '/batches';
  static const String import = '/import';
  static const String addImport = '/import/add';
  static const String export = '/export';
  static const String addExport = '/export/add';
  static const String inventory = '/inventory';
  static const String reports = '/reports';
  static const String profile = '/profile';
  static const String alerts = '/alerts';
  static const String forecast = '/forecast';
  static const String ocrPrototype = '/ocr/prototype';

  static final Map<String, WidgetBuilder> routes = <String, WidgetBuilder>{
    splash: (_) => const SplashScreen(),
    login: (_) => const LoginScreen(),
    home: (_) => const MainScreen(),
    rice: (_) => const RiceListScreen(),
    addRice: (_) => const RiceFormScreen(),
    editRice: (context) {
      final argument = ModalRoute.of(context)?.settings.arguments;
      return RiceFormScreen(
        riceId: argument is String ? argument : null,
        isEditing: true,
      );
    },
    suppliers: (_) => const SupplierListScreen(),
    addSupplier: (_) => const SupplierFormScreen(),
    editSupplier: (context) {
      final argument = ModalRoute.of(context)?.settings.arguments;
      return SupplierFormScreen(
        supplierId: argument is String ? argument : null,
        isEditing: true,
      );
    },
    customers: (_) => const CustomerListScreen(),
    addCustomer: (_) => const CustomerFormScreen(),
    editCustomer: (context) {
      final argument = ModalRoute.of(context)?.settings.arguments;
      return CustomerFormScreen(
        customerId: argument is String ? argument : null,
        isEditing: true,
      );
    },
    batches: (_) => const BatchListScreen(),
    inventory: (_) => const InventoryScreen(),
    import: (_) => const ImportListScreen(),
    addImport: (_) => const ImportFormScreen(),
    export: (_) => const ExportListScreen(),
    addExport: (_) => const ExportFormScreen(),
    reports: (_) => Scaffold(
          appBar: AppBar(title: const Text('Báo cáo')),
          body: const ReportsTab(),
        ),
    profile: (_) => Scaffold(
          appBar: AppBar(title: const Text('Tài khoản')),
          body: const ProfileTab(),
        ),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == alerts) {
      return MaterialPageRoute(builder: (_) => const AlertListScreen());
    }
    if (settings.name == forecast) {
      return MaterialPageRoute(builder: (_) => const ForecastScreen());
    }
    if (settings.name == ocrPrototype) {
      return MaterialPageRoute(builder: (_) => const OcrPrototypeScreen());
    }
    return null;
  }
}
