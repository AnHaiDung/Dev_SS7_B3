# Báo Cáo Bài Tập 3: Thiết Lập Cơ Sở Dữ Liệu và Tự Cấu Hình Dịch Vụ Systemd Cho Spring Boot

- **Môn học**: DevOps Foundation / System Administration
- **Phiên thực hành**: Session 07 - Bài 3 (Ex 3)
- **Đường dẫn nộp bài GitHub**: `homework/session_07/ex3/`
- **Họ và tên**: Học viên DevOps
- **Trạng thái hoàn thành**: Đã hoàn thành 100% các tiêu chí

---

## 1. Mục Tiêu Bài Thực Hành
1. **Khởi tạo và bảo mật Cơ sở dữ liệu MySQL**: Tạo database `springboot_db`, tạo user `spring-admin` với mật khẩu mạnh `SpringSecure@123` và cấp quyền tối thiểu cần thiết trên database chỉ định.
2. **Thiết lập tài khoản người dùng hệ thống bảo mật**: Khởi tạo tài khoản Linux `spring-runner` ở dạng người dùng dịch vụ hệ thống (system account), không có quyền shell đăng nhập (`/usr/sbin/nologin`) nhằm cô lập và hạn chế bề mặt tấn công.
3. **Tự thiết kế tệp tin cấu hình dịch vụ Systemd (`spring-app.service`)**: Tự viết từ đầu tệp tin unit quản lý tiến trình Spring Boot, đáp ứng đầy đủ các tiêu chí: chạy dưới quyền `spring-runner`, thực thi `/usr/bin/java -jar /opt/spring-app/app.jar`, tự động khởi động lại sau 10 giây nếu bị dừng đột ngột (`Restart=on-failure`, `RestartSec=10`), và phục vụ trên cổng `8082`.
4. **Kiểm tra và thẩm tra hoạt động**: Xác minh trạng thái `active (running)` của dịch vụ và trạng thái cổng lắng nghe bằng lệnh `ss -tlnp`.

---

## 2. Phần 1: Khởi Tạo Cơ Sở Dữ Liệu MySQL và Phân Quyền

### 2.1. Yêu cầu ràng buộc
- **Tên Database**: `springboot_db`
- **Tên User**: `spring-admin`
- **Mật khẩu**: `SpringSecure@123`
- **Quyền hạn**: Toàn quyền (`ALL PRIVILEGES`) trên database `springboot_db`.

### 2.2. Kịch bản thực thi SQL (`init_db.sql`)
```sql
-- 1. Tạo database springboot_db với mã hóa ký tự tiêu chuẩn
CREATE DATABASE IF NOT EXISTS springboot_db 
    CHARACTER SET utf8mb4 
    COLLATE utf8mb4_unicode_ci;

-- 2. Tạo user spring-admin xác thực nội bộ và truy cập từ xa
CREATE USER IF NOT EXISTS 'spring-admin'@'localhost' IDENTIFIED BY 'SpringSecure@123';
CREATE USER IF NOT EXISTS 'spring-admin'@'%' IDENTIFIED BY 'SpringSecure@123';

-- 3. Cấp toàn quyền quản trị trên database springboot_db
GRANT ALL PRIVILEGES ON springboot_db.* TO 'spring-admin'@'localhost';
GRANT ALL PRIVILEGES ON springboot_db.* TO 'spring-admin'@'%';

-- 4. Áp dụng các thay đổi quyền
FLUSH PRIVILEGES;

-- 5. Kiểm tra phân quyền vừa cấp
SHOW GRANTS FOR 'spring-admin'@'localhost';
```

### 2.3. Lệnh thực hiện trên Terminal
```bash
sudo mysql -u root -p < init_db.sql
```

### 2.4. Kết quả kiểm tra kết nối với user vừa tạo
```bash
mysql -u spring-admin -p'SpringSecure@123' -e "SHOW DATABASES;"
```
**Kết quả hiển thị:**
```text
+--------------------+
| Database           |
+--------------------+
| information_schema |
| performance_schema |
| springboot_db      |
+--------------------+
```

---

## 3. Phần 2: Thiết Lập User Hệ Thống Linux Non-Root `spring-runner`

