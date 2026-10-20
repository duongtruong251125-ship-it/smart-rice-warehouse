# Tổ chức mã nguồn

## Sửa ở đâu?

| Việc cần làm | Thư mục |
| --- | --- |
| Layout, nút bấm, dialog, màn hình | `lib/presentation/screens/` |
| Widget dùng chung | `lib/presentation/widgets/` |
| Màu sắc, font, sáng/tối | `lib/presentation/theme/` |
| Route và điều hướng | `lib/presentation/routes/` |
| Trạng thái và dữ liệu cho màn hình | `lib/logic/view_models/`, `lib/logic/providers/` |
| Quy tắc nghiệp vụ, tạo phiếu, tổng hợp số liệu | `lib/logic/services/` |
| Kiểm tra dữ liệu nhập | `lib/logic/validators/` |
| Model và hợp đồng dùng chung | `lib/logic/models/`, `lib/logic/contracts/` |
| SQLite, lưu ảnh, cấu hình thiết bị | `lib/data/local/` |
| Firebase Auth, migration, cấu hình Firestore | `lib/data/firebase/` |
| Truy cập Firestore, mapper, repository | `lib/data/repositories/` |
| Dữ liệu mẫu | `lib/data/mock/` |
| Định dạng ngày, số, tiền | `lib/core/utils/` |
| Khởi tạo và nối các thành phần | `lib/bootstrap_app.dart`, `lib/app.dart` |

## Cách nối các phần

`Screen → ViewModel / Provider → Service / Repository → SQLite / Firebase`

Giữ Provider/ChangeNotifier hiện có. Provider quản lý các tập dữ liệu dùng chung;
không đổi tên hàng loạt thành ViewModel vì chúng phục vụ nhiều màn hình.
ViewModel của Báo cáo và Dashboard chuẩn bị dữ liệu khi nguồn thay đổi;
trạng thái giao diện như tab đang chọn, controller ô nhập và dialog ở lại widget.

Giao diện gọi API của logic, nhận kết quả và hiển thị thông báo hoặc điều hướng.
Logic không nhận BuildContext, không gọi Navigator, không tạo Flutter widget.
Giao diện không import trực tiếp SQLite, Firebase repository hoặc lớp lưu ảnh.
Màu biểu đồ thuộc presentation; dữ liệu số liệu biểu đồ thuộc logic.

Các điểm chính:

- `inventory_form_service.dart`: tạo phiếu nhập, lô hàng, phiếu xuất, đổi đơn vị,
  tính tiền. OCR sử dụng cùng đường tạo phiếu nhập.
- `catalog_form_service.dart`: lưu gạo, khách hàng, nhà cung cấp, đặc tính,
  vị trí kho và điều phối ảnh sản phẩm.
- `damage_form_service.dart`: kiểm tra số lượng, lưu ảnh và gọi logic báo hỏng.
- `reports_view_model.dart`, `report_service.dart`: lọc tháng, thống kê, cơ cấu tồn,
  dữ liệu biểu đồ và lịch sử giá trị tồn.
- `dashboard_view_model.dart`, `dashboard_service.dart`: số liệu Dashboard,
  danh sách hoạt động và biểu đồ tuần.
- `login_view_model.dart`, `profile_view_model.dart`: điều phối đăng nhập,
  cập nhật hồ sơ và ảnh đại diện.
- `inventory_check_provider.dart`: phiên kiểm kê, chênh lệch và cập nhật tồn.

Đây là phân tầng thực dụng, không phải chuyển toàn bộ sang Clean Architecture.
Một số Provider vẫn dùng các lớp dữ liệu hiện có. Việc khởi tạo backend nằm ở
bootstrap; refactor này giữ nguyên API và chính sách local/Firebase hiện tại.

## Thêm hoặc sửa chức năng

1. Viết quy tắc nghiệp vụ trong `logic/`, dùng đầu vào Dart và kết quả có kiểu.
2. Đưa đọc/ghi dữ liệu vào `data/`, tái sử dụng repository hiện có.
3. Nối logic với widget ở `presentation/`; giữ toast và Navigator tại đây.
4. Thêm test cho hành vi nghiệp vụ hoặc luồng người dùng bị ảnh hưởng.
5. Chạy `dart format lib test`, `flutter analyze` và `flutter test`.

`test/architecture_boundaries_test.dart` kiểm tra các ranh giới import để tránh
đưa logic và lưu trữ trở lại màn hình trong những lần sửa sau.

## Xác thực và phân quyền

