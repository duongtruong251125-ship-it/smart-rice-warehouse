import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/app_toast.dart';
import 'package:smart_rice_warehouse/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _rememberLogin = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  static String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Vui lòng nhập email';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Email không đúng định dạng';
    }
    return null;
  }

  static String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (value.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
    return null;
  }

  void _openHome() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (route) => false,
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final remoteResult = await authProvider.loginWithFirebase(
        email: email,
        password: password,
        remember: _rememberLogin,
      );
      if (!mounted) return;

      if (remoteResult.success) {
        AppToast.success(context, 'Đăng nhập thành công!');
        _openHome();
        return;
      }

      // Local mode exists only for widget tests and installations where
      // Firebase could not be initialized. Cloud mode never falls back to a
      // password stored in SQLite.
      if (!authProvider.isCloudAuthEnabled &&
          authProvider.login(
            email: email,
            password: password,
            remember: _rememberLogin,
          )) {
        AppToast.success(context, 'Đăng nhập thành công!');
        _openHome();
        return;
      }

      AppToast.error(
        context,
        remoteResult.message ?? 'Email hoặc mật khẩu không chính xác.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showRegisterDialog() async {
    final registeredEmail = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _RegisterDialog(),
    );

    if (registeredEmail != null && mounted) {
      _emailController.text = registeredEmail;
      AppToast.success(
        context,
        'Đã tạo tài khoản. Vui lòng chờ quản trị viên kích hoạt.',
      );
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ForgotPasswordDialog(
        initialEmail: _emailController.text.trim(),
      ),
    );

    if (sent == true && mounted) {
      AppToast.success(
        context,
        'Đã gửi liên kết khôi phục. Vui lòng kiểm tra email.',
      );
    }
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
            // Ambient glow effect nền góc trên và dưới
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : AppTheme.primaryColor.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? const Color(0xFF0F766E).withValues(alpha: 0.15)
                      : AppTheme.accentTeal.withValues(alpha: 0.06),
                ),
              ),
            ),

            // Form nội dung chính
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 48)
                        .clamp(0.0, double.infinity),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo Container
                            Center(
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  gradient: isDark
                                      ? AppTheme.darkHeroGradient
                                      : AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: AppTheme.modernElevation,
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    const Icon(
                                      Icons.warehouse_rounded,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                    Positioned(
                                      right: 10,
                                      bottom: 10,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.secondaryColor,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x33000000),
                                              blurRadius: 4,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.rice_bowl_rounded,
                                          size: 13,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fade(duration: 400.ms).scale(
                                  begin: const Offset(0.88, 0.88),
                                  curve: Curves.easeOutBack,
                                ),

                            const SizedBox(height: 18),

                            // Badge Tag
                            Center(
                              child: Container(
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
                                  'Quản lý kho gạo thông minh',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppTheme.safeTextColor(context),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ).animate().fade(delay: 100.ms, duration: 350.ms),

                            const SizedBox(height: 12),

                            // App Title
                            Text(
                              'Smart Rice Warehouse',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: AppTheme.textPrimaryColor(context),
                              ),
                            )
                                .animate()
                                .fade(delay: 150.ms, duration: 400.ms)
                                .slideY(
                                  begin: 0.1,
                                  end: 0,
                                ),

                            const SizedBox(height: 6),

                            // Subtitle
                            Text(
                              'Đăng nhập để tiếp tục quản lý kho',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor(context),
                                fontSize: 13.5,
                              ),
                            ).animate().fade(delay: 200.ms, duration: 400.ms),

                            const SizedBox(height: 24),

                            // Card Form
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.cardBg(context),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppTheme.border(context),
                                  width: 1,
                                ),
                                boxShadow: isDark
                                    ? AppTheme.darkCardShadow
                                    : const [
                                        BoxShadow(
                                          color: Color(0x0C17251F),
                                          blurRadius: 28,
                                          offset: Offset(0, 10),
                                        ),
                                      ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Gradient Top Accent Bar
                                  Container(
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                    ),
                                  ),

                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 24,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Email Field
                                        TextFormField(
                                          controller: _emailController,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          textInputAction: TextInputAction.next,
                                          autofillHints: const [
                                            AutofillHints.email
                                          ],
                                          validator: _validateEmail,
                                          decoration: InputDecoration(
                                            labelText: 'Email',
                                            hintText: 'admin@gmail.com',
                                            prefixIcon: const Icon(
                                              Icons.email_outlined,
                                              color: AppTheme.primaryColor,
                                            ),
                                            filled: true,
                                            fillColor: isDark
                                                ? const Color(0xFF131D31)
                                                : const Color(0xFFFAFBFB),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              borderSide: BorderSide(
                                                color: AppTheme.border(context),
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              borderSide: BorderSide(
                                                color: AppTheme.border(context),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              borderSide: const BorderSide(
                                                color: AppTheme.primaryColor,
                                                width: 1.8,
                                              ),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 16),

                                        // Password Field
                                        TextFormField(
                                          controller: _passwordController,
                                          obscureText: !_isPasswordVisible,
                                          textInputAction: TextInputAction.done,
                                          autofillHints: const [
                                            AutofillHints.password
                                          ],
                                          validator: _validatePassword,
                                          onFieldSubmitted: (_) => _submit(),
                                          decoration: InputDecoration(
                                            labelText: 'Mật khẩu',
                                            hintText: 'Tối thiểu 6 ký tự',
                                            prefixIcon: const Icon(
                                              Icons.lock_outline_rounded,
                                              color: AppTheme.primaryColor,
                                            ),
                                            filled: true,
                                            fillColor: isDark
                                                ? const Color(0xFF131D31)
                                                : const Color(0xFFFAFBFB),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              borderSide: BorderSide(
                                                color: AppTheme.border(context),
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              borderSide: BorderSide(
                                                color: AppTheme.border(context),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              borderSide: const BorderSide(
                                                color: AppTheme.primaryColor,
                                                width: 1.8,
                                              ),
                                            ),
                                            suffixIcon: IconButton(
                                              tooltip: _isPasswordVisible
                                                  ? 'Ẩn mật khẩu'
                                                  : 'Hiện mật khẩu',
                                              onPressed: () => setState(
                                                () => _isPasswordVisible =
                                                    !_isPasswordVisible,
                                              ),
                                              icon: Icon(
                                                _isPasswordVisible
                                                    ? Icons
                                                        .visibility_off_outlined
                                                    : Icons.visibility_outlined,
                                                color: AppTheme.textSecondaryColor(context),
                                              ),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 8),

                                        // Remember & Forgot Password Row
                                        Row(
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                onTap: () => setState(
                                                  () => _rememberLogin =
                                                      !_rememberLogin,
                                                ),
                                                child: Row(
                                                  children: [
                                                    SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child: Checkbox(
                                                        value: _rememberLogin,
                                                        activeColor: AppTheme
                                                            .primaryColor,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        onChanged: (value) =>
                                                            setState(
                                                          () => _rememberLogin =
                                                              value ?? false,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Flexible(
                                                      child: Text(
                                                        'Ghi nhớ đăng nhập',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: AppTheme
                                                              .textSecondaryColor(context),
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: _isLoading
                                                  ? null
                                                  : _showForgotPasswordDialog,
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 4,
                                                ),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              child: Text(
                                                'Quên mật khẩu?',
                                                style: TextStyle(
                                                  color: isDark
                                                      ? AppTheme.darkSafeText
                                                      : AppTheme.primaryDark,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 18),

                                        // Nút Đăng nhập
                                        FilledButton(
                                          onPressed:
                                              _isLoading ? null : _submit,
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                AppTheme.primaryColor,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            elevation: 2,
                                            shadowColor: AppTheme.primaryColor
                                                .withValues(alpha: 0.35),
                                          ),
                                          child: _isLoading
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Text(
                                                  'Đăng nhập',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                        ),

                                        const SizedBox(height: 18),

                                        // Hoặc phân cách
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Divider(
                                                color: AppTheme.border(context),
                                                thickness: 1,
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                              ),
                                              child: Text(
                                                'HOẶC',
                                                style: TextStyle(
                                                  color: isDark
                                                      ? AppTheme.darkTextMuted
                                                      : AppTheme.textMuted,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Divider(
                                                color: AppTheme.border(context),
                                                thickness: 1,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 18),

                                        // Nút Đăng ký
                                        OutlinedButton.icon(
                                          onPressed: _isLoading
                                              ? null
                                              : _showRegisterDialog,
                                          icon: const Icon(
                                            Icons.person_add_rounded,
                                            size: 19,
                                          ),
                                          label: const Text(
                                            'Đăng ký',
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: isDark
                                                ? AppTheme.darkSafeText
                                                : AppTheme.primaryDark,
                                            side: BorderSide(
                                              color: isDark
                                                  ? AppTheme.darkSafeBorder
                                                  : const Color(0xFFC3E8D3),
                                              width: 1.3,
                                            ),
                                            backgroundColor: isDark
                                                ? AppTheme.darkSafeBg
                                                : AppTheme.primaryLight
                                                    .withValues(alpha: 0.4),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 13,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                                .animate()
                                .fade(delay: 250.ms, duration: 400.ms)
                                .slideY(
                                  begin: 0.08,
                                  end: 0,
                                ),

                            const SizedBox(height: 24),

                            // Footer note
                            Center(
                              child: Text(
                                'Dương Vân Trường - Vũ Huy',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppTheme.textMuted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _RegisterDialog extends StatefulWidget {
  const _RegisterDialog();

  @override
  State<_RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<_RegisterDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final String _selectedRole = 'staff';
  bool _submitting = false;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Row(
        children: [
          Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primaryColor),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đăng ký tài khoản',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Vui lòng nhập họ tên'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newUsername],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: _LoginScreenState._validateEmail,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: !_passwordVisible,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  helperText: 'Tối thiểu 6 ký tự',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _passwordVisible ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                    onPressed: () => setState(
                      () => _passwordVisible = !_passwordVisible,
                    ),
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: _LoginScreenState._validatePassword,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: !_passwordVisible,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Nhập lại mật khẩu',
                  prefixIcon: Icon(Icons.verified_user_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập lại mật khẩu';
                  }
                  if (value != _passwordController.text) {
                    return 'Mật khẩu nhập lại không khớp';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: 'Nhân viên (chờ quản trị viên kích hoạt)',
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Vai trò',
                  helperText: 'Vai trò được quản trị viên cấp sau khi đăng ký',
                  prefixIcon: Icon(Icons.lock_person_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _handleRegister,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Đăng ký'),
        ),
      ],
    );
  }

  Future<void> _handleRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);

    final result = await context.read<AuthProvider>().registerWithFirebase(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          role: _selectedRole,
        );

    if (!mounted) return;

    if (!result.success) {
      setState(() => _submitting = false);
      AppToast.error(
        context,
        result.message ?? 'Không thể tạo tài khoản.',
      );
      return;
    }

    Navigator.of(context).pop(_emailController.text.trim());
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Khôi phục mật khẩu'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập email đã đăng ký. Hệ thống sẽ gửi liên kết để bạn tạo mật khẩu mới.',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _controller,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email tài khoản',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: _LoginScreenState._validateEmail,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _handleReset,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Gửi liên kết'),
        ),
      ],
    );
  }

  Future<void> _handleReset() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);

    final result = await context
        .read<AuthProvider>()
        .resetPasswordWithFirebase(_controller.text.trim());

    if (!mounted) return;

    if (!result.success) {
      setState(() => _submitting = false);
      AppToast.error(
        context,
        result.message ?? 'Không thể gửi liên kết khôi phục.',
      );
      return;
    }

    Navigator.of(context).pop(true);
  }
}
