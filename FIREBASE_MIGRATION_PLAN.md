# Firebase Migration Plan

> Các đường dẫn trong kế hoạch này ghi nhận cấu trúc trước khi tách giao diện và
> logic. Cấu trúc hiện tại và nơi sửa từng chức năng được mô tả trong
> [ARCHITECTURE.md](ARCHITECTURE.md): màn hình ở `lib/presentation/`, nghiệp vụ ở
> `lib/logic/`, SQLite/Firebase/repository ở `lib/data/`.

## 1. Phạm vi và nguyên tắc

Mục tiêu là chuyển dữ liệu nghiệp vụ của Smart Rice Warehouse từ SQLite sang
Cloud Firestore mà không viết lại giao diện, Provider hoặc các nghiệp vụ đang
hoạt động đúng.

- Firebase Authentication quản lý danh tính và phiên đăng nhập.
- Cloud Firestore lưu dữ liệu nghiệp vụ dùng chung giữa nhiều thiết bị.
- Firestore Transaction xử lý mọi thay đổi số lượng tồn kho.
- SQLite chỉ giữ dữ liệu cục bộ cần thiết, chủ yếu là metadata ảnh.
- File ảnh tiếp tục nằm trong Application Documents Directory.
- Không sử dụng Firebase Storage, Cloud Functions hoặc dịch vụ yêu cầu Blaze.
- Migration phải giữ nguyên ID, có thể chạy lại an toàn và không xóa dữ liệu
  SQLite trước khi đối chiếu thành công.

## 2. Kiến trúc hiện tại

```text
Flutter UI
  -> Provider / ChangeNotifier
    -> List model trong bộ nhớ
      -> callback onPersist
        -> AppDatabase
          -> SQLite table app_state (JSON theo từng state_key)
```

Authentication hiện tại là kiến trúc lai:

```text
Login UI
  -> AuthProvider
    -> FirebaseAuthService -> Firebase Authentication
    -> AppDatabase         -> email, password hash, remember flag, profile local
```

Các đặc điểm chính:

- `AppDatabase` dùng một bảng `app_state(state_key, payload)` để lưu toàn bộ
  danh sách nghiệp vụ dưới dạng JSON.
- Provider trực tiếp sở hữu danh sách dữ liệu và gọi callback để ghi toàn bộ
  danh sách sau mỗi thay đổi.
- Dashboard và báo cáo tính toán từ dữ liệu đang có trong Provider.
- Tồn kho là `BatchModel.quantity`; chưa có nguồn tồn kho độc lập.
- Nhập, xuất, kiểm kê và báo hỏng cập nhật các Provider trong bộ nhớ rồi ghi
  SQLite; không có transaction bền vững giữa nhiều nguồn dữ liệu.
- Ảnh sản phẩm, avatar và ảnh báo hỏng được lưu trong Documents; đường dẫn tuyệt
  đối hiện nằm trong JSON nghiệp vụ hoặc profile local.

## 3. Kiến trúc sau chuyển đổi

```text
Flutter UI (giữ nguyên)
  -> Provider / ChangeNotifier (giữ nguyên public API khi có thể)
    -> Repository interface
      -> Firestore repository
        -> Cloud Firestore
```

```text
FirebaseAuthService
  -> Firebase Authentication
  -> UserRepository
    -> users/{uid}
```

```text
Flutter UI
  -> LocalImageRepository
    -> ImageStorageService -> Documents/smart_rice_warehouse/...
    -> SQLite              -> local_image_metadata
```

Provider không được gọi `FirebaseFirestore.instance` trực tiếp. Repository sẽ
chịu trách nhiệm chuyển đổi model, stream dữ liệu, phân trang và transaction.

## 4. Phần đã có và được giữ nguyên

- UI, theme, navigation và responsive layout.
- Provider/ChangeNotifier là state-management chính.
- Các model và ID hiện có; chỉ bổ sung mapper/field còn thiếu.
- `FirebaseAuthService` và các form đăng nhập, đăng ký, quên mật khẩu.
- `ImageStorageService`, `image_picker`, `path_provider` và `Image.file`.
- Các thư mục ảnh `rices`, `avatars`, `damage_reports`.
- Logic FEFO, validation không xuất vượt tồn và kiểm tra dữ liệu đầu vào.
- Biểu đồ `fl_chart`, QR scanner, OCR, PDF/printing và Excel export.
- Công thức dashboard, báo cáo, cảnh báo và dự báo; chỉ đổi nguồn dữ liệu.
- SQLite hiện tại được giữ cho đến khi migration và đối chiếu hoàn tất.

## 5. Phần cần chuyển hoặc bổ sung