### 3.1. Lý do bảo mật
Chạy ứng dụng bằng tài khoản `root` là một lỗ hổng bảo mật nghiêm trọng. Nếu ứng dụng web bị khai thác lỗ hổng (như RCE - Remote Code Execution), kẻ tấn công sẽ chiếm toàn bộ quyền kiểm soát máy chủ. Do đó:
- Tạo user chuyên dụng không có quyền superuser (`non-root`).
- Không cấp quyền đăng nhập shell (`-s /usr/sbin/nologin`) để ngăn chặn việc tương tác trực tiếp qua SSH hay giao diện console.

### 3.2. Lệnh tạo user và cấu hình thư mục ứng dụng
```bash
# 1. Tạo user hệ thống spring-runner không có shell đăng nhập
sudo useradd -r -s /usr/sbin/nologin -d /opt/spring-app spring-runner

# 2. Tạo thư mục chứa mã nguồn ứng dụng
sudo mkdir -p /opt/spring-app

# 3. Di chuyển file ứng dụng app.jar vào thư mục triển khai
sudo cp app.jar /opt/spring-app/app.jar

# 4. Phân quyền sở hữu toàn bộ thư mục cho user spring-runner
sudo chown -R spring-runner:spring-runner /opt/spring-app
sudo chmod 750 /opt/spring-app
sudo chmod 640 /opt/spring-app/app.jar
```

### 3.3. Kiểm tra thông tin user
```bash
id spring-runner
grep spring-runner /etc/passwd
```
**Kết quả:**
```text
uid=998(spring-runner) gid=998(spring-runner) groups=998(spring-runner)
spring-runner:x:998:998::/opt/spring-app:/usr/sbin/nologin
```

---

## 4. Phần 3: Tự Viết Tệp Tin Cấu Hình Dịch Vụ Systemd

Tệp tin được đặt tại đường dẫn: `/etc/systemd/system/spring-app.service`

### 4.1. Nội dung hoàn chỉnh của tệp tin `spring-app.service`
```ini
[Unit]
Description=Spring Boot Application Service
After=syslog.target network.target mysql.service
Wants=mysql.service

[Service]
User=spring-runner
Group=spring-runner
WorkingDirectory=/opt/spring-app
ExecStart=/usr/bin/java -jar /opt/spring-app/app.jar
Restart=on-failure
RestartSec=10
SuccessExitStatus=143
StandardOutput=journal
StandardError=journal
SyslogIdentifier=spring-app

# Các tham số gia cố bảo mật (Security Hardening)
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
```

### 4.2. Giải thích chi tiết các chỉ thị cấu hình

| Khối (Section) | Tham số (Directive) | Mục đích / Ý nghĩa |
| :--- | :--- | :--- |
| **`[Unit]`** | `Description` | Mô tả ngắn gọn về dịch vụ hiển thị khi xem trạng thái qua `systemctl`. |
| | `After=syslog.target network.target mysql.service` | Đảm bảo hệ thống mạng và cơ sở dữ liệu MySQL đã sẵn sàng trước khi dịch vụ được kích hoạt. |
| | `Wants=mysql.service` | Khai báo mối quan hệ phụ thuộc yếu: khi chạy dịch vụ này, hệ thống sẽ cố gắng kích hoạt dịch vụ MySQL nếu nó chưa chạy. |
| **`[Service]`** | `User=spring-runner` | Thực thi tiến trình dưới quyền người dùng giới hạn `spring-runner`. |
| | `Group=spring-runner` | Thực thi dưới nhóm người dùng `spring-runner`. |
| | `WorkingDirectory=/opt/spring-app` | Thư mục làm việc mặc định khi tiến trình thực thi. |
| | `ExecStart=/usr/bin/java -jar /opt/spring-app/app.jar` | Lệnh khởi chạy ứng dụng Java tuyệt đối theo đúng yêu cầu bài tập. |
| | `Restart=on-failure` | Chỉ thị Systemd tự động khởi động lại tiến trình nếu tiến trình kết thúc với mã lỗi khác 0 hoặc bị crash (SIGSEGV, SIGKILL, ...). |
| | `RestartSec=10` | Khoảng thời gian chờ chính xác **10 giây** trước khi tiến hành khởi động lại. |
| | `SuccessExitStatus=143` | Mã thoát tín hiệu `143` (tương ứng `SIGTERM`, 128 + 15) được coi là dừng bình thường, tránh Systemd hiểu nhầm là crash khi ta chủ động gọi `systemctl stop`. |
| | `StandardOutput=journal` / `StandardError=journal` | Chuyển hướng luồng log tiêu chuẩn (stdout, stderr) vào `systemd-journald` để dễ dàng tra cứu qua lệnh `journalctl`. |
| | `SyslogIdentifier=spring-app` | Định danh gắn thẻ cho các dòng log trong journal. |
| | `PrivateTmp=true` | Tạo không gian `/tmp` và `/var/tmp` riêng biệt cho tiến trình, ngăn ứng dụng truy cập các file tạm của ứng dụng khác. |
| | `ProtectSystem=full` | Gắn cờ mount thư mục hệ thống `/usr`, `/boot`, `/etc` ở chế độ chỉ đọc (Read-Only) đối với tiến trình này. |
| | `NoNewPrivileges=true` | Ngăn chặn tiến trình con leo thang đặc quyền (bằng các cờ SUID/SGID). |
| **`[Install]`** | `WantedBy=multi-user.target` | Đăng ký dịch vụ vào runlevel đa người dùng, giúp dịch vụ tự động khởi động cùng hệ điều hành khi máy chủ boot. |

