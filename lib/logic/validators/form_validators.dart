abstract final class FormValidators {
  static double? parseNumber(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Vui lòng nhập email';
    return optionalEmail(value);
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (value.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
    return null;
  }

  static String? number(String? value, String fieldName,
      {bool positive = false}) {
    final requiredError = required(value, fieldName);
    if (requiredError != null) return requiredError;
    final parsed = parseNumber(value!);
    if (parsed == null || !parsed.isFinite) {
      return '$fieldName phải là số hợp lệ';
    }
    if (positive && parsed <= 0) return '$fieldName phải lớn hơn 0';
    if (parsed < 0) return '$fieldName không được nhỏ hơn 0';
    return null;
  }

  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập $fieldName';
    }
    return null;
  }

  static String? phone(String? value) {
    final requiredError = required(value, 'số điện thoại');
    if (requiredError != null) {
      return requiredError;
    }

    final phonePattern = RegExp(r'^[0-9+ .-]{8,15}$');
    if (!phonePattern.hasMatch(value!.trim())) {
      return 'Số điện thoại không đúng định dạng';
    }
    return null;
  }

  static String? optionalEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return null;
    }

    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailPattern.hasMatch(email)) {
      return 'Email không đúng định dạng';
    }
    return null;
  }
}
