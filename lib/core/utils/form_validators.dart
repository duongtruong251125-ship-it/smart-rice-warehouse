abstract final class FormValidators {
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