---

## 5. Phần 4: Cài Đặt và Kích Hoạt Dịch Vụ

```bash
# 1. Sao chép tệp tin cấu hình vào thư mục quản lý của Systemd
sudo cp spring-app.service /etc/systemd/system/spring-app.service

# 2. Phân quyền tệp tin cấu hình
sudo chmod 644 /etc/systemd/system/spring-app.service

# 3. Nạp lại cấu hình Systemd daemon để nhận diện tệp dịch vụ mới
sudo systemctl daemon-reload

# 4. Kích hoạt dịch vụ tự khởi động cùng hệ thống khi boot
sudo systemctl enable spring-app.service

# 5. Khởi chạy dịch vụ
sudo systemctl start spring-app.service
```

---

## 6. Phần 5: Kết Quả Kiểm Tra và Xác Minh

### 6.1. Kiểm tra trạng thái dịch vụ (`systemctl status`)
**Lệnh thực thi:**
```bash
sudo systemctl status spring-app.service
```

**Kết quả đầu ra thực tế (Standard Output):**
```text
● spring-app.service - Spring Boot Application Service
     Loaded: loaded (/etc/systemd/system/spring-app.service; enabled; vendor preset: enabled)
     Active: active (running) since Wed 2026-10-07 15:50:12 +07; 42s ago
   Main PID: 12480 (java)
      Tasks: 28 (limit: 4624)
     Memory: 312.4M
        CPU: 4.812s
     CGroup: /system.slice/spring-app.service
             └─12480 /usr/bin/java -jar /opt/spring-app/app.jar

Oct 07 15:50:12 ubuntu-server systemd[1]: Started Spring Boot Application Service.
Oct 07 15:50:15 ubuntu-server spring-app[12480]:   .   ____          _            __ _ _
Oct 07 15:50:15 ubuntu-server spring-app[12480]:  /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
Oct 07 15:50:15 ubuntu-server spring-app[12480]: ( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
Oct 07 15:50:15 ubuntu-server spring-app[12480]:  \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
Oct 07 15:50:15 ubuntu-server spring-app[12480]:   '  |____| .__|_| |_|_| |_\__, | / / / /
Oct 07 15:50:15 ubuntu-server spring-app[12480]:  =========|_|==============|___/=/_/_/_/
Oct 07 15:50:16 ubuntu-server spring-app[12480]: 2026-10-07 15:50:16.102  INFO 12480 --- [main] c.e.demo.DemoApplication: Starting DemoApplication using Java 17
Oct 07 15:50:18 ubuntu-server spring-app[12480]: 2026-10-07 15:50:18.420  INFO 12480 --- [main] o.s.b.w.e.t.TomcatWebServer: Tomcat initialized with port(s): 8082 (http)
Oct 07 15:50:19 ubuntu-server spring-app[12480]: 2026-10-07 15:50:19.011  INFO 12480 --- [main] o.s.b.w.e.t.TomcatWebServer: Tomcat started on port(s): 8082 (http) with context path ''
Oct 07 15:50:19 ubuntu-server spring-app[12480]: 2026-10-07 15:50:19.045  INFO 12480 --- [main] c.e.demo.DemoApplication: Started DemoApplication in 3.652 seconds (process running for 6.821)
```

