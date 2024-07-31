#!/bin/bash

# Bước 1: Cập nhật hệ thống và cài đặt các gói cần thiết
echo "Cập nhật hệ thống và cài đặt các gói cần thiết..."
sudo apt update

# Bước 3: Sửa đổi các file php.ini
echo "Sửa đổi các file php.ini..."
PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
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
        sudo sed -i 's/memory_limit = .*/memory_limit = 1G/' "$INI_FILE"
        echo "Sửa đổi cấu hình php.ini ($INI_FILE) cho PHP phiên bản $PHP_VERSION"
    else
        echo "Không tìm thấy file php.ini tại $INI_FILE"
    fi
done


# Bước 8: Sửa đổi file fastcgi.conf
echo "Sửa đổi file fastcgi.conf..."
sudo bash -c 'cat > /etc/apache2/mods-enabled/fastcgi.conf << EOF
<IfModule mod_fastcgi.c>
  AddHandler fastcgi-script .fcgi
  FastCgiIpcDir /var/lib/apache2/fastcgi
  AddType application/x-httpd-fastphp .php
  Action application/x-httpd-fastphp /php-fcgi
  Alias /php-fcgi /usr/lib/cgi-bin/php-fcgi
  FastCgiExternalServer /usr/lib/cgi-bin/php-fcgi -socket /run/php/php'"$PHP_VERSION"'-fpm.sock -idle-timeout 900 -pass-header Authorization
  <Directory /usr/lib/cgi-bin>
    Require all granted
  </Directory>
</IfModule>
EOF'

# Bước 9: Tải lại cấu hình Apache
echo "Tải lại cấu hình Apache..."
sudo systemctl reload apache2

# Bước 12: Cài đặt và cấu hình mod_rpaf cho Apache
echo "Cài đặt và cấu hình mod_rpaf cho Apache..."
wget https://github.com/gnif/mod_rpaf/archive/stable.zip
unzip stable.zip
cd mod_rpaf-stable
make
sudo make install

# Bước 13: Cấu hình mod_rpaf
echo "Cấu hình mod_rpaf..."
YOUR_SERVER_IP=$(hostname -I | awk '{print $1}')
sudo bash -c 'cat > /etc/apache2/mods-available/rpaf.load << EOF
LoadModule rpaf_module /usr/lib/apache2/modules/mod_rpaf.so
EOF'

sudo bash -c 'cat > /etc/apache2/mods-available/rpaf.conf << EOF
<IfModule mod_rpaf.c>
    RPAF_Enable             On
    RPAF_Header             X-Real-Ip
    RPAF_ProxyIPs           '"$YOUR_SERVER_IP"'
    RPAF_SetHostName        On
    RPAF_SetHTTPS           On
    RPAF_SetPort            On
</IfModule>
EOF'

# Kích hoạt mod_rpaf và khởi động lại Apache
echo "Kích hoạt mod_rpaf và khởi động lại Apache..."
sudo a2enmod rpaf
sudo systemctl reload apache2

# Bước 14: Cài đặt certbot
# Bước 16: Khởi động lại Apache, Nginx và PHP-FPM
echo "Khởi động lại Apache, Nginx và PHP-FPM..."
sudo systemctl restart apache2
sudo systemctl restart nginx
sudo systemctl restart php"$PHP_VERSION"-fpm

echo "Quá trình cài đặt và cấu hình đã hoàn tất!"