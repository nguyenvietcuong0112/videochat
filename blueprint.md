# Blueprint: Ứng dụng Video Chat Ngẫu nhiên

## Tổng quan

Tài liệu này vạch ra kế hoạch và tiến độ xây dựng ứng dụng video chat **ngẫu nhiên**, kết nối người dùng với những người lạ đang online. Ứng dụng sẽ được xây dựng cho Android và iOS bằng Flutter và Firebase.

## **Kế hoạch Thực thi Mới**

### **Giai đoạn 7: Báo cáo và Chặn Người dùng (User Reporting and Blocking)**

*   **Mục tiêu:** Cung cấp cho người dùng các công cụ để báo cáo hành vi không phù hợp và chặn những người dùng khác, nhằm xây dựng một cộng đồng an toàn.
*   **Trạng thái: Đang thực hiện**

*   **Kế hoạch Chi tiết:**
    1.  **Cập nhật Giao diện Người dùng (UI):**
        *   Thêm các nút "Báo cáo" (Report) và "Chặn" (Block) vào màn hình cuộc gọi video.
        *   Thiết kế một hộp thoại (dialog) để người dùng có thể chọn lý do báo cáo và cung cấp thêm chi tiết.
    2.  **Mở rộng Firestore Schema:**
        *   Tạo một collection mới là `reports` để lưu trữ các báo cáo. Mỗi báo cáo sẽ chứa thông tin về người báo cáo, người bị báo cáo, lý do, và thời gian.
        *   Thêm một mảng `blockedUsers` vào document của mỗi người dùng để lưu trữ UID của những người đã bị họ chặn.
    3.  **Triển khai Logic Chặn:**
        *   Cập nhật `MatchmakingService` để loại trừ việc ghép đôi người dùng với những người nằm trong danh sách `blockedUsers` của họ.
    4.  **Triển khai Logic Báo cáo:**
        *   Tạo một Cloud Function hoặc service-side logic để xử lý các báo cáo (ví dụ: tự động cảnh cáo hoặc tạm khóa tài khoản nếu có nhiều báo cáo).

---

### **Các Giai đoạn Đã Hoàn thành**

<details>
<summary>Lịch sử các giai đoạn đã hoàn thành</summary>

*   **Giai đoạn 1: Giao diện & Hệ thống Ghép đôi (Matchmaking)**
*   **Giai đoạn 2: Trải nghiệm Cuộc gọi & Xử lý Kết thúc**
*   **Giai đoạn 3: Tinh chỉnh UI/UX & Tính năng Mở rộng**
*   **Giai đoạn 4: Lịch sử Cuộc gọi & Hoàn thiện**
*   **Giai đoạn 5: Chat Text Trong Cuộc gọi**
*   **Giai đoạn 6: Thông báo Tái tương tác (Re-engagement)**
    *   **Mô tả:** Gửi thông báo đẩy định kỳ để khuyến khích người dùng quay trở lại ứng dụng.

</details>