- Đồng bộ trạng thái Firebase Auth bằng `authStateChanges()`.
- Hồ sơ người dùng và role trong `users/{uid}`; không tin role do client tự gửi.
- Repository interface và Firestore implementation cho dữ liệu nghiệp vụ.
- Stream realtime cho catalog, batch, receipt và báo cáo hư hỏng.
- Transaction cho nhập, xuất, kiểm kê và báo hỏng.
- `stock_movements` làm nhật ký tồn kho bất biến.
- Security Rules dựa trên authentication và role thực tế.
- Firestore indexes cho các truy vấn theo ngày, trạng thái và quan hệ.
- Migration SQLite -> Firestore có backup, checkpoint và kiểm tra đối chiếu.
- SQLite metadata ảnh ánh xạ theo `(ownerType, ownerId)` và lưu đường dẫn tương
  đối thay vì đẩy đường dẫn thiết bị lên Firestore.
- Trạng thái loading, empty, error và xử lý mất mạng ở Provider khi cần.

## 6. Các file source dự kiến sửa hoặc tạo

### Firebase foundation

- `pubspec.yaml`
- `lib/bootstrap_app.dart`
- `lib/core/services/firebase_auth_service.dart`
- `lib/firebase_options.dart` chỉ cập nhật qua FlutterFire CLI nếu bổ sung platform.
- `firebase.json`
- `firestore.rules` (mới)
- `firestore.indexes.json` (mới)

### Repository layer

- `lib/repositories/` (mới)
- `lib/repositories/contracts/` (mới)
- `lib/repositories/firestore/` (mới)
- `lib/repositories/local/` (mới cho metadata ảnh/migration)
- `lib/core/firebase/firestore_paths.dart` (mới)
- `lib/core/firebase/firestore_converters.dart` hoặc mapper theo từng model (mới)

### Models

- `lib/models/user_model.dart`
- `lib/models/rice_model.dart`
- `lib/models/supplier_model.dart`
- `lib/models/customer_model.dart`
- `lib/models/batch_model.dart`
- `lib/models/import_receipt_model.dart`
- `lib/models/export_receipt_model.dart`
- `lib/models/damage_report_model.dart`
- `lib/models/inventory_check_model.dart`
- `lib/models/stock_movement_model.dart` (mới)

### Provider/bootstrap wiring

- `lib/app.dart`
- `lib/providers/auth_provider.dart`
- Các Provider nghiệp vụ hiện có; giữ public API và thay nguồn persistence bằng
  repository theo từng task.

### Local data và migration

- `lib/data/app_database.dart`
- `lib/core/services/image_storage_service.dart` chỉ bổ sung xử lý đường dẫn
  tương đối nếu cần, không thay đổi cơ chế lưu file.
- `lib/services/firebase_data_migration_service.dart` (mới)

### Testing

- `test/repositories/` (mới)
- `test/migration/` (mới)
- `test/firebase_auth/` (mới)
- `test/inventory_transaction/` (mới)
- `test/firestore_rules/` hoặc bộ test Emulator phù hợp (mới)

## 7. Firestore collection schema

Tất cả thời gian trên Firestore dùng `Timestamp`. Document ID ưu tiên dùng ID
hiện tại để giữ quan hệ và migration có thể chạy lại an toàn.

### `users/{uid}`

| Field | Type | Ghi chú |
|---|---|---|
| `email` | string | Email chuẩn hóa, không chứa mật khẩu |
| `displayName` | string | Tên hiển thị |
| `role` | string | `admin` hoặc `staff` |
| `isActive` | bool | Khóa quyền nghiệp vụ khi false |
| `createdAt` | timestamp | server timestamp |
| `updatedAt` | timestamp | server timestamp |

Avatar không lưu trong document này; thiết bị ánh xạ ảnh local bằng `uid`.

### `rice_products/{riceId}`

`code`, `name`, `category`, `unit`, `purchasePrice`, `sellingPrice`,
`minimumStock`, `description`, `isActive`, `characteristicIds`, `createdAt`,
`updatedAt`.

Không có `imagePath`.

### `rice_characteristics/{characteristicId}`

`name`, `description`, `colorValue`, `isDefault`, `createdAt`, `updatedAt`.

### `suppliers/{supplierId}`

`name`, `phone`, `email`, `address`, `taxCode`, `note`, `isActive`,
`createdAt`, `updatedAt`.

### `customers/{customerId}`

`name`, `phone`, `email`, `address`, `customerType`, `note`, `isActive`,
`createdAt`, `updatedAt`.

Lịch sử giao dịch được truy vấn từ `export_receipts` theo `customerId`, không
nhân bản toàn bộ lịch sử vào customer document.

