# Tiến độ tách giao diện và logic

## Quy ước làm việc

- Tiếp tục quy trình codex-token-saver đã được người dùng chọn.
- Mỗi lượt thực hiện một task người dùng yêu cầu; giữ Provider/ChangeNotifier.
- Đọc ARCHITECTURE.md, kiểm tra git status và các symbol liên quan trước khi sửa.
- Giữ controller, dialog, theme và điều hướng ở presentation.
- Kết thúc task bằng kết quả kiểm tra thực tế, task còn lại và prompt sao chép.
- Không deploy Firebase khi chưa có chấp thuận rõ ràng cho lần deploy đó.

## Task 1 — Đã hoàn thành

- Chuyển screens/widgets/theme/routes sang presentation.
- Chuyển models/providers/services/validators sang logic; ThemeProvider thuộc
  presentation/theme vì quản lý ThemeMode của Flutter.
- Gom SQLite/settings/ảnh vào data/local; Firebase/migration vào data/firebase;
  Firestore mapper và repository vào data/repositories.
- Đưa hợp đồng repository, settings và inventory transaction vào logic/contracts.
- Tách tổng hợp Báo cáo và Dashboard thành service/ViewModel.
- Tách tạo phiếu nhập/xuất, OCR nhập kho và lưu danh mục khỏi màn hình.
- Tách điều phối đăng nhập, hồ sơ và lưu ảnh; tách kiểm tra báo hỏng.
- Thêm test ranh giới import và test logic không cần widget tree.
- Sửa test điều hướng để đóng cảnh báo modal và xác nhận tab thực sự mở;
  sửa overflow thẻ sức chứa Kho hàng tại 320px được phát hiện qua test này.
- Cập nhật import của source/test, tài liệu và ignore cache Kotlin sinh khi build.

Kiểm tra: formatter sạch; flutter analyze không có issue; toàn bộ 98 test pass;
flutter build apk --debug --no-pub thành công. Toolchain Android còn cảnh báo
phiên bản Gradle/AGP/Kotlin sắp hết hỗ trợ. Chưa chạy Firebase emulator hoặc
kiểm thử trên thiết bị thật. Không thay đổi Firebase rules hay deploy.

## Task 2 — Đã hoàn thành

- Tạo `ImportFormViewModel`, `ExportFormViewModel`, `OcrInvoiceViewModel` trong
  `lib/logic/view_models/`.
- Tách toàn bộ trạng thái lựa chọn gạo/lô/NCC/khách hàng, sinh gợi ý mã lô,
  chọn ngày mặc định, quy đổi đơn vị (kg, bao, tạ, tấn), phân bổ FEFO preview,
  validation nghiệp vụ và điều phối submit khỏi các màn hình `import_form_screen.dart`,
  `export_form_screen.dart` và `ocr_prototype_screen.dart`.
- Tái sử dụng `InventoryFormService` và `OcrService` trong ViewModel; màn hình
  không còn import trực tiếp `InventoryFormService`.
- Giữ `TextEditingController`, DatePicker dialog, BottomSheet FEFO, Toast và
  Navigator ở `presentation/`.
- Thêm `test/form_view_models_test.dart` với 13 test mới bao phủ nhập lô mới/bổ sung,
  đổi đơn vị, preview FEFO, OCR extraction, submit và xử lý lỗi submit.

Kiểm tra: formatter sạch; `flutter analyze` không có issue; toàn bộ 111 test pass
(tăng từ 98 lên 111 test); test ranh giới kiến trúc `architecture_boundaries_test.dart`
tiếp tục đạt 100%. Không thay đổi Firebase rules hay deploy.

## Task 3 — Đã hoàn thành

