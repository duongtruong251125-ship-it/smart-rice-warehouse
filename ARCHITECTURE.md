# Kiến trúc dự án

## Các lớp chính

| Trách nhiệm | Thư mục |
| --- | --- |
| Màn hình, widget, điều hướng, giao diện | `lib/presentation/` |
| Provider, ViewModel, quy tắc nghiệp vụ, model và hợp đồng | `lib/logic/` |
| Supabase, SQLite cục bộ, đồng bộ và lưu ảnh | `lib/data/` |
| Khởi tạo ứng dụng và nối dependency | `lib/bootstrap_app.dart`, `lib/app.dart` |
| Schema, migration, RLS, RPC và Edge Functions | `supabase/` |

Luồng phụ thuộc chính:

`Presentation → Logic contracts/providers → Data repositories/services → Supabase hoặc SQLite`

Giữ Provider/ChangeNotifier và các ranh giới hiện có. Giao diện không truy cập
trực tiếp repository hay SQLite. Logic không nhận `BuildContext`, điều hướng
hoặc tạo widget.

## Dữ liệu và quyền truy cập

- Ngoài `DEMO_MODE`, ứng dụng dùng Supabase Auth và repository Supabase cho hồ
  sơ, danh mục, kho và giao dịch.
- SQLite giữ dữ liệu cục bộ cần cho cache/thiết bị; dữ liệu này không được dùng
  làm nguồn tồn kho thật hoặc tự tải lên Supabase.
- PostgreSQL RLS/RPC kiểm tra quyền và thực hiện các thay đổi tồn kho nguyên tử.
- Edge Function `admin-confirm-email` chỉ cho admin đang hoạt động xác minh email
  nhân viên sau bước xác nhận trong giao diện.
- Mẫu và tài khoản local chỉ bật trong `DEMO_MODE`.

## Phát triển và kiểm tra

1. Đặt repository Supabase trong `lib/data/` và khai báo hợp đồng trong `lib/logic/`.
2. Nối nghiệp vụ qua Provider/ViewModel; giữ toast và điều hướng ở presentation.
3. Thêm unit/widget/integration test cho hành vi thay đổi.
4. Chạy `dart format`, `flutter analyze` và `flutter test` phù hợp với phạm vi.

`test/architecture_boundaries_test.dart` bảo vệ các ranh giới import của ứng dụng.