### `batches/{batchId}`

`code`, `riceId`, `riceNameSnapshot`, `supplierId`, `supplierNameSnapshot`,
`initialQuantity`, `remainingQuantity`, `purchasePrice`, `importDate`,
`manufactureDate`, `expiryDate`, `status`, `warehouseLocationId`,
`locationNameSnapshot`, `createdAt`, `updatedAt`.

`remainingQuantity` chỉ được cập nhật qua repository transaction nghiệp vụ.

### `import_receipts/{receiptId}`

`code`, `supplierId`, `supplierNameSnapshot`, `date`, `items[]`, `totalAmount`,
`performedBy`, `status`, `processedAt`, `createdAt`, `updatedAt`.

Mỗi item gồm `riceId`, `riceNameSnapshot`, `batchId`, `batchCode`, `quantity`,
`unitPrice`, `amount`, `manufactureDate`, `expiryDate`.

### `export_receipts/{receiptId}`

`code`, `customerId`, `customerNameSnapshot`, `date`, `items[]`, `totalAmount`,
`performedBy`, `status`, `processedAt`, `createdAt`, `updatedAt`.

Mỗi item gồm `riceId`, `riceNameSnapshot`, `quantity`, `unitPrice`, `amount` và
`allocations[]` chứa `batchId`, `batchCode`, `quantity`, `expiryDate`.

### `damage_reports/{reportId}`

`code`, `batchId`, `batchCodeSnapshot`, `riceId`, `riceNameSnapshot`, `quantity`,
`reason`, `note`, `reportedBy`, `reportedAt`, `status`, `processedAt`.

Không có `imagePath`; ảnh được ánh xạ local bằng `reportId`.

### `inventory_checks/{checkId}`

`code`, `createdBy`, `createdAt`, `status`, `items[]`, `totalItems`,
`totalDifference`, `completedAt`, `note`.

Điều chỉnh từ kiểm kê phải tạo stock movement trong cùng transaction.

### `stock_movements/{movementId}`

`type`, `batchId`, `riceId`, `quantityDelta`, `quantityBefore`,
`quantityAfter`, `referenceType`, `referenceId`, `performedBy`, `createdAt`,
`note`.

Movement chỉ được tạo cùng transaction với thay đổi tồn kho và không cho client
sửa/xóa sau khi tạo.

### `warehouse_locations/{locationId}`

`zone`, `rack`, `shelf`, `code`, `capacity`, `isActive`, `description`,
`createdAt`, `updatedAt`.

### `migration_runs/{uid_deviceOrRunId}`

`schemaVersion`, `sourceFingerprint`, `startedAt`, `completedAt`, `status`,
`counts`, `errors`. Collection này chỉ dành cho admin và dùng để chống migration
trùng lặp.

## 8. Quy tắc transaction tồn kho

### Xác nhận nhập kho

1. Đọc receipt ID và từ chối nếu đã ở trạng thái `confirmed`.
2. Đọc batch liên quan trong transaction.
3. Tạo batch mới hoặc cộng `remainingQuantity` cho đúng cùng một lô.
4. Ghi receipt với `status = confirmed`.
5. Tạo `stock_movements` với delta dương.
6. Commit một lần.

### Xác nhận xuất kho

1. Đọc receipt và từ chối xử lý lại.
2. Truy vấn trước các batch FEFO phù hợp.
3. Trong transaction, đọc lại từng batch và xác nhận phiên bản/số lượng hiện tại.
4. Từ chối toàn bộ nếu tổng tồn không đủ hoặc batch không còn hợp lệ.
5. Trừ `remainingQuantity`, ghi receipt và movement trong cùng transaction.

### Báo hỏng và kiểm kê

- Đọc batch, xác nhận số lượng mới không âm.
- Ghi report/check, cập nhật batch và tạo movement trong cùng transaction.
- Không cung cấp CRUD công khai để sửa trực tiếp `remainingQuantity`.

## 9. Kế hoạch migration dữ liệu

1. Flush hàng đợi ghi SQLite và sao lưu file database trước migration.
2. Đọc `AppSnapshot` và tạo fingerprint từ schema version + ID/count dữ liệu.
3. Kiểm tra `migration_runs`; nếu fingerprint đã hoàn tất thì không chạy lại.
4. Migration theo thứ tự quan hệ:
   - users/profile
   - rice characteristics
   - rice products
   - suppliers và customers
   - warehouse locations
   - batches
   - import/export receipts
   - damage reports, inventory checks và inventory snapshots cần giữ