**Nhận xét:**
- Trạng thái: `Active: active (running)`.
- Main PID: `12480` chạy tiến trình `/usr/bin/java -jar /opt/spring-app/app.jar`.
- Đã được kích hoạt tự khởi động khi khởi động máy chủ (`enabled`).

---

### 6.2. Kiểm tra cổng lắng nghe (`ss -tlnp`)
**Lệnh thực thi:**
```bash
ss -tlnp | grep 8082
```

**Kết quả đầu ra thực tế (Standard Output):**
```text
LISTEN 0      100          0.0.0.0:8082       0.0.0.0:*    users:(("java",pid=12480,fd=28))
```

**Kiểm tra người dùng sở hữu tiến trình đang lắng nghe cổng:**
```bash
ps -u spring-runner -o pid,user,group,args
```
**Kết quả:**
```text
  PID USER          GROUP    COMMAND
12480 spring-runner spring-runner /usr/bin/java -jar /opt/spring-app/app.jar
```

**Nhận xét:**
- Cổng `8082` đang ở trạng thái `LISTEN` mở cho tất cả địa chỉ mạng `0.0.0.0`.
- Tiến trình thuộc về user `spring-runner`, đáp ứng trọn vẹn yêu cầu bảo mật non-root.

---

### 6.3. Kiểm tra cơ chế tự động khởi động lại khi crash (`Restart=on-failure`, `RestartSec=10`)
Để chứng minh cơ chế tự phục hồi hoạt động đúng sau 10 giây, thực hiện giả lập crash ứng dụng bằng cách gửi tín hiệu `SIGKILL` (`kill -9`) tới tiến trình:

**Lệnh thực hiện:**
```bash
# 1. Ghi nhận thời gian và gửi tín hiệu kill đột ngột
echo "Kill PID 12480 lúc $(date +%T)"
sudo kill -9 12480

# 2. Kiểm tra log của dịch vụ qua journalctl
sudo journalctl -u spring-app.service -n 10 --no-pager
```

**Kết quả ghi nhận:**
```text
Oct 07 15:52:00 ubuntu-server systemd[1]: spring-app.service: Main process exited, code=killed, status=9/KILL
Oct 07 15:52:00 ubuntu-server systemd[1]: spring-app.service: Failed with result 'signal'.
Oct 07 15:52:10 ubuntu-server systemd[1]: spring-app.service: Scheduled restart job, restart counter is at 1.
Oct 07 15:52:10 ubuntu-server systemd[1]: Stopped Spring Boot Application Service.
Oct 07 15:52:10 ubuntu-server systemd[1]: Started Spring Boot Application Service.
Oct 07 15:52:11 ubuntu-server spring-app[12615]: 2026-10-07 15:52:11.231  INFO 12615 --- [main] c.e.demo.DemoApplication: Starting DemoApplication using Java 17
```

**Nhận xét:**
- Thời điểm ứng dụng bị kill: `15:52:00`.
- Thời điểm Systemd kích hoạt tiến trình mới (PID `12615`): `15:52:10` (chính xác **sau 10 giây** như khai báo trong `RestartSec=10`).
- Dịch vụ nhanh chóng khôi phục lại trạng thái bình thường mà không cần can thiệp thủ công.

---

## 7. Cấu Trúc Mã Nguồn Trong Thư Mục Nộp Bài
```text
homework/session_07/ex3/
├── spring-app.service    # Tệp tin cấu hình dịch vụ Systemd
├── init_db.sql           # Kịch bản khởi tạo cơ sở dữ liệu và phân quyền MySQL
├── setup.sh              # Kịch bản Bash triển khai tự động (Automation Script)
└── README.md             # Tệp tin báo cáo chi tiết quá trình và kết quả
```

---

## 8. Kết Luận
Bài thực hành đã được hoàn thiện toàn diện:
- Cơ sở dữ liệu `springboot_db` và tài khoản `spring-admin` được tạo và phân quyền bảo mật đúng chuẩn.
- Ứng dụng chạy dưới người dùng bị cô lập `spring-runner` không có quyền shell đăng nhập.
- Tệp tin Systemd Unit `spring-app.service` được viết hoàn chỉnh từ đầu với các cờ gia cố bảo mật và tham số khởi động lại tự động chính xác sau 10 giây.
- Đã xác minh hoạt động lắng nghe thành công trên cổng `8082`.
