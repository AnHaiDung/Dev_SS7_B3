-- ==============================================================
-- Kịch bản khởi tạo Cơ sở dữ liệu và Phân quyền cho Spring Boot
-- Bài 3: Session 07 - DevOps Lab
-- ==============================================================

-- 1. Tạo database springboot_db nếu chưa tồn tại
CREATE DATABASE IF NOT EXISTS springboot_db 
    CHARACTER SET utf8mb4 
    COLLATE utf8mb4_unicode_ci;

-- 2. Tạo người dùng spring-admin với mật khẩu SpringSecure@123
CREATE USER IF NOT EXISTS 'spring-admin'@'localhost' IDENTIFIED BY 'SpringSecure@123';
CREATE USER IF NOT EXISTS 'spring-admin'@'%' IDENTIFIED BY 'SpringSecure@123';

-- 3. Cấp toàn quyền quản trị trên database springboot_db
GRANT ALL PRIVILEGES ON springboot_db.* TO 'spring-admin'@'localhost';
GRANT ALL PRIVILEGES ON springboot_db.* TO 'spring-admin'@'%';

-- 4. Áp dụng thay đổi quyền hạn
FLUSH PRIVILEGES;

-- 5. Truy vấn kiểm tra quyền người dùng vừa tạo
SHOW GRANTS FOR 'spring-admin'@'localhost';