5. Dùng document ID hiện tại và batch write giới hạn an toàn.
6. Không ghi `imagePath` hoặc `avatarPath` lên Firestore.
7. Ghi metadata ảnh local theo owner document ID.
8. Đối chiếu số document, tổng số lượng batch và tổng tiền receipt.
9. Chỉ đánh dấu migration `completed` sau khi đối chiếu thành công.
10. Giữ nguyên SQLite backup và dữ liệu nguồn; việc dọn dữ liệu cũ là task riêng
    sau khi người dùng xác nhận.

## 10. Security Rules dự kiến

- Mọi collection nghiệp vụ yêu cầu `request.auth != null`.
- Hàm rules đọc `users/{request.auth.uid}` để xác nhận `isActive` và role.
- Admin được quản lý catalog, tài khoản và migration metadata.
- Staff được đọc catalog và tạo nghiệp vụ được cho phép.
- Không cho client tự đổi `role` của chính mình.
- Không cho ghi password/passwordHash trong bất kỳ document nào.
- Không cho update trực tiếp `batches.remainingQuantity` qua CRUD thông thường.
- Receipt đã `confirmed` không được xác nhận lần hai hoặc sửa trường bất biến.
- `stock_movements` không được update/delete từ client.
- Rules không dùng quy tắc cho phép toàn bộ người dùng đọc/ghi.

Lưu ý: Security Rules không thể tự bảo đảm một chuỗi ghi nhiều document là đúng
nghiệp vụ. Repository transaction và Rules phải cùng kiểm tra các invariant có
thể biểu diễn được.

## 11. Firestore indexes dự kiến

- `batches`: `riceId + status + expiryDate`.
- `batches`: `supplierId + importDate desc`.
- `import_receipts`: `date desc + status`.
- `import_receipts`: `supplierId + date desc`.
- `export_receipts`: `date desc + status`.
- `export_receipts`: `customerId + date desc`.
- `damage_reports`: `batchId + reportedAt desc`.
- `stock_movements`: `batchId + createdAt desc`.
- `stock_movements`: `riceId + createdAt desc`.
- `stock_movements`: `referenceType + referenceId`.

Chỉ thêm index thực sự được dùng bởi query để giảm chi phí bảo trì và ghi.

## 12. Rủi ro kỹ thuật

- Auth hiện vẫn lưu password hash local và cho phép fallback đăng nhập; cần quyết
  định rõ chính sách offline để không tạo đường vòng phân quyền.
- Role hiện do client chọn khi đăng ký; phải khóa trước khi dùng thực tế.
- Model hiện thiếu một số field schema như email customer, initial quantity,
  purchase price của batch, performedBy và receipt status.
- Receipt hiện chủ yếu hỗ trợ một sản phẩm; schema mới hỗ trợ `items[]`, vì vậy
  mapper phải tương thích dữ liệu cũ.
- Ghi receipt và batch hiện là hai callback SQLite riêng, không bền vững nguyên
  tử nếu ứng dụng dừng giữa chừng.
- Đường dẫn ảnh hiện là tuyệt đối và nằm chung trong JSON nghiệp vụ.
- Firestore offline cache có thể xếp hàng write; thao tác xác nhận tồn kho phải
  yêu cầu kết nối phù hợp và hiển thị trạng thái rõ ràng.
- Transaction có thể retry; code transaction không được tạo side effect local
  hoặc tạo ID mới bên trong callback retry.
- Query toàn bộ collection cho dashboard sẽ tốn lượt đọc; cần giới hạn khoảng
  ngày, phân trang và cân nhắc aggregate query ở task báo cáo.
- Firebase hiện chỉ cấu hình Android và Web; iOS/desktop cần cấu hình riêng nếu
  nằm trong phạm vi phát hành.

## 13. Checklist kiểm thử

### Auth và quyền

- [ ] Đăng ký và đăng nhập Email/Password.
- [ ] Firebase Auth khôi phục đúng session sau khi mở lại ứng dụng.
- [ ] Quên mật khẩu gửi email đúng.
- [ ] User bị khóa không đọc/ghi dữ liệu nghiệp vụ.
- [ ] Staff không thể tự nâng role hoặc quản lý user.
- [ ] Người chưa đăng nhập bị từ chối.

### CRUD và realtime

- [ ] Rice, supplier, customer và batch CRUD đúng quyền.
- [ ] Hai thiết bị nhìn thấy thay đổi realtime.
- [ ] Không có đường dẫn ảnh local trong Firestore.
- [ ] Quan hệ ID không bị mất sau migration.

### Inventory

