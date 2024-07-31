#!/bin/bash

# Định nghĩa các thư mục cần thiết
TARGET_DIR_HTML="/var/www/html"
TARGET_DIR_SOURCES="/var/www/sources"
SHELL_DIR="/var/www/shell"

# Kiểm tra và khởi tạo thư mục /var/www/sources nếu chưa tồn tại
if [ ! -d "$TARGET_DIR_SOURCES" ]; then
  echo "Creating directory $TARGET_DIR_SOURCES..."
  mkdir -p $TARGET_DIR_SOURCES
fi

# Kiểm tra và khởi tạo thư mục /var/www/shell nếu chưa tồn tại
if [ ! -d "$SHELL_DIR" ]; then
  echo "Creating directory $SHELL_DIR..."
  mkdir -p $SHELL_DIR
fi

# Kiểm tra nếu số lượng tham số ít hơn 1
if [ "$#" -lt 1 ]; then
  # Yêu cầu nhập URL git
  read -p "Enter the Git URL: " GIT_URL

  # Yêu cầu nhập tên thư mục hoặc để trống nếu muốn mặc định
  read -p "Enter the folder name (leave empty for default): " CLONE_FOLDER

  # Hỏi người dùng có phải là project Laravel không
  read -p "Is this a Laravel project? (yes/no): " IS_LARAVEL
  if [ "$IS_LARAVEL" == "yes" ]; then
    LARAVEL_FLAG="--laravel"
  else
    LARAVEL_FLAG=""
  fi
else
  # Lấy tham số đầu vào
  GIT_URL=$1
  CLONE_FOLDER=$2
  LARAVEL_FLAG=$3
fi

# Nếu tham số thứ 2 là --laravel, đặt CLONE_FOLDER là rỗng và LARAVEL_FLAG là tham số thứ 2
if [ "$2" == "--laravel" ]; then
  CLONE_FOLDER=""
  LARAVEL_FLAG=$2
elif [ "$3" == "--laravel" ]; then
  LARAVEL_FLAG=$3
fi

# Function để clone repository và cd vào thư mục
clone_and_cd() {
  local target_dir=$1
  local git_url=$2
  local folder_name=$3

  cd $target_dir

  # Kiểm tra nếu folder_name không được truyền vào
  if [ -z "$folder_name" ]; then
    git clone $git_url
    folder_name=$(basename $git_url .git)
  else
    git clone $git_url $folder_name
  fi

  cd $target_dir/$folder_name
}

# Thực hiện clone vào thư mục /var/www/sources
echo "Cloning repository into $TARGET_DIR_SOURCES..."
clone_and_cd $TARGET_DIR_SOURCES $GIT_URL $CLONE_FOLDER

# Xác định tên folder nếu chưa được đặt
if [ -z "$CLONE_FOLDER" ]; then
  CLONE_FOLDER=$(basename $GIT_URL .git)
fi

# Copy project từ /var/www/sources sang /var/www/html
echo "Copying project from $TARGET_DIR_SOURCES/$CLONE_FOLDER to $TARGET_DIR_HTML/$CLONE_FOLDER..."
cp -r $TARGET_DIR_SOURCES/$CLONE_FOLDER $TARGET_DIR_HTML/

# Tạo nội dung cho file bash mới
SHELL_SCRIPT_CONTENT=$(cat <<EOF
#!/bin/bash

echo "started..."
cd /var/www/sources/$CLONE_FOLDER/

echo "cd /var/www/sources/$CLONE_FOLDER/"
echo "git pull"

git pull

echo "Copying /var/www/sources/$CLONE_FOLDER/ to /var/www/html/$CLONE_FOLDER/ ..."

cp -r /var/www/sources/$CLONE_FOLDER/* /var/www/html/$CLONE_FOLDER/
cd /var/www/html/$CLONE_FOLDER/

echo "cd /var/www/html/$CLONE_FOLDER/"
echo "sudo chown -Rf www-data:www-data themes storage public/static/contents public/static/assets resources/views/themes"

# Thay đổi quyền sở hữu của các thư mục cần thiết cho www-data
sudo chown -Rf www-data:www-data themes storage public/static/contents public/static/assets resources/views/themes
# pm2 stop api-server.js
# composer update gomee/*
# php artisan migrate
# pm2 start api-server.js
echo "done"
EOF
)

# Nếu là project Laravel, thêm các bước xử lý bổ sung vào nội dung script
if [ "$LARAVEL_FLAG" == "--laravel" ]; then
  # Kiểm tra và cài đặt Composer nếu chưa tồn tại
  if ! command -v composer &> /dev/null; then
    echo "Composer is not installed. Installing Composer..."
    EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')"
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    ACTUAL_CHECKSUM="$(php -r 'echo hash_file("sha384", "composer-setup.php");')"
    if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
      echo 'ERROR: Invalid installer checksum' >&2
      rm composer-setup.php
      exit 1
    fi
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer
    rm composer-setup.php
  else
    echo "Composer is already installed."
  fi

  LARAVEL_STEPS=$(cat <<'LARAVEL_EOF'

echo "Checking for .env file"
if [ ! -f ".env" ]; then
  if [ -f ".env.example" ]; then
    cp .env.example .env
    echo "Copied .env.example to .env"
  elif [ -f ".env.development" ]; then
    cp .env.development .env
    echo "Copied .env.development to .env"
  elif [ -f ".env.production" ]; then
    cp .env.production .env
    echo "Copied .env.production to .env"
  else
    echo "No suitable .env file found"
  fi
fi

echo "Running composer install"
composer install

# Thay đổi quyền sở hữu của các thư mục cần thiết cho www-data
sudo chown -Rf www-data:www-data themes storage public/static/contents public/static/assets resources/views/themes
LARAVEL_EOF
)
  SHELL_SCRIPT_CONTENT="${SHELL_SCRIPT_CONTENT}${LARAVEL_STEPS}"
fi

# Tạo file bash mới trong thư mục /var/www/shell
echo "$SHELL_SCRIPT_CONTENT" > $SHELL_DIR/$CLONE_FOLDER.sh

# Cấp quyền thực thi cho file bash
chmod +x $SHELL_DIR/$CLONE_FOLDER.sh

echo "Setup complete!"
echo "Shell script created at $SHELL_DIR/$CLONE_FOLDER.sh"