- Tạo các ViewModel chuyên biệt trong `lib/logic/view_models/`:
  - `BatchListViewModel`: Quản lý query, bộ lọc (Tất cả, ST25, Jasmine, Bao 50kg, Cần ưu tiên xuất, Còn hàng), đếm badge ưu tiên xuất theo hạn dùng (FIFO/30 ngày), tính tổng số lượng kg/tấn/bao, và hỗ trợ xuất Excel.
  - `InventoryViewModel`: Quản lý query, bộ lọc (Tất cả, ST25, Jasmine, Bao 50kg, Cần nhập thêm, Đủ hàng), đếm badge cảnh báo tồn tối thiểu, lọc và tính tổng chỉ số tồn kho.
  - `WarehouseHubViewModel`: Tổng hợp các chỉ số sức chứa (tổng kg, tấn, bao, phần trăm tỷ lệ sức chứa Silo) và thống kê số lượng thực thể từ 6 providers cho thẻ Warehouse Hub.
  - `InventoryCheckViewModel`: Quản lý phiên kiểm kê (bảo đảm phiên hoạt động, lưu chênh lệch lô hàng với `addOrUpdateItem`, và điều phối hoàn tất phiên cập nhật tồn kho).
  - `DamageFormViewModel`: Quản lý danh sách lô khả dụng, nguyên nhân hư hỏng, ảnh chụp minh chứng, validate số lượng và submit báo hỏng qua `DamageProvider` & `BatchProvider`.
- Mở rộng `CatalogFormService` trong `lib/logic/services/`:
  - Điều phối nghiệp vụ đa-provider: kiểm tra ràng buộc tham chiếu trước khi xóa gạo (`deleteRice`), nhà cung cấp (`deleteSupplier`), và khách hàng (`deleteCustomer`).
  - Điều phối chuyển vị trí kho cho lô hàng (`assignBatchLocation`).
- Cập nhật các màn hình trong `lib/presentation/screens/`:
  - `batch_list_screen.dart`, `batch_detail_screen.dart`, `inventory_screen.dart`, `warehouse_hub.dart`, `inventory_check_screen.dart`, `damage_form_screen.dart`, `rice_list_screen.dart`, `supplier_list_screen.dart`, `customer_list_screen.dart`.
  - Màn hình giữ nguyên giao diện, chuyển toàn bộ logic tính toán, lọc, sắp xếp, và kiểm tra ràng buộc chéo sang logic.
- Thêm `test/warehouse_management_logic_test.dart` với 9 unit tests bao phủ:
  - Lọc và tính metrics cho BatchListViewModel và InventoryViewModel.
  - Tổng hợp metrics và sức chứa kho trong WarehouseHubViewModel.
  - Ghi nhận chênh lệch và hoàn thành phiên kiểm kê trong InventoryCheckViewModel.
  - Validate và giảm tồn lô hàng khi báo hỏng trong DamageFormViewModel.
  - Chặn xóa có tham chiếu và chuyển vị trí kho trong CatalogFormService.

Kiểm tra:
- Formatter sạch (`dart format`).
- `flutter analyze`: Không có issue (0 errors, 0 warnings).
- Toàn bộ 120/120 tests pass (tăng từ 111 lên 120 test).
- `test/architecture_boundaries_test.dart` đạt 100% (presentation không truy cập data; logic/data không import Flutter UI).
- Không thay đổi Firebase rules hay deploy.

## Task 4 — Đã hoàn thành

- Trừu tượng hóa các hợp đồng mới trong `lib/logic/contracts/`:
  - `authentication_service.dart`: Định nghĩa `AuthenticationService`, `AuthenticatedUser`, `AuthResult`.
  - `media_storage.dart`: Định nghĩa `MediaStorage` (`saveImagePermanently`, `deleteImageIfExists`).
  - `initial_data_provider.dart`: Định nghĩa `InitialDataProvider` và `DefaultDataRegistry`.
- Triển khai hợp đồng tại tầng Data:
  - `FirebaseAuthService` triển khai `AuthenticationService`.
  - `LocalMediaStorage` triển khai `MediaStorage`.
  - `MockInitialDataProvider` triển khai `InitialDataProvider`.
