# WiFi Scope

Web phân tích Wi-Fi chạy cục bộ trên Windows, không cần cài Node hoặc Python.

## Chạy

Nhấp đúp **Start.cmd**. Trình duyệt mở **http://127.0.0.1:8765**. Giữ cửa sổ PowerShell mở khi sử dụng; Ctrl+C để dừng.

Nếu Windows chặn quét, vào **Settings → Privacy & security → Location** và bật quyền vị trí, bao gồm quyền ứng dụng desktop nếu có. Nếu vẫn báo yêu cầu elevation, chạy Start.cmd bằng **Run as administrator**. Không cần quyền administrator để mở giao diện web thông thường.

## Chức năng

- Quét SSID, từng BSSID, tín hiệu %, dBm ước tính, kênh, băng tần, chuẩn radio, xác thực và mã hóa qua `netsh wlan show networks mode=bssid`.
- Biểu đồ kênh 2.4/5/6 GHz; chọn mạng trong bảng để xem tối đa 30 lần đọc tín hiệu trong phiên.
- Tự cập nhật 10 giây, tìm kiếm, lọc băng tần, sắp xếp tín hiệu, xuất các hàng đang lọc ra CSV UTF-8.
- Chế độ mẫu có nhãn riêng; không được coi là kết quả quét thật.

## Giới hạn

Đây là bản quét và phân tích cơ bản, không phải toàn bộ tính năng NetSpot. Chỉ dịch vụ trên máy Windows mới đọc được card Wi-Fi; đưa riêng giao diện lên hosting sẽ không quét được máy người truy cập. Dịch vụ chỉ lắng nghe loopback và không gửi dữ liệu ra ngoài.

Bộ đọc hiện hỗ trợ đầu ra netsh tiếng Anh. Dữ liệu phụ thuộc adapter, driver và bộ nhớ đệm Windows; mỗi lần đọc không đảm bảo adapter vừa thực hiện một lần quét radio mới. dBm = signal% / 2 − 100 là quy đổi gần đúng, không phải RSSI đo trực tiếp. Không cung cấp nhiễu, SNR, độ rộng kênh, tốc độ thực tế hay bản đồ nhiệt. Khi Windows không cung cấp băng tần cho 802.11ax/be, giữ trạng thái chưa xác định để tránh nhầm 2.4 GHz và 6 GHz. Đường cong kênh chỉ minh họa; không dùng để kết luận chính xác mức nhiễu/chồng lấn.

## Kiểm tra

`powershell -NoProfile -ExecutionPolicy Bypass -File .\Test-Scanner.ps1`

Cổng khác: `powershell -NoProfile -ExecutionPolicy Bypass -File .\Start-WifiScope.ps1 -Port 8766`
