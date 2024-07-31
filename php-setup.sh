#!/bin/bash

# Hàm hiển thị hướng dẫn sử dụng
usage() {
  echo "Usage: $0 [version]"
  echo "  version : Phiên bản PHP muốn cài đặt hoặc cập nhật (ví dụ: 8.3). Nếu bỏ trống, sẽ cài phiên bản mới nhất (8.4) nếu PHP chưa được cài đặt."
  exit 1
}

# Kiểm tra xem phiên bản PHP đã được cung cấp chưa
if [ -z "$1" ]; then
  if command -v php > /dev/null 2>&1; then
    read -p "Nhập phiên bản PHP bạn muốn cài đặt hoặc cập nhật: " PHP_VERSION
  else
    read -p "Nhập phiên bản PHP bạn muốn cài đặt (bỏ trống để cài phiên bản mới nhất - 8.4): " PHP_VERSION
    if [ -z "$PHP_VERSION" ]; then
      PHP_VERSION="8.4"
    fi
  fi
else
  PHP_VERSION="$1"
fi

# Hàm kiểm tra phiên bản PHP hiện tại
check_php_version() {
  if command -v php > /dev/null 2>&1; then
    CURRENT_PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
    echo "Phiên bản PHP hiện tại: $CURRENT_PHP_VERSION"
  else
    CURRENT_PHP_VERSION=""
    echo "Không có phiên bản PHP nào được cài đặt trên hệ thống."
  fi
}

# Gỡ bỏ PHP cũ nếu có phiên bản cũ hơn
remove_old_php() {
  echo "Gỡ bỏ PHP cũ..."
  sudo apt purge -y php* 
  sudo apt autoremove -y
  sudo apt autoclean -y
}

# Cài đặt PHP mới
install_php() {
  echo "Cài đặt PHP $PHP_VERSION và các module cần thiết..."
  sudo add-apt-repository ppa:ondrej/php -y
  sudo apt update
  sudo apt install -y php$PHP_VERSION php$PHP_VERSION-fpm php$PHP_VERSION-cli php$PHP_VERSION-mysql php$PHP_VERSION-curl php$PHP_VERSION-json php$PHP_VERSION-cgi php$PHP_VERSION-gd php$PHP_VERSION-mbstring php$PHP_VERSION-xml php$PHP_VERSION-zip
}

# Sửa đổi các file cấu hình nếu cần thiết
update_config_files() {
  echo "Cập nhật các file cấu hình..."
  
  # Sửa đổi các file php.ini
  PHP_INI_FILES=(
      "/etc/php/$PHP_VERSION/cli/php.ini"
      "/etc/php/$PHP_VERSION/fpm/php.ini"
      "/etc/php/$PHP_VERSION/apache2/php.ini"
  )
  for INI_FILE in "${PHP_INI_FILES[@]}"; do
      if [ -f "$INI_FILE" ]; then
          sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 100M/' "$INI_FILE"
          sudo sed -i 's/post_max_size = .*/post_max_size = 100M/' "$INI_FILE"
          sudo sed -i 's/max_execution_time = .*/max_execution_time = 600/' "$INI_FILE"
          sudo sed -i 's/max_input_time = .*/max_input_time = 600/' "$INI_FILE"
          sudo sed -i 's/memory_limit = .*/memory_limit = 1G/' "$INI_FILE"
          echo "Sửa đổi cấu hình php.ini ($INI_FILE) cho PHP phiên bản $PHP_VERSION"
      else
          echo "Không tìm thấy file php.ini tại $INI_FILE"
      fi
  done

  # Cập nhật cấu hình Nginx
  echo "Cập nhật cấu hình Nginx trong thư mục /etc/nginx/sites-available/..."
  nginx_conf_dir="/etc/nginx/sites-available/"
  nginx_conf_files=("$nginx_conf_dir"*)

  for file in "${nginx_conf_files[@]}"; do
    if [ -f "$file" ]; then
      sudo sed -i "s/php$CURRENT_PHP_VERSION-fpm\.sock/php${PHP_VERSION}-fpm.sock/g" "$file"
    fi
  done

  # Cập nhật cấu hình PHP-FPM
  echo "Cập nhật cấu hình PHP-FPM..."
  php_fpm_conf_files=("/etc/php/$PHP_VERSION/fpm/pool.d/www.conf" "/etc/php/$PHP_VERSION/cli/php.ini")

  for file in "${php_fpm_conf_files[@]}"; do
    if [ -f "$file" ]; then
      sudo sed -i "s/php$CURRENT_PHP_VERSION/php$PHP_VERSION/g" "$file"
    fi
  done

  # Khởi động lại PHP-FPM và Nginx
  sudo systemctl restart php$PHP_VERSION-fpm
  sudo systemctl restart nginx

  # Cập nhật cấu hình Apache
  echo "Cập nhật cấu hình Apache..."
  apache_conf_files=("/etc/apache2/sites-available/*.conf" "/etc/apache2/ports.conf" "/etc/apache2/mods-enabled/fastcgi.conf")

  for file in $apache_conf_files; do
    if [ -f "$file" ]; then
      sudo sed -i "s/php$CURRENT_PHP_VERSION/php$PHP_VERSION/g" "$file"
    fi
  done

  # Vô hiệu hóa module PHP phiên bản cũ và kích hoạt module PHP $PHP_VERSION cho Apache
  sudo a2dismod php$CURRENT_PHP_VERSION
  sudo a2enmod php$PHP_VERSION

  # Khởi động lại Apache
  sudo systemctl restart apache2

  # Sửa đổi các file cấu hình khác có chứa thông tin phiên bản PHP
  echo "Sửa đổi các file cấu hình khác có chứa thông tin phiên bản PHP..."
  other_conf_files=(
      "/etc/apache2/mods-available/rpaf.conf"
      "/etc/apache2/mods-available/rpaf.load"
      "/etc/nginx/sites-available/default"
  )

  for file in "${other_conf_files[@]}"; do
    if [ -f "$file" ]; then
      sudo sed -i "s/php$CURRENT_PHP_VERSION/php$PHP_VERSION/g" "$file"
    fi
  done
}

# Kiểm tra phiên bản PHP hiện tại và cài đặt hoặc cập nhật
check_php_version
if [ -z "$CURRENT_PHP_VERSION" ]; then
  echo "Không có phiên bản PHP nào được cài đặt. Tiến hành cài đặt mới PHP $PHP_VERSION..."
  install_php
else
  if [ -z "$PHP_VERSION" ]; then
    echo "Không có phiên bản PHP được chỉ định rõ ràng, vì vậy sẽ không tiến hành cập nhật."
  elif [ "$(printf '%s\n' "$PHP_VERSION" "$CURRENT_PHP_VERSION" | sort -V | head -n1)" != "$PHP_VERSION" ]; then
    echo "Phiên bản yêu cầu ($PHP_VERSION) mới hơn phiên bản hiện tại ($CURRENT_PHP_VERSION). Tiến hành cập nhật..."
    remove_old_php
    install_php
    update_config_files
  else
    echo "Phiên bản hiện tại ($CURRENT_PHP_VERSION) đã là phiên bản mới nhất hoặc phiên bản yêu cầu ($PHP_VERSION). Không cần cập nhật."
  fi
fi

# Kiểm tra phiên bản PHP hiện tại sau khi cài đặt hoặc cập nhật
php -v

echo "Quá trình cài đặt hoặc cập nhật PHP đã hoàn tất!"