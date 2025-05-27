#!/bin/bash

# Rangli chiqish uchun o'zgaruvchilar
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Xatolarni loglash uchun funksiya
log_error() {
    echo -e "${RED}XATO: $1${NC}" >&2
    exit 1
}

# Muvaffaqiyat xabarini chiqarish uchun funksiya
log_success() {
    echo -e "${GREEN}MUVAFFAQIYAT: $1${NC}"
}

# Ogohlantirish xabarini chiqarish uchun funksiya
log_warning() {
    echo -e "${YELLOW}OGOHLANTIRISH: $1${NC}"
}

# Tekshiruv va jarayon boshlanishi
echo -e "${GREEN}Yii2 dasturini sozlash jarayoni boshlanmoqda...${NC}"

# 1. Paketlar bazasini yangilash
echo "Paketlar ro'yxati yangilanmoqda..."
sudo apt-get update -y || log_error "Paketlar ro'yxatini yangilash amalga oshmadi."

# 2. Docker tekshiruvi
echo "Docker o'rnatilganligi tekshirilmoqda..."
if ! command -v docker &> /dev/null; then
    log_error "Docker o'rnatilmagan. Iltimos, Docker 28.1.1 ni qo'lda o'rnating."
else
    log_success "Docker o'rnatilgan."
fi

# 3. Docker Compose tekshiruvi
echo "Docker Compose o'rnatilganligi tekshirilmoqda..."
if ! command -v docker-compose &> /dev/null; then
    log_error "Docker Compose o'rnatilmagan. Iltimos, Docker Compose v2.35.1 ni qo'lda o'rnating."
else
    log_success "Docker Compose o'rnatilgan."
fi

# 4. PHP versiyasini tekshirish
echo "PHP versiyasi tekshirilmoqda..."
PHP_INSTALLED_VERSION=$(php -v | head -n 1 | awk '{print $2}')
if [[ "$PHP_INSTALLED_VERSION" != 8.1.* ]]; then
    log_warning "O'rnatilgan PHP versiyasi $PHP_INSTALLED_VERSION, tavsiya etilgan 8.1.x"
else
    log_success "PHP versiyasi $PHP_INSTALLED_VERSION mos keladi."
fi

