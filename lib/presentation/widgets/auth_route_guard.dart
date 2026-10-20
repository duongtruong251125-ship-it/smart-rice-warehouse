import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/logic/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/presentation/routes/app_routes.dart';
import 'package:smart_rice_warehouse/presentation/screens/auth/login_screen.dart';

/// Removes protected content immediately when a profile is revoked.
class AuthRouteGuard extends StatelessWidget {
  const AuthRouteGuard({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.isLoggedIn ? builder(context) : const LoginScreen();
  }
}

/// Clears history on revocation/sign-out so Back cannot reopen an old session.
class AuthSessionGuard extends StatefulWidget {
  const AuthSessionGuard({super.key, required this.child});
  final Widget child;

  @override
  State<AuthSessionGuard> createState() => _AuthSessionGuardState();
}

class _AuthSessionGuardState extends State<AuthSessionGuard> {
  bool _wasLoggedIn = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    if (_wasLoggedIn && !auth.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || context.read<AuthProvider>().isLoggedIn) return;
        AppRoutes.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
      });
    }
    _wasLoggedIn = auth.isLoggedIn;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