- Cloud là mặc định. `AuthProvider` không dùng dữ liệu SQLite hoặc tài khoản mẫu
  để cấp quyền cloud; Firebase lỗi sẽ đóng quyền truy cập.
- Chỉ `DEMO_MODE=true` mới bật tài khoản local/mẫu. Truyền repository cloud vào
  Provider luôn vô hiệu hóa demo, kể cả khi cờ demo bị cấu hình nhầm.
- `USE_FIREBASE` và cài đặt đồng bộ nền chỉ điều khiển dữ liệu nghiệp vụ,
  không quyết định việc xác thực có được bỏ qua hay không.
- Repository kiểm tra hồ sơ bằng Source.server khi đăng nhập/khôi phục phiên;
  listener chỉ nhận hồ sơ do server xác nhận và truyền lỗi về logic.
- Đăng nhập/khôi phục phiên chỉ đọc hồ sơ: không tự tạo pending hoặc sửa role.
  Chỉ luồng đăng ký chủ động được tạo hồ sơ pending. Mapper yêu cầu role đúng
  nguyên văn `admin`/`staff` và isActive kiểu bool; không chuẩn hóa role.
- AuthProfileDiagnostics phân loại thiếu hồ sơ, UID lệch, role/dữ liệu sai,
  trạng thái vô hiệu hóa và lỗi mạng/quyền. Thông báo không chứa lỗi SDK thô.
  isActive=false ở phiên mới không phân biệt được chưa kích hoạt với đã khóa;
  thay đổi từ phiên đã hoạt động sang false được báo là bị khóa.
- `AuthRouteGuard` gỡ nội dung bảo vệ khi phiên hết hiệu lực;
  `AuthSessionGuard` xóa lịch sử điều hướng khi đăng xuất hoặc bị khóa.
- `updateUserAccess` đợi server thành công trước khi thay đổi trạng thái local.
  Security Rules kiểm tra role/isActive và bảo vệ email/createdAt của hồ sơ.

## Ranh giới tồn kho tin cậy — Task 1

- Cloud dùng `CallableInventoryTransactions` qua hợp đồng `InventoryTransactions`;
  Provider không phụ thuộc Functions SDK. Demo/local giữ luồng cũ.
- Bốn callable trong `functions/` kiểm tra UID Firebase Auth và hồ sơ Firestore
  hiện tại, rồi ghi lô–phiếu–sổ biến động trong một transaction phía server.
- Rules cấm client ghi trực tiếp tồn kho, phiếu, kiểm kê, sổ biến động, giữ chỗ mã lô.
  Chuyển vị trí dùng `BatchLocationWriter`, chỉ patch các trường vị trí.
- `InventoryTransactionRepository` trực tiếp Firestore chỉ giữ để kiểm thử hồi quy,
  không được dùng làm fallback runtime. Lô `qualityHold` không được xuất ở FEFO,
  kiểm tra khả dụng, planner và callable.
- Chưa deploy. Phải phát hành Functions/rules/app đồng bộ; migration stock từ
  client cũ sẽ bị chặn. Xem `functions/README.md` và xử lý migration ở Task 2.

## Xác nhận thao tác và vòng đời listener — Task 3

- CatalogFormService trả Future cho thêm/chuyển vị trí; màn hình chỉ đóng sau
  server acknowledgement và giữ đầu vào khi lỗi. Không gọi wrapper bool local
  để khởi chạy ghi cloud bằng unawaited.
- FirestoreCollectionRepository chỉ phát snapshot không có pending writes;
  listener thay thế được tuần tự hóa và lỗi giữ mã RepositoryException.
- WarehouseProvider/BatchProvider dùng lifecycle guard và generation guard;
  retry/dispose không để callback cũ ghi đè dữ liệu mới. Số lô theo snapshot
  xác nhận, không theo một thao tác chuyển vị trí đang chờ.
- Refresh thủ công chỉ đọc server, không phải migration/upload SQLite.

## Dự báo tồn kho — Task 5

- ForecastService tính cửa sổ 7 ngày lịch, từ hôm nay trừ 6 ngày đến hết hôm
  nay; bỏ giờ khi so sánh, dùng constructor ngày để qua tháng/năm an toàn.
- Phiếu có ngày tương lai bị loại cả ở cửa sổ 7 ngày và nhánh fallback.
- Giữ nguyên fallback tổng lịch sử hợp lệ chia 30, ngưỡng tốc độ bằng 0,
  công thức số ngày còn hàng, trạng thái và đề xuất nhập. API/Provider không đổi.
