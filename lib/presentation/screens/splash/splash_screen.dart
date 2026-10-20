import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/presentation/routes/app_routes.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';
import 'package:smart_rice_warehouse/logic/providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Timer _navigationTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );
    _animController.forward();

    _navigationTimer = Timer(
      const Duration(milliseconds: 1500),
      _openNextScreen,
    );
  }

  Future<void> _openNextScreen() async {
    if (!mounted) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    await authProvider.waitUntilReady();
    if (!mounted) return;
    final route = authProvider.isLoggedIn ? AppRoutes.home : AppRoutes.login;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  void dispose() {
    _navigationTimer.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      body: SafeArea(
        child: Stack(
          children: [
            // Ambient soft glow effect
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentTeal.withValues(alpha: 0.06),
                ),
              ),
            ),

            // Main Content
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Brand Icon with Scale Transition
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: AppTheme.modernElevation,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(
                                Icons.warehouse_rounded,
                                size: 48,
                                color: Colors.white,
                              ),
                              Positioned(
                                right: 12,
                                bottom: 12,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryColor,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x33000000),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.rice_bowl_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Badge Tag (không overflow trên màn hình 320px)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.safeBgColor(context),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.safeBorderColor(context),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'POS • QUẢN LÝ KHO GẠO TINH GỌN',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.safeTextColor(context),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // App Title
                      Text(
                        'Smart Rice Warehouse',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          fontSize: 26,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Subtitle
                      Text(
                        'Vận hành kho gạo nhanh chóng, trực quan & chuẩn xác',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondaryColor(context),
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 38),

                      // Elegant Loading Indicator
                      Container(
                        width: 160,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(6)),
                              child: LinearProgressIndicator(
                                minHeight: 4,
                                color: AppTheme.primaryColor,
                                backgroundColor: isDark
                                    ? AppTheme.darkBorder
                                    : AppTheme.primaryLight,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Đang kết nối hệ thống kho...',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppTheme.textSecondaryColor(context),
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(
                child: Text(
                  'Phiên bản 1.0.0 • Nền tảng Nông nghiệp Số FEFO & OCR',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textMutedColor(context),
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
