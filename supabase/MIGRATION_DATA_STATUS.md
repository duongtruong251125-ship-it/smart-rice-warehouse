# Tình trạng dữ liệu lịch sử

## Đã nhập

- Bản kiểm kê cuối cùng ghi nhận 53 tài liệu thuộc 11 nhóm và 7 tài khoản.
- Bảy tài khoản cùng mã người dùng lịch sử đã được ánh xạ sang Supabase Auth.
- Ba hồ sơ giữ nguyên vai trò/trạng thái; bốn tài khoản còn lại được tạo dưới
  dạng nhân viên chưa kích hoạt.
- Bộ dữ liệu mở kho tạm 1.200 kg được nhập riêng vào Supabase với migration run
  `tmp-opening-stock-2026-10-29`. Đây là fixture, không phải số liệu thực tế.

## Chưa đủ điều kiện di trú tồn kho lịch sử

- Nguồn dữ liệu không có danh sách lô, số dư tại thời điểm chốt, sổ biến động
  hoặc chỉ mục mã lô.
- Chín phiếu nhập tham chiếu mã lô không tồn tại; ba báo cáo hư hỏng tham chiếu
  ID lô không tồn tại.
- Chín lô trên thiết bị trùng dữ liệu mẫu của ứng dụng, không phải nguồn tồn kho
  thật có thể dùng để khôi phục.
- Không suy ra số dư từ tổng phiếu nhập/xuất. Cần dữ liệu lô và số dư hiện tại
  được chủ dự án xác nhận trước khi nạp thêm.

## Bảo toàn dữ liệu

Các bản export kiểm kê gốc được giữ ở thư mục local bị Git bỏ qua. Chúng không
được ứng dụng đọc và không được đồng bộ tự động. Không chỉnh sửa hoặc xóa bản
gốc nếu chưa hoàn tất đối chiếu dữ liệu và chính sách lưu trữ.
