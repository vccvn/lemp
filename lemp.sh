#!/bin/bash

# Bước 1: Cập nhật hệ thống và cài đặt các gói cần thiết
echo "Cập nhật hệ thống và cài đặt các gói cần thiết..."
sudo apt update
sudo apt install -y apache2 php php-fpm php-cli php-mysql php-curl php-json php-cgi php-gd php-mbstring php-xml php-zip mysql-server nginx unzip build-essential apache2-dev make net-tools zip unzip nodejs npm supervisor

# Bước 2: Cài đặt libapache2-mod-fastcgi
echo "Cài đặt libapache2-mod-fastcgi..."
wget https://mirrors.edge.kernel.org/ubuntu/pool/multiverse/liba/libapache-mod-fastcgi/libapache2-mod-fastcgi_2.4.7~0910052141-1.2_amd64.deb
sudo dpkg -i libapache2-mod-fastcgi_2.4.7~0910052141-1.2_amd64.deb

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

# Bước 4: Cấu hình Apache để lắng nghe trên cổng 8080
echo "Cấu hình Apache để lắng nghe trên cổng 8080..."
echo "Listen 8080" | sudo tee /etc/apache2/ports.conf

# Bước 5: Sửa đổi file cấu hình VirtualHost
echo "Sửa đổi file cấu hình VirtualHost..."
sudo bash -c 'cat > /etc/apache2/sites-available/000-default.conf << EOF
<VirtualHost *:8080>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF'

# Bước 6: Tải lại cấu hình Apache
echo "Tải lại cấu hình Apache..."
sudo systemctl reload apache2

# Bước 7: Kích hoạt module actions
echo "Kích hoạt module actions..."
sudo a2enmod actions

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

# Bước 10: Cấu hình Nginx
echo "Cấu hình Nginx..."
sudo bash -c 'cat > /etc/nginx/sites-available/default << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;

    # Add index.php to the list if you are using PHP
    index index.php index.html index.htm index.nginx-debian.html;

    server_name _;

    location ~* ^/(static/|wp-content/vcc|wp-admin/|wp-includes/).+\.(?:css|cur|js|jpe?g|gif|htc|ico|png|html|xml|otf|ttf|eot|woff|woff2|svg)$ {
        try_files \$uri \$uri/ /index.php;
        client_max_body_size 100M;
        access_log off;
        expires 30d;
        add_header Cache-Control public;
        tcp_nodelay off;
        open_file_cache max=3000 inactive=120s;
        open_file_cache_valid 45s;
        open_file_cache_min_uses 2;
        open_file_cache_errors off;
    }

    location / {
        fastcgi_read_timeout 3000;
        proxy_read_timeout 3000;
        proxy_connect_timeout 3000;
        proxy_send_timeout 3000;
        send_timeout 3000;
        proxy_set_header X-Real-IP  \$remote_addr;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_pass http://127.0.0.1:8080;
        client_max_body_size 100M;
    }

    location ~ \.php$ {
        proxy_read_timeout 3000;
        proxy_connect_timeout 3000;
        proxy_send_timeout 3000;
        send_timeout 3000;
        fastcgi_pass unix:/run/php/php'"$PHP_VERSION"'-fpm.sock;
        fastcgi_read_timeout 3000;
        include snippets/fastcgi-php.conf;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF'

# Bước 11: Khởi động lại Nginx
echo "Khởi động lại Nginx..."
sudo systemctl reload nginx

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
echo "Cài đặt certbot..."
sudo snap install --classic certbot

# Bước 15: Cài đặt pm2 qua npm
echo "Cài đặt pm2 qua npm..."
sudo npm install -g pm2

# Bước 16: Khởi động lại Apache, Nginx và PHP-FPM
echo "Khởi động lại Apache, Nginx và PHP-FPM..."
sudo systemctl restart apache2
sudo systemctl restart nginx
sudo systemctl restart php"$PHP_VERSION"-fpm

echo "Quá trình cài đặt và cấu hình đã hoàn tất!"