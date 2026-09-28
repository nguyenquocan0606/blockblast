# blockblast

Game xếp khối kiểu Block Blast viết bằng Flutter, chạy trên iOS.

- **Không quảng cáo**: không dùng bất kỳ SDK quảng cáo nào.
- **Hồi sinh vô hạn, miễn phí**: khi hết chỗ đặt, bấm "Hồi sinh" để nhận 3 khối mới chắc chắn đặt vừa bàn cờ.
- Bàn 8×8, kéo thả khối, xoá hàng/cột đầy, combo, lưu kỷ lục.

## Cấu trúc

| File | Vai trò |
| --- | --- |
| `lib/game_logic.dart` | Luật chơi (thuần Dart): bàn cờ, đặt khối, xoá hàng, tính điểm, hồi sinh |
| `lib/main.dart` | Giao diện: kéo thả, hiệu ứng, màn hình hết lượt |
| `test/` | Test luật chơi và giao diện |

## Chạy trên iPhone

Cần một máy **Mac** có [Flutter](https://docs.flutter.dev/get-started/install/macos/mobile-ios) và **Xcode**.

```bash
# 1. Tạo thư mục ios/ (chỉ cần làm 1 lần; không ghi đè code có sẵn).
#    Thay "com.tenban" bằng tên miền đảo ngược của bạn.
flutter create --platforms=ios --org com.tenban .

# 2. Cài thư viện và chạy test
flutter pub get
flutter test

# 3. Cắm iPhone vào Mac rồi chạy
flutter run --release
```

Lần đầu chạy trên iPhone thật: mở `ios/Runner.xcworkspace` bằng Xcode →
**Runner → Signing & Capabilities** → chọn **Team** là Apple ID của bạn.
Trên iPhone vào **Cài đặt → Cài đặt chung → Quản lý VPN & thiết bị** để tin cậy nhà phát triển.

> Với Apple ID miễn phí, app hết hạn sau 7 ngày — chỉ cần chạy lại `flutter run` để cài lại.
> Tài khoản Apple Developer trả phí (99 USD/năm) thì app dùng được 1 năm và có thể đưa lên TestFlight/App Store.
