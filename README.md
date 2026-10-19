# Smart Rice Warehouse

Ứng dụng mặc định chạy ở chế độ cục bộ, dùng SQLite và tự nạp một lần bộ dữ
liệu kho gạo mẫu trong `lib/data/mock_data.dart`. Không cần Firebase để đăng
nhập, xem hoặc chỉnh sửa dữ liệu.

Tài khoản mẫu:

- Email: `admin@gmail.com`
- Mật khẩu: `123456`

Chạy chế độ cục bộ:

```sh
flutter run
```

Chỉ bật Firebase khi chủ động truyền biến build sau:

```sh
flutter run --dart-define=USE_FIREBASE=true
```

Ở chế độ cục bộ, thay đổi được lưu trên thiết bị bằng SQLite. Chúng không tự
đồng bộ sang điện thoại khác.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