# 5. Composer tekshiruvi va o'rnatish
echo "Composer o'rnatilganligi tekshirilmoqda..."
if ! command -v composer &> /dev/null; then
    echo "Composer 2.8.8 o'rnatilmoqda..."
    EXPECTED_SIGNATURE=$(wget -qO - https://composer.github.io/installer.sig) || log_error "Composer imzosini olish amalga oshmadi."
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" || log_error "Composer o'rnatuvchisini yuklab olish amalga oshmadi."
    ACTUAL_SIGNATURE=$(php -r "echo hash_file('sha384', 'composer-setup.php');")
    
    if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then
        rm composer-setup.php
        log_error "Composer o'rnatuvchisi imzosida xato."
    fi
    
    php composer-setup.php --version=2.8.8 || log_error "Composer o'rnatish amalga oshmadi."
    sudo mv composer.phar /usr/local/bin/composer || log_error "Composer-ni /usr/local/bin ga ko'chirish amalga oshmadi."
    rm composer-setup.php
    log_success "Composer 2.8.8 muvaffaqiyatli o'rnatildi."
else
    log_success "Composer allaqachon o'rnatilgan."
fi

# 6. Loyiha katalogining huquqlarini www-data ga berish
echo "Loyiha katalogi huquqlari yangilanmoqda..."
sudo chown -R www-data:www-data "$(pwd)" || log_error "Fayl egasi o'zgartirishda xato yuz berdi."
sudo find "$(pwd)" -type d -exec chmod 755 {} \; || log_error "Kataloglar uchun ruxsat o'rnatishda xato."
sudo find "$(pwd)" -type f -exec chmod 644 {} \; || log_error "Fayllar uchun ruxsat o'rnatishda xato."
log_success "Loyiha katalogi huquqlari www-data foydalanuvchisiga berildi."

# 7. www-data foydalanuvchisi sifatida composer install ishga tushirilmoqda
echo "www-data foydalanuvchisi sifatida composer install ishga tushirilmoqda..."
sudo -u www-data composer install || log_error "Composer install amalga oshirilmadi."
log_success "Composer bog'liqliklari o'rnatildi."

# 8. Composer fund (moliyaviy yordam haqida ma'lumot)
echo "Composer loyihasi uchun moliyaviy yordam ma'lumotlari..."
sudo -u www-data composer fund || log_warning "Composer fund ma'lumotlarini olish amalga oshmadi."
log_success "Composer fund ma'lumotlari ko'rsatildi."

# 9. Kerakli kataloglar va fayllar uchun ruxsatlar o'rnatish
echo "Kerakli kataloglar va fayllar uchun ruxsatlar o'rnatilmoqda..."
sudo mkdir -p backend/runtime backend/web/assets console/runtime frontend/runtime frontend/web/assets || log_error "Kataloglarni yaratish amalga oshmadi."
sudo touch yii yii_test yii_test.bat || log_error "Fayllarni yaratish amalga oshmadi."
sudo chown -R www-data:www-data backend console frontend yii yii_test yii_test.bat || log_error "Katalog va fayl egaligini o'rnatish amalga oshmadi."
sudo chmod -R 775 backend console frontend yii yii_test yii_test.bat || log_error "Katalog va fayl ruxsatlarini o'rnatish amalga oshmadi."
sudo chmod -R 775 /var/www/html || log_error "Loyiha katalogi ruxsatlarini o'rnatish amalga oshmadi."
log_success "Kataloglar va fayllar yaratildi, ruxsatlar o'rnatildi."

# 10. Yii2 dasturini ishga tushirish (Production muhiti)
echo "Yii2 dasturi Production muhiti uchun sozlanmoqda..."
sudo -u www-data php init --env=Production --overwrite=All --no-interaction || log_error "Yii2 dasturini sozlash amalga oshmadi."

# 11. common/config/main-local.php faylini PostgreSQL sozlamalari bilan yangilash
echo "Ma'lumotlar bazasi sozlamalarini PostgreSQL uchun yangilamoqda..."
CONFIG_FILE="common/config/main-local.php"
if [ -f "$CONFIG_FILE" ]; then
    sudo -u www-data bash -c "cat > $CONFIG_FILE" << 'EOL'
<?php
return [
    'components' => [
        'db' => [
            'class' => \yii\db\Connection::class,
            'dsn' => 'mysql:host=' . getenv('DB_HOST') . ';port=' . getenv('DB_PORT') . ';dbname=' . getenv('DB_DATABASE'),
            'username' => getenv('DB_USERNAME'),
            'password' => getenv('DB_PASSWORD'),
            'charset' => 'utf8',
        ],
        'mailer' => [
            'class' => \yii\symfonymailer\Mailer::class,
            'viewPath' => '@common/mail',
            'useFileTransport' => true,
        ],
    ],
];
EOL
    log_success "Ma'lumotlar bazasi sozlamalari PostgreSQL uchun yangilandi."
else
    log_error "$CONFIG_FILE fayli topilmadi."
fi

log_success "Yii2 dasturi sozlandi."

# 12. Docker konteynerlarini ishga tushirish
echo "Docker konteynerlari ishga tushirilmoqda..."
docker-compose up -d --build --force-recreate || log_error "Docker konteynerlarini ishga tushirish amalga oshmadi."
log_success "Docker konteynerlari ishga tushirildi."

# 13. Yakuniy xabar
echo ""
echo -e "${GREEN}✅ Dastur endi ishlamoqda!${NC}"
echo -e "${GREEN}🌐 Tashrif buyuring: http://127.0.0.1:8010${NC}"
echo -e "${GREEN}Powered by https://yii.devit.uz${NC}"
