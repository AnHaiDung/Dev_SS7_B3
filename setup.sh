#!/usr/bin/env bash
# ==============================================================================
# Script tự động triển khai Bài 3 - Session 07:
# Thiết lập Cơ sở dữ liệu và Tự cấu hình dịch vụ Systemd cho Spring Boot
# ==============================================================================

set -euo pipefail

echo "=========================================================="
echo " [BƯỚC 1] Khởi tạo Cơ sở dữ liệu MySQL và Phân quyền"
echo "=========================================================="
if command -v mysql &>/dev/null; then
    echo ">> Đang thực thi init_db.sql vào MySQL..."
    mysql -u root < "$(dirname "$0")/init_db.sql" || {
        echo ">> Vui lòng nhập mật khẩu root MySQL nếu có:"
        mysql -u root -p < "$(dirname "$0")/init_db.sql"
    }
    echo ">> Khởi tạo database và user MySQL thành công!"
else
    echo ">> [LƯU Ý] Lệnh mysql không khả dụng trong môi trường hiện tại. Bỏ qua bước chạy MySQL tự động."
fi

echo ""
echo "=========================================================="
echo " [BƯỚC 2] Tạo System User không có shell login"
echo "=========================================================="
if id "spring-runner" &>/dev/null; then
    echo ">> Người dùng 'spring-runner' đã tồn tại."
else
    echo ">> Tạo người dùng hệ thống 'spring-runner' (nologin)..."
    sudo useradd -r -s /usr/sbin/nologin -d /opt/spring-app spring-runner
    echo ">> Đã tạo user spring-runner thành công."
fi

echo ""
echo "=========================================================="
echo " [BƯỚC 3] Thiết lập thư mục và quyền thực thi ứng dụng"
echo "=========================================================="
sudo mkdir -p /opt/spring-app

# Đảm bảo file app.jar tồn tại trong /opt/spring-app/
if [ ! -f /opt/spring-app/app.jar ]; then
    if [ -f "$(dirname "$0")/app.jar" ]; then
        echo ">> Sao chép app.jar từ thư mục hiện tại vào /opt/spring-app/..."
        sudo cp "$(dirname "$0")/app.jar" /opt/spring-app/app.jar
    else
        echo ">> [CẢNH BÁO] Không tìm thấy app.jar tại $(dirname "$0")/app.jar."
        echo ">> Hãy đảm bảo bạn đã đặt app.jar vào /opt/spring-app/app.jar trước khi khởi chạy dịch vụ."
    fi
fi

# Cấp quyền cho user spring-runner
if [ -d /opt/spring-app ]; then
    sudo chown -R spring-runner:spring-runner /opt/spring-app
    sudo chmod 750 /opt/spring-app
    echo ">> Đã phân quyền thư mục /opt/spring-app cho user spring-runner."
fi

echo ""
echo "=========================================================="
echo " [BƯỚC 4] Cài đặt và cấu hình Systemd Service"
echo "=========================================================="
echo ">> Sao chép spring-app.service vào /etc/systemd/system/..."
sudo cp "$(dirname "$0")/spring-app.service" /etc/systemd/system/spring-app.service
sudo chmod 644 /etc/systemd/system/spring-app.service

echo ">> Nạp lại cấu hình systemd daemon..."
sudo systemctl daemon-reload

echo ">> Kích hoạt dịch vụ khởi động cùng hệ thống (enable)..."
sudo systemctl enable spring-app.service

echo ">> Khởi chạy dịch vụ..."
sudo systemctl restart spring-app.service

echo ""
echo "=========================================================="
echo " [BƯỚC 5] Kiểm tra trạng thái dịch vụ và cổng lắng nghe"
echo "=========================================================="
echo ">> Trạng thái dịch vụ:"
sudo systemctl status spring-app.service --no-pager

echo ""
echo ">> Kiểm tra cổng lắng nghe 8082:"
ss -tlnp | grep 8082 || echo ">> Chưa thấy tiến trình lắng nghe trên port 8082 (có thể cần vài giây để Spring Boot khởi động)."
