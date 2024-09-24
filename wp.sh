#!/bin/bash

# Hàm hiển thị hướng dẫn sử dụng
function show_help {
    echo "Usage:"
    echo "  ./install_wp.sh --name <folder_name> --domain <domain_name>"
    echo "  ./install_wp.sh <folder_name> <domain_name>"
    echo "Options:"
    echo "  -n | --name    Tên thư mục chứa WordPress (Document Root)"
    echo "  -d | --domain  Tên miền (domain) của website"
    exit 1
}

# Nếu không có đủ tham số
if [ "$#" -lt 2 ]; then
    show_help
fi

# Mặc định không có giá trị cho name và domain
wp_folder=""
domain_name=""

# Kiểm tra nếu tham số được truyền theo cờ
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--name) wp_folder="$2"; shift ;;
        -d|--domain) domain_name="$2"; shift ;;
        *) 
            # Nếu tham số không dùng cờ, kiểm tra nếu đã có đủ 2 giá trị
            if [ -z "$wp_folder" ]; then
                wp_folder="$1"
            elif [ -z "$domain_name" ]; then
                domain_name="$1"
            else
                echo "Tham số không hợp lệ: $1"
                show_help
            fi
            ;;
    esac
    shift
done

# Kiểm tra nếu cả wp_folder và domain_name chưa được cung cấp
if [[ -z "$wp_folder" || -z "$domain_name" ]]; then
    echo "Thiếu tham số. Bạn cần chỉ định cả tên thư mục và tên miền."
    show_help
fi

# Tạo cơ sở dữ liệu cho WordPress
echo "Nhập tên database cho WordPress:"
read wp_db
echo "Nhập tên user cho database:"
read wp_user
echo "Nhập mật khẩu cho user:"
read wp_password

sudo mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE ${wp_db};
CREATE USER '${wp_user}'@'localhost' IDENTIFIED BY '${wp_password}';
GRANT ALL PRIVILEGES ON ${wp_db}.* TO '${wp_user}'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo "Database đã được tạo."

# Tải xuống và cài đặt WordPress
cd /var/www/html/
sudo curl -O https://wordpress.org/latest.tar.gz
sudo tar -zxvf latest.tar.gz
sudo mv wordpress "$wp_folder"

# Thiết lập quyền cho WordPress
sudo chown -R www-data:www-data /var/www/html/"$wp_folder"
sudo chmod -R 755 /var/www/html/"$wp_folder"

# Hướng dẫn tiếp theo
echo "Cài đặt hoàn tất. Hãy cấu hình Nginx hoặc Apache theo yêu cầu của bạn để hoàn tất quá trình cài đặt WordPress."