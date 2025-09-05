# Blueprint: Ứng dụng Video Chat Ngẫu nhiên

## Tổng quan

Tài liệu này vạch ra kế hoạch và tiến độ xây dựng ứng dụng video chat **ngẫu nhiên**, kết nối người dùng với những người lạ đang online. Ứng dụng sẽ được xây dựng cho Android và iOS bằng Flutter và Firebase.

## **Kế hoạch Thực thi Mới**

### **Giai đoạn 1-6: Hoàn thiện Các tính năng Cốt lõi & Tái tương tác**
*   **Trạng thái: Hoàn thành**
*   **Mô tả:** Bao gồm việc xây dựng hệ thống ghép đôi, trải nghiệm cuộc gọi, UI/UX, lịch sử cuộc gọi, chat text và hệ thống thông báo tái tương tác người dùng.

---

### **Chi tiết Giai đoạn 6: Thông báo Tái tương tác (Re-engagement)**

*   **Mục tiêu:** Gửi thông báo đẩy định kỳ để khuyến khích người dùng quay trở lại ứng dụng.
*   **Trạng thái: Hoàn thành**

*   **Kế hoạch Đã Thực hiện:**
    1.  **Tích hợp Firebase Messaging (FCM):
**        *   Đã thêm package `firebase_messaging`.
        *   Đã tạo `NotificationService` để quản lý token, quyền và thông báo.
        *   FCM token được tự động lưu và cập nhật vào Firestore cho mỗi người dùng.
    2.  **Cloud Function gửi thông báo định kỳ:**
        *   Đã triển khai Cloud Function `sendReengagementNotifications` chạy hàng ngày.
        *   Function tự động quét những người dùng không hoạt động trong 7 ngày và gửi thông báo mời quay lại.
    3.  **Xử lý khi nhấn vào thông báo:**
        *   Ứng dụng được cấu hình để mở màn hình chính khi người dùng nhấn vào thông báo.

### **Các Giai đoạn Trước (Lưu trữ)**

<details>
<summary>Lịch sử các giai đoạn đã hoàn thành</summary>

*   **Giai đoạn 1: Giao diện & Hệ thống Ghép đôi (Matchmaking)**
*   **Giai đoạn 2: Trải nghiệm Cuộc gọi & Xử lý Kết thúc**
*   **Giai đoạn 3: Tinh chỉnh UI/UX & Tính năng Mở rộng**
*   **Giai đoạn 4: Lịch sử Cuộc gọi & Hoàn thiện**
*   **Giai đoạn 5: Chat Text Trong Cuộc gọi**
*   **Giai đoạn 6: Thông báo Tái tương tác**

</details>
