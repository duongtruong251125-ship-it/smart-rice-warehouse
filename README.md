# Smart Rice Warehouse

Ứng dụng mặc định xác thực bằng Firebase. Hồ sơ Firestore quyết định chức vụ và
trạng thái kích hoạt. Nếu xác thực cloud hoặc kiểm tra hồ sơ thất bại, ứng dụng
không cho đăng nhập bằng mật khẩu local hay tài khoản mẫu.

Tài khoản mẫu (chỉ trong demo được bật chủ động):

- Email: `admin@gmail.com`
- Mật khẩu: `123456`

Chạy demo cục bộ, không kết nối Firebase:

```sh
flutter run --dart-define=DEMO_MODE=true
```

Chạy cloud (mặc định):

```sh
flutter run
```

`USE_FIREBASE` điều khiển backend nghiệp vụ; `USE_FIREBASE=false` không bật demo
và không tắt xác thực Firebase. Tắt đồng bộ nền cũng không bỏ qua xác thực cloud.
Ở chế độ demo, dữ liệu được lưu bằng SQLite và không đồng bộ sang thiết bị khác.
Không sử dụng bản demo để bảo vệ dữ liệu nghiệp vụ thực tế.

Hồ sơ được kiểm tra từ máy chủ khi khôi phục phiên/đăng nhập. Khi đang online,
thay đổi role/isActive từ Firestore được áp dụng qua listener; tài khoản bị khóa
hoặc mất quyền sẽ bị đưa về đăng nhập. Rules là lớp chặn yêu cầu cloud cuối cùng.

Kiểm tra rules cục bộ (Node >=20, Java >=21, Firebase CLI):

```sh
cd test/firestore_rules
npm ci
cd ../..
firebase emulators:exec --config firebase.auth-test.json --project demo-smart-rice-auth --only firestore "node --test test/firestore_rules/auth.rules.test.mjs"
```

Bộ test chỉ chấp nhận endpoint `127.0.0.1:8089` và project demo, không chạy trên
Firebase thật. Các thay đổi rules chưa được deploy bằng lệnh kiểm tra này.

## Cấu trúc mã nguồn

- `lib/presentation/`: giao diện, widget, theme và routes.
- `lib/logic/`: ViewModel, Provider, service, model và validation.
- `lib/data/`: SQLite, Firebase, repository và dữ liệu mẫu.

Xem [ARCHITECTURE.md](ARCHITECTURE.md) để biết sửa chức năng ở đâu và cách nối các tầng.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
