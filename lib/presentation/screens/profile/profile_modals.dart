import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/logic/models/user_model.dart';
import 'package:smart_rice_warehouse/logic/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/logic/view_models/profile_view_model.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';
import 'package:smart_rice_warehouse/presentation/utils/app_toast.dart';
import 'package:smart_rice_warehouse/presentation/widgets/confirmation_dialog.dart';

class UserManagementSheet extends StatelessWidget {
  const UserManagementSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final users = auth.managedUsers;
    final currentId = auth.currentUser?.id;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Quản lý nhân sự & Phân quyền',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Đồng bộ quyền hạn Quản trị viên và Nhân viên kho (Mật khẩu mặc định: 123456)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final u = users[index];
                  final isSelf = u.id == currentId;
                  final isUserAdmin = u.role == 'admin';

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: isUserAdmin
                                  ? AppTheme.primaryLight
                                  : const Color(0xFFDBEAFE),
                              child: Icon(
                                isUserAdmin
                                    ? Icons.admin_panel_settings_rounded
                                    : Icons.badge_rounded,
                                size: 18,
                                color: isUserAdmin
                                    ? AppTheme.primaryColor
                                    : const Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    u.name,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    u.email,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelf)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Tôi',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            DropdownButton<String>(
                              value: u.role,
                              underline: const SizedBox.shrink(),
                              isDense: true,
                              items: const [
                                DropdownMenuItem(
                                  value: 'admin',
                                  child: Text(
                                    'Quản trị viên',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'staff',
                                  child: Text(
                                    'Nhân viên kho',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                              onChanged: isSelf
                                  ? null
                                  : (role) async {
                                      if (role == null) return;
                                      final res = await auth.updateUserAccess(
                                        uid: u.id,
                                        role: role,
                                        isActive: u.isActive,
                                      );
                                      if (context.mounted && res.success) {
                                        AppToast.success(
                                          context,
                                          'Đã đổi quyền ${u.name} thành ${role == 'admin' ? 'Quản trị viên' : 'Nhân viên kho'}',
                                        );
                                      }
                                    },
                            ),
                            if (!isSelf)
                              TextButton.icon(
                                icon: Icon(
                                  u.isActive
                                      ? Icons.lock_outline_rounded
                                      : Icons.lock_open_rounded,
                                  size: 14,
                                  color: u.isActive
                                      ? AppTheme.dangerColor
                                      : AppTheme.primaryColor,
                                ),
                                label: Text(
                                  u.isActive ? 'Khóa' : 'Kích hoạt',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: u.isActive
                                        ? AppTheme.dangerColor
                                        : AppTheme.primaryColor,
                                  ),
                                ),
                                onPressed: () async {
                                  final nextActive = !u.isActive;
                                  final confirm = await showConfirmationDialog(
                                    context: context,
                                    title: nextActive
                                        ? 'Kích hoạt tài khoản'
                                        : 'Khóa tài khoản',
                                    message: nextActive
                                        ? 'Bạn có muốn mở khóa cho ${u.name} không?'
                                        : 'Bạn có chắc muốn khóa ${u.name} không? Người này sẽ không thể đăng nhập.',
                                  );
                                  if (confirm != true || !context.mounted) {
                                    return;
                                  }
                                  final res = await auth.updateUserAccess(
                                    uid: u.id,
                                    role: u.role,
                                    isActive: nextActive,
                                  );
                                  if (context.mounted && res.success) {
                                    AppToast.success(
                                      context,
                                      nextActive
                                          ? 'Đã kích hoạt tài khoản ${u.name}'
                                          : 'Đã khóa tài khoản ${u.name}',
                                    );
                                  }
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PersonalInformationSheet extends StatefulWidget {
  const PersonalInformationSheet({
    super.key,
    required this.user,
  });

  final UserModel? user;

  @override
  State<PersonalInformationSheet> createState() =>
      _PersonalInformationSheetState();
}

class _PersonalInformationSheetState extends State<PersonalInformationSheet> {
  late final TextEditingController _nameController;
  File? _selectedImage;
  final _picker = ImagePicker();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.user?.name ?? 'Admin Quản Lý');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _handleSave() async {
    final updatedName = _nameController.text.trim();
    if (updatedName.isEmpty) {
      AppToast.error(context, 'Họ và tên không được để trống.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final auth = context.read<AuthProvider>();
      final result = await ProfileViewModel().save(
        auth: auth,
        name: updatedName,
        original: widget.user,
        imagePath: _selectedImage?.path,
      );

      if (!mounted) return;
      if (!result.success) {
        AppToast.error(
          context,
          result.message ?? 'Không thể cập nhật hồ sơ',
        );
        return;
      }

      Navigator.of(context).pop();
      AppToast.success(
        context,
        'Đã cập nhật hồ sơ và ảnh đại diện!',
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cập nhật Hồ sơ',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppTheme.primaryLight,
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : null,
                      child: _selectedImage == null
                          ? const Icon(Icons.person,
                              size: 40, color: AppTheme.primaryColor)
                          : null,
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        color: AppTheme.secondaryColor,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Họ và tên',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _isSaving ? null : _handleSave,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Lưu thông tin',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final current = _currentPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập đầy đủ các trường mật khẩu';
      });
      return;
    }
    if (newPass.length < 6) {
      setState(() {
        _errorMessage = 'Mật khẩu mới phải có ít nhất 6 ký tự';
      });
      return;
    }
    if (newPass != confirm) {
      setState(() {
        _errorMessage = 'Mật khẩu xác nhận không khớp';
      });
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final auth = context.read<AuthProvider>();
      final result = await auth.changePasswordWithFirebase(
        current: current,
        replacement: newPass,
      );

      if (!mounted) return;
      if (!result.success) {
        setState(() {
          _errorMessage = result.message ?? 'Mật khẩu hiện tại không chính xác';
        });
        return;
      }

      Navigator.of(context).pop();
      AppToast.success(context, 'Đổi mật khẩu thành công!');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Đổi mật khẩu',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (_errorMessage != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.dangerBgColor(context),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppTheme.dangerBorderColor(context)),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: AppTheme.dangerTextColor(context),
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _currentPasswordController,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: 'Mật khẩu hiện tại',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _newPasswordController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'Mật khẩu mới',
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscureNew ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Xác nhận mật khẩu mới',
                prefixIcon: const Icon(Icons.check_circle_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _isSubmitting ? null : _handleSubmit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Xác nhận đổi',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
