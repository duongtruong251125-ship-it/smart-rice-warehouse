# Smart Rice Warehouse

Ứng dụng Flutter quản lý kho gạo. Ngoài chế độ demo, Supabase là dịch vụ cloud
cho đăng nhập, hồ sơ, danh mục, kho và các giao dịch tồn.

## Chạy ứng dụng

Demo cục bộ, không kết nối cloud:

```sh
flutter run --dart-define=DEMO_MODE=true
```

Chạy với project cloud mặc định:

```powershell
$env:SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_...'
flutter run
```

URL project đã có mặc định trong ứng dụng. Chỉ dùng publishable key trong app;
không truyền secret/service-role key vào Flutter hoặc lưu vào Git.

Tài khoản local mẫu chỉ dùng trong demo chủ động. Dữ liệu demo được lưu bằng
SQLite và không đồng bộ sang thiết bị khác. Không dùng demo để quản lý tồn kho
thật.

## Cấu trúc mã nguồn

- `lib/presentation/`: giao diện, widget, theme và routes.
- `lib/logic/`: Provider, ViewModel, service, model và validation.
- `lib/data/`: Supabase, SQLite, đồng bộ và dữ liệu mẫu.
- `supabase/`: migrations, kiểm thử SQL và Edge Functions.

Xem [ARCHITECTURE.md](ARCHITECTURE.md) để biết ranh giới giữa các tầng.
Xem [supabase/README.md](supabase/README.md) để chạy database local và test.
Tình trạng dữ liệu tồn lịch sử nằm trong
[supabase/MIGRATION_DATA_STATUS.md](supabase/MIGRATION_DATA_STATUS.md).