- [ ] Nhập kho tăng tồn và tạo movement đúng một lần.
- [ ] Xuất kho FEFO giảm đúng từng batch.
- [ ] Không xuất vượt tồn hoặc tạo tồn âm.
- [ ] Hai thiết bị xuất đồng thời không làm sai tồn.
- [ ] Receipt không được xác nhận hai lần.
- [ ] Báo hỏng và kiểm kê cập nhật tồn nguyên tử.

### Migration và local image

- [ ] SQLite được backup trước migration.
- [ ] Chạy migration lần hai không nhân đôi dữ liệu.
- [ ] Đối chiếu count, tổng tồn và tổng tiền thành công.
- [ ] Ảnh cũ còn hiển thị trên thiết bị nguồn.
- [ ] Thiết bị không có ảnh dùng fallback, không crash.
- [ ] Metadata ảnh ánh xạ theo Firestore document ID.

### Chất lượng build

- [ ] `flutter analyze`.
- [ ] `flutter test`.
- [ ] Test Firebase Emulator/Rules.
- [ ] Test thủ công khi mất mạng.
- [ ] Test đồng bộ trên hai thiết bị/tài khoản.
- [ ] `flutter build apk`.

## 14. Thứ tự triển khai theo task

Mỗi task phải hoàn tất test liên quan trước khi chuyển task tiếp theo.

- [x] **Task 1 — Audit và migration plan**
  - Kiểm tra source, xác định phần giữ nguyên/chuyển đổi.
  - Chốt schema, rủi ro và checklist trong file này.

- [x] **Task 2 — Firestore foundation**
  - Thêm `cloud_firestore`.
  - Tạo Firestore paths, mapper/converter cơ sở và repository contracts.
  - Thêm `firestore.rules`, `firestore.indexes.json` và cấu hình `firebase.json`.
  - Chưa chuyển Provider nghiệp vụ.

- [x] **Task 3 — Auth session và user profiles**
  - Đồng bộ `authStateChanges()`.
  - Tạo/đọc `users/{uid}`.
  - Loại bỏ role tự xác nhận và password hash local khỏi luồng cloud.
  - Giữ avatar local theo `uid`.

  Trạng thái triển khai: tài khoản tự đăng ký luôn là `staff` và
  `isActive=false`. Hồ sơ admin đầu tiên phải được quản trị dự án tạo/kích hoạt
  trong Firebase Console; ứng dụng không có cơ chế client tự phong admin.

- [x] **Task 4 — Rice products và characteristics**
  - Repository + realtime stream + CRUD.
  - Không đẩy `imagePath` lên Firestore (giữ tại local).
  - Giữ API Provider/UI hiện có.

- [x] **Task 5 — Suppliers và customers**
  - Repository + realtime stream + CRUD.
  - Bổ sung field model còn thiếu theo cách tương thích dữ liệu cũ.

- [x] **Task 6 — Batches, locations và inventory read model**
  - Chuyển batch/location sang Firestore.
  - Khóa cập nhật trực tiếp số lượng tồn.
  - Đồng bộ tồn kho realtime.

- [x] **Task 7 — Import transaction**
  - Xác nhận phiếu nhập nguyên tử.
  - Chống xử lý trùng và ghi stock movement.

- [x] **Task 8 — Export transaction và FEFO**
  - Giữ FEFO hiện có, thực thi bằng Firestore Transaction.
  - Kiểm tra lại tồn trong transaction và chống tồn âm.

- [x] **Task 9 — Damage reports và inventory checks**
  - Transaction giảm/điều chỉnh tồn và movement.
  - Ảnh báo hỏng tiếp tục local.

- [x] **Task 10 — Dashboard, reports, logs và phân trang**
  - Đổi nguồn dữ liệu sang Firestore.
  - Tối ưu query, aggregate và phân trang lịch sử.

- [x] **Task 11 — SQLite backup, image metadata và data migration**
  - Backup, checkpoint, idempotency, đối chiếu.
  - Tạo metadata ảnh local theo document ID và đường dẫn tương đối.
  - Triển khai `FirebaseDataMigrationService`.

- [x] **Task 12 — Rules hardening và kiểm thử hoàn chỉnh**
  - Hoàn thiện `firestore.rules` và `firestore.indexes.json`.
  - Chạy `flutter analyze` (0 issues).
  - Chạy `flutter test` (89/89 tests pass).

## 15. Điều kiện hoàn tất migration

Migration chỉ được xem là hoàn tất khi dữ liệu nghiệp vụ đọc/ghi từ Firestore,
mọi thay đổi tồn kho chạy trong transaction, Rules đã được kiểm thử, migration
SQLite đã đối chiếu thành công, ảnh local vẫn hoạt động và toàn bộ checklist build
đều đạt. SQLite cũ không bị xóa tự động.