- Tách hoàn toàn các phụ thuộc dữ liệu cụ thể trong `lib/logic/`:
  - `AuthProvider` nhận `AuthenticationService` qua DI (fallback `_NoOpAuthenticationService`), không còn import `firebase_auth_service.dart` hay `mock_data.dart`.
  - `MediaService` ủy thác toàn bộ cho `MediaStorage` (`MediaService.initialize(...)`), không còn import tĩnh `image_storage_service.dart`.
  - Toàn bộ 10 Provider danh mục và giao dịch (`BatchProvider`, `RiceProvider`, `SupplierProvider`, `CustomerProvider`, `WarehouseProvider`, `RiceCharacteristicProvider`, `DamageProvider`, `ImportProvider`, `ExportProvider`, `InventoryCheckProvider`) sử dụng `DefaultDataRegistry.provider` để fallback thay vì trực tiếp import `mock_data.dart`.
  - `lib/logic/` không còn bất kỳ dòng import nào từ `package:smart_rice_warehouse/data/`.
- Nối ghép và khởi tạo tại `lib/bootstrap_app.dart` và `lib/app.dart`:
  - Nối `FirebaseAuthService.instance` qua interface `AuthenticationService`.
  - Khởi tạo `MediaService.initialize(const LocalMediaStorage())`.
  - Gán `DefaultDataRegistry.provider = const MockInitialDataProvider()`.
- Tăng cường kiểm tra kiến trúc và kiểm thử DI:
  - Thêm kiểm tra `logic never depends on data layer` và `contracts never depend on external database, cloud, or device platform drivers` trong `test/architecture_boundaries_test.dart` (5/5 tests pass).
  - Tạo cấu hình tự động cho môi trường test runner tại `test/flutter_test_config.dart`.
  - Tạo `test/logic_dependency_injection_test.dart` với fake contracts (`FakeAuthService`, `FakeUserProfileRepository`, `FakeMediaStorage`, `FakeInitialDataProvider`) chứng minh logic hoạt động độc lập và cô lập tuyệt đối khỏi các driver thiết bị, Firebase hay dữ liệu mẫu.

Kiểm tra:
- Formatter sạch (`dart format lib test`).
- `flutter analyze`: Không có issue (0 errors, 0 warnings).
- Toàn bộ 125/125 tests pass (tăng từ 120 lên 125 test).
- `test/architecture_boundaries_test.dart` đạt 100% ranh giới kiến trúc.
- `flutter build apk --debug` thành công. Không thay đổi Firebase rules hay deploy.

## Task 5 — Đã hoàn thành

- Xác minh và sửa lỗi seed/migration bảo toàn dữ liệu cũ:
  - Cập nhật [AppDatabase.seedLocalDataIfNeeded](file:///c:/Users/duong/Downloads/smart-rice-warehouse/lib/data/local/app_database.dart):
    - Khi `installedVersion == 0`: Kiểm tra nếu bảng `app_state` đã chứa dữ liệu của người dùng trước đó (thiếu version marker), ghi version marker và tuyệt đối KHÔNG ghi đè dữ liệu mẫu `MockData`.
    - Khi di chuyển lên version 2 (`installedVersion < 2`): Chỉ bổ sung đường dẫn ảnh cho các bản ghi gạo mẫu còn thiếu, giữ nguyên gạo do người dùng tạo.
    - Khi di chuyển lên version 3 (`installedVersion < 3`): Chỉ cập nhật đường dẫn ảnh mẫu nếu có bản ghi mẫu trùng ID; loại bỏ hoàn toàn việc gọi `addAll` chèn các `initialDamageReports` mẫu vào lịch sử thật của người dùng.
  - Tách độc lập [SeedMigrationPolicy](file:///c:/Users/duong/Downloads/smart-rice-warehouse/lib/data/local/seed_migration_policy.dart) trong `lib/data/local/` để kiểm thử tự động các quy tắc bảo toàn dữ liệu mà không phụ thuộc SQLite C platform driver.
- Chuẩn hóa cờ `useFirebaseBackend` và cô lập Cloud Auth:
  - Trong [lib/bootstrap_app.dart](file:///c:/Users/duong/Downloads/smart-rice-warehouse/lib/bootstrap_app.dart): Cả `authUid` và `userProfiles` được bảo vệ nghiêm ngặt bằng điều kiện `firebaseReady && useFirebaseBackend`.
  - Khi `useFirebaseBackend == false` (mặc định cho offline): `userProfiles = null`, `AuthProvider` chạy hoàn toàn ở chế độ Local Authentication (`isCloudAuthEnabled = false`), không gọi Cloud Firestore hay Firebase Auth khi đăng nhập thông thường.
- Sửa xác nhận giao dịch online và báo đúng kết quả lỗi:
  - Chuyển toàn bộ các hàm giao dịch chính sang async `Future<bool>`:
    - [ImportProvider.createImportReceipt](file:///c:/Users/duong/Downloads/smart-rice-warehouse/lib/logic/providers/import_provider.dart)
    - [ExportProvider.createExportReceipt](file:///c:/Users/duong/Downloads/smart-rice-warehouse/lib/logic/providers/export_provider.dart)
    - [DamageProvider.createDamageReport](file:///c:/Users/duong/Downloads/smart-rice-warehouse/lib/logic/providers/damage_provider.dart)
    - [InventoryCheckProvider.completeSession](file:///c:/Users/duong/Downloads/smart-rice-warehouse/lib/logic/providers/inventory_check_provider.dart)
  - Loại bỏ hoàn toàn cơ chế `unawaited` tạo kết quả thành công giả tạo; `await` trực tiếp `transactionRepository` và bắt ngoại lệ (Exception/timeout/conflict/abort), gán thông điệp vào `errorMessage`, cập nhật trạng thái lỗi chính xác lên ViewModels và giao diện người dùng.
  - Cập nhật đồng bộ các ViewModels và Screens: [ImportFormViewModel](file:///c:/Users/duong/Downloads/smart-rice-warehouse/lib/logic/view_models/import_form_view_model.dart), [ExportFormViewModel](file:///c:/Users/duong/Downloads/smart-rice-warehouse/lib/logic/view_models/export_form_view_model.dart), [DamageFormViewModel](file:///c:/Users/duong/Downloads/smart-rice-warehouse/lib/logic/view_models/damage_form_view_model.dart), [InventoryCheckViewModel](file:///c:/Users/duong/Downloads/smart-rice-warehouse/lib/logic/view_models/inventory_check_view_model.dart), [OcrInvoiceViewModel](file:///c:/Users/duong/Downloads/smart-rice-warehouse/lib/logic/view_models/ocr_invoice_view_model.dart), [InventoryFormService](file:///c:/Users/duong/Downloads/smart-rice-warehouse/lib/logic/services/inventory_form_service.dart), [DamageFormService](file:///c:/Users/duong/Downloads/smart-rice-warehouse/lib/logic/services/damage_form_service.dart).
- Bộ test nâng cấp dữ liệu và lỗi giao dịch mới:
  - Tạo [test/data_upgrade_and_transaction_error_test.dart](file:///c:/Users/duong/Downloads/smart-rice-warehouse/test/data_upgrade_and_transaction_error_test.dart) bao gồm 8 unit tests:
    - Kiểm tra cô lập cờ backend và offline authentication.
    - Kiểm tra 4 lỗi giao dịch online (timeout, conflict, permission denied, abort) được bắt đúng, báo lỗi vào `errorMessage` và bảo toàn số lượng tồn kho nội bộ.
    - Kiểm tra bảo vệ database cũ không có marker version khỏi bị seed đè.
    - Kiểm tra nâng cấp danh mục gạo v1->v2 bảo toàn gạo người dùng tự tạo.
    - Kiểm tra nâng cấp báo hỏng v2->v3 không chèn dữ liệu mẫu vào lịch sử người dùng.

Kiểm tra:
- Formatter sạch (`dart format lib test`).
- `flutter analyze`: Không có issue (0 errors, 0 warnings, 0 lints).
- Toàn bộ 133/133 tests pass (tăng từ 125 lên 133 test).
- `test/architecture_boundaries_test.dart` đạt 100% ranh giới kiến trúc (5/5 tests pass).
- `flutter build apk --debug` thành công.
- Không deploy Firebase, giữ an toàn tuyệt đối cho môi trường cloud.

## Bổ sung bảo mật — Xác thực và phân quyền

Các thay đổi này thay thế mô tả chế độ xác thực local/cloud ở Task 5; không làm lại các bước refactor đã hoàn thành.

- Mặc định dùng cloud và đóng truy cập khi Firebase/hồ sơ máy chủ không sẵn sàng. Không fallback sang tài khoản local sau lỗi đăng nhập.
- Chỉ bật tài khoản mẫu chủ động bằng `--dart-define=DEMO_MODE=true`. Cờ backend và đồng bộ nền không còn chuyển xác thực sang demo.
- Firestore là nguồn duy nhất quyết định role/isActive: đọc hồ sơ từ server, bỏ snapshot cache/pending writes, không trộn tài khoản mẫu.
- Theo dõi khóa/xóa/hạ quyền tài khoản; xóa phiên và ngăn truy cập lại route bảo vệ. Chặn kết quả bất đồng bộ cũ khôi phục phiên/quyền.
- Cập nhật quyền chờ xác nhận Firestore, trả lỗi khi thất bại, không sửa quyền local lạc quan.
- Bổ sung hồi quy xác thực và kiểm thử Security Rules độc lập trong `test/firestore_rules/`, dùng cấu hình `firebase.auth-test.json` và project emulator `demo-smart-rice-auth`.
- Giữ Provider và ranh giới presentation/logic/data. Không deploy Firebase.

Công việc kế tiếp: rà soát migration/seed và giao dịch nhiều lô, bảo toàn dữ liệu thật; sau đó xử lý UI/UX theo đánh giá trước. Không thuộc phạm vi sửa xác thực lần này.

Kết quả xác minh bổ sung:
- `flutter analyze`: không có issue; toàn bộ 150/150 test Flutter thành công.
- Firestore Emulator: 8/8 test Security Rules thành công; không dùng project production.
- `flutter build apk --debug --no-pub`: thành công.
- Format các file Dart thuộc thay đổi này sạch. Kiểm tra không ghi toàn bộ `lib test` còn phát hiện 4 file ngoài phạm vi chưa đúng format; không chỉnh sửa chúng.
- Chưa chạy E2E Firebase Auth trên thiết bị thật, chưa deploy rules. Thu hồi quyền cần kết nối để nhận hồ sơ mới; Security Rules kiểm tra quyền tại máy chủ cho từng yêu cầu.

## Task 1 bảo vệ tồn kho — triển khai backend được người dùng duyệt

- Giữ hợp đồng InventoryTransactions/Provider và transaction planner hiện có;
  bổ sung adapter callable trong data, 4 Cloud Functions Node 22 trong functions/.
- Actor lấy từ UID đã xác thực, kiểm tra khóa Auth và role/isActive server-side;
  kiểm tra dữ liệu hữu hạn/không âm, tính lại chênh lệch, đối chiếu tồn mới nhất,
  chống xác nhận lặp, ghi lô–phiếu–biến động nguyên tử.
- Rules chỉ cho client đọc dữ liệu tồn kho và patch vị trí vào location hoạt động;
  cấm mọi ghi trực tiếp lô/phiếu/check/ledger/code reservation kể cả admin.
- Chặn qualityHold trong FEFO, tồn khả dụng, planner và server; thêm test hồi quy.
- Đã được duyệt mở rộng backend, chưa được duyệt và không thực hiện deploy.
- Release gate và giới hạn nằm trong functions/README.md. Task 2 phải xử lý seed,
  migration và đồng bộ, không khôi phục đường client ghi stock trực tiếp.

Kiểm tra Task 1:
- flutter analyze: không có issue; flutter build apk --debug --no-pub thành công.
- Toàn bộ 190/190 test Flutter đạt (8 test mới cho qualityHold/callable/location).
- 16/16 test backend qua endpoint Functions + Auth + Firestore Emulator đạt;
  10/10 test Security Rules đạt trên project demo-smart-rice-auth.
- Format toàn bộ lib/test sạch, Node syntax check và git diff --check sạch.
- npm audit production dependencies: 0 lỗ hổng tại thời điểm kiểm tra.
- Một lượt emulator timeout khi discovery SDK; đã chuyển khởi tạo sang onInit
  và chạy lại thành công, có cấu hình discovery timeout cho máy chậm.
- Không deploy, không ghi thử production. App Check, tải lớn, E2E trên thiết bị
  thật và quy trình phát hành Functions/rules/app chưa được kiểm chứng.

## Task 2 — Tách dữ liệu demo/local khỏi dữ liệu cloud thật và chuẩn hóa chính sách đồng bộ

- Tách hoàn toàn cơ sở dữ liệu local/demo và cloud:
  - Chỉ khởi tạo và seed dữ liệu mẫu khi cờ `DEMO_MODE=true` được bật chủ động (`WarehouseDataMode.demo`).
  - Cài đặt mới ở chế độ cloud/thật (`WarehouseDataMode.cloud` hoặc `local`) giữ cơ sở dữ liệu sạch, không tự động seed tồn kho mẫu và không upload dữ liệu mẫu lên Firestore.
  - Bảo toàn dữ liệu SQLite cũ: dữ liệu chưa có version marker được coi là dữ liệu thật của người dùng, không tự động xóa hoặc ghi đè dữ liệu theo ID trùng mẫu.
- Chuẩn hóa chính sách di chuyển dữ liệu cũ (Legacy Migration):
  - Chức năng di chuyển dữ liệu cũ chỉ có thể khởi chạy bởi tài khoản `admin` đang hoạt động (`isActive = true`), sau khi xác minh quyền ở cả tầng client (`FirebaseDataMigrationService`) lẫn trong giao dịch máy chủ (`migrateLegacyWarehouse` callable).
  - Quy tắc bảo toàn dữ liệu cloud: nếu bản ghi đã tồn tại trên Firestore, migration bỏ qua (`skip`) để giữ nguyên dữ liệu cloud mới hơn, không ghi đè.
  - Khởi tạo số dư đầu kỳ cho các lô hàng chuyển từ dữ liệu cũ: tự động đăng ký `batch_codes` và tạo biến động kho `stock_movements` dạng `migration` với `quantityDelta = quantity`.
  - Phân đoạn xử lý (chunking 20 bản ghi/bước), mã băm SHA-256 đối soát manifest, theo dõi cursor `nextIndex`, cho phép tiếp tục an toàn khi mạng gián đoạn và đảm bảo tính lũy thỏa (idempotency).
- Phân biệt rõ rệt giữa cờ đồng bộ nền và backend nghiệp vụ:
  - `BusinessSyncPolicy` điều khiển việc tạm dừng lắng nghe Firestore stream khi app vào background nếu người dùng tắt đồng bộ nền; không âm thầm chuyển hướng giao dịch cloud sang local.
  - Các giao dịch kho (nhập, xuất, báo hỏng, kiểm kê) luôn gọi Cloud Functions callable khi ở chế độ cloud; nếu mất mạng sẽ trả lỗi rõ ràng, không tự tạo cơ chế ghi offline thiếu đối soát.
  - Công tắc cài đặt trong `ProfileTab` có hiệu lực ngay lập tức với thông báo Toast minh bạch.
- Bộ kiểm thử toàn diện:
  - Phía Flutter: `test/demo_cloud_sync_policy_test.dart` và `test/data_upgrade_and_transaction_error_test.dart` kiểm chứng phân giải mode, cài mới sạch, bảo vệ database cũ, toggle sync nền và xử lý resume migration.
  - Phía Cloud Functions Emulator: `functions/test/legacy-migration.test.js` kiểm chứng từ chối unauthenticated/non-admin/unapproved, bảo toàn bản ghi cloud hiện có, đăng ký mã lô, tạo sổ kho đầu kỳ và chạy lại an toàn.

Kiểm tra Task 2:
- `flutter analyze`: Không có issue (0 errors, 0 warnings, 0 lints).
- Toàn bộ 200/200 test Flutter đạt (tăng từ 190 lên 200 test).
- 23/23 test Cloud Functions (16 inventory + 7 legacy migration) và 10/10 test Firestore Security Rules đạt trên emulator.
- Định dạng toàn bộ 190 file Dart sạch sẽ (`dart format lib test`).
- Không deploy Firebase, không ghi thử production.

## Task 3 — Kết quả thao tác và trạng thái đồng bộ đáng tin cậy

- Tái sử dụng CloudRefreshService của Task 2; bổ sung bắt lỗi flush local ở
  bootstrap và khóa gửi lặp/kiểm tra phiên cho thao tác refresh thủ công.
- Repository dùng restarting_repository_stream: hủy listener cũ xong mới mở
  listener thay thế, chặn callback thế hệ cũ, chuyển lỗi SDK/mapper thành
  RepositoryException giữ code/cause. Chỉ nhận snapshot không có pending writes.
- WarehouseProvider/BatchProvider tuần tự hóa retry, chặn callback sau dispose,
  giữ lỗi có cấu trúc. Các wrapper đồng bộ cho thêm/chuyển vị trí không được
  tự fire-and-forget thao tác cloud rồi trả thành công.
- CatalogFormService và màn hình thêm/chuyển vị trí await kết quả server;
  khóa nút/giữ đầu vào khi lỗi, chỉ đóng hộp thoại và báo thành công sau xác nhận.
  Số lô ở vị trí lấy theo snapshot lô đã xác nhận, không cập nhật lạc quan.
- Giữ nguyên điều kiện banner HomeTab: thông báo đã đồng bộ không được truyền
  vào errorMessage. Không đổi Provider, quyền/rules hay backend Task 1–2.

File thuộc Task 3:
- lib/data/repositories/firestore/{restarting_repository_stream.dart,
  firestore_collection_repository.dart,firestore_batch_repository.dart}
- lib/logic/providers/{lifecycle_notifier.dart,warehouse_provider.dart,
  batch_provider.dart,auth_provider.dart}
- lib/logic/services/catalog_form_service.dart; lib/bootstrap_app.dart
- lib/presentation/widgets/add_warehouse_location_dialog.dart
- lib/presentation/screens/{warehouse/warehouse_location_screen.dart,
  batch/batch_detail_screen.dart}
- test/sync_operation_reliability_test.dart; test/warehouse_management_logic_test.dart

Kiểm tra Task 3:
- flutter analyze: không có issue; build APK debug thành công.
- 211/211 test Flutter đạt, gồm 11 test hồi quy mới cho lỗi quyền/mạng,
  listener hủy chậm, retry, server thất bại/thành công và dispose khi đang chờ.
- 10/10 test Security Rules trên Firestore Emulator project demo đạt.
- Kiểm tra format 194 file Dart không thay đổi; git diff --check sạch.
- Không deploy, không ghi thử production. Chưa chạy E2E UI với SDK thật trên
  thiết bị; tranh chấp sức chứa vị trí giữa nhiều thiết bị chưa được đưa vào
  transaction server trong Task 3. Release gate Functions/rules/app của Task 1–2
  vẫn áp dụng. Task 4 chẩn đoán Auth được triển khai bên dưới;
  bước còn lại: Task 5 cửa sổ dự báo.

## Task 4 — Chẩn đoán xác thực, không nới quyền

- Đăng nhập/khôi phục phiên chỉ đọc hồ sơ; thiếu hồ sơ bị từ chối, không tự
  tạo pending. Đăng ký chủ động vẫn tạo pending như trước.
- UserProfileMapper từ chối role thiếu/sai kiểu/không đúng nguyên văn admin
  hoặc staff, và isActive không phải bool. Không trim hoặc sửa role.
- AuthProfileDiagnostics dùng chung cho đăng nhập, khôi phục và listener;
  phân biệt thiếu hồ sơ, UID lệch, role/dữ liệu sai, chưa kích hoạt/bị khóa,
  lỗi mạng, permission-denied và hồ sơ chưa được server xác nhận.
- LoginViewModel ưu tiên thông báo của kết quả thao tác hiện tại; thông báo
  đọc hồ sơ không chèn nội dung exception SDK hoặc dữ liệu hồ sơ. Không thêm log.
- Giữ nguyên session revision, fail-closed, thu hồi quyền, cập nhật quyền
  await server và Provider/presentation/logic/data. Không đổi Security Rules.
- Giới hạn schema: chỉ có isActive, không thể phân biệt chưa từng kích hoạt
  và bị khóa khi đăng nhập mới; chỉ báo chắc chắn bị khóa khi nhận thay đổi
  isActive=false từ phiên đang hoạt động. Không tự suy diễn từ timestamps/role.

File Task 4: auth_profile_diagnostics.dart, auth_provider.dart,
user_profile_mapper.dart, login_view_model.dart; test/auth_profile_diagnostics_test.dart,
test/auth_security_regression_test.dart, test/auth_cloud_provider_test.dart,
test/firestore_rules/auth.rules.test.mjs; ARCHITECTURE.md và REFACTOR_PLAN.md.

Kiểm tra Task 4:
- flutter analyze --no-pub: không có issue; 47/47 test Auth chạy lại đạt.
- Toàn bộ 237/237 test Flutter đạt (26 test mới, gồm LoginScreen hiển thị toast).
- 11/11 test Security Rules đạt trên Firestore Emulator, project demo-smart-rice-auth.
- Kiểm tra format 196 file Dart sạch; git diff --check không có lỗi whitespace.
- Không deploy, không đọc/ghi production, không thay đổi backend/rules.
- Chưa kiểm thử Auth end-to-end với SDK thật trên thiết bị; Firebase Auth/profile
  được giả lập trong unit/widget tests, còn Security Rules chạy emulator thật.

Prompt task tiếp theo (Task 5 — cửa sổ dự báo):

> $codex-token-saver $flutter-dart-development
> Triển khai Task 5 cho Smart Rice Warehouse: rà soát và sửa cửa sổ dữ liệu
> dự báo. Đọc ARCHITECTURE.md, REFACTOR_PLAN.md và ForecastProvider/ForecastService
> trước khi sửa; không làm lại Task 1–4. Kiểm tra khoảng lịch sử, biên ngày,
> ngày không có giao dịch, dữ liệu thiếu và thay đổi bộ lọc; không đưa dữ liệu
> tương lai vào dự báo hoặc coi thiếu dữ liệu là chắc chắn không có nhu cầu.
> Giữ Provider và ranh giới presentation/logic/data; thêm test hồi quy,
> chạy format/analyze/test phù hợp, không ghi thử production hoặc deploy.
> Kết thúc bằng file sửa, kết quả kiểm tra và rủi ro còn lại. Chỉ làm Task 5.

## Task 5 — Sửa cửa sổ tính toán dự báo tồn kho

- Sửa mốc bắt đầu từ hôm nay trừ 7 thành trừ 6 ngày lịch: đúng 7 ngày chia 7.
- Chuẩn hóa ngày phiếu trước khi so sánh, không phụ thuộc giờ referenceDate;
  tạo mốc bằng DateTime(year, month, day - 6), không trừ khoảng 24 giờ qua DST.
- Test đã chứng minh phiếu tương lai lọt vào fallback khi cửa sổ không có
  giao dịch: thêm điều kiện ngày không sau hôm nay vào lịch sử fallback.
  Giữ nguyên mẫu số 30 và toàn bộ công thức/ngưỡng còn lại.
- Không đổi API, ForecastProvider, UI, dữ liệu hay Firebase.
- File sửa: lib/logic/services/forecast_service.dart, test/forecast_window_test.dart,
  ARCHITECTURE.md và REFACTOR_PLAN.md.
- 13 test mới dùng thời gian cố định: biên cửa sổ, giờ trong ngày, 8 ngày,
  giao tháng/năm/năm nhuận, tương lai ở cả hai nhánh, fallback, tốc độ 0,
  số ngày/trạng thái/đề xuất nhập và đường gọi ForecastProvider.
- Trước sửa: 9 test mới thất bại; sau sửa: 26/26 test dự báo và luồng liên quan đạt.
- Kết quả cuối: 250/250 test Flutter đạt; flutter analyze --no-pub sạch;
  dart format kiểm tra 2 file Dart sửa sạch; git diff --check sạch.
- Giới hạn giữ nguyên: fallback vẫn lấy toàn bộ lịch sử hợp lệ chia 30,
  không chuyển thành cửa sổ 30 ngày; ngày theo thành phần year/month/day
  hiện có, chưa thiết kế múi giờ kho riêng. Các thay đổi đó ngoài Task 5.

