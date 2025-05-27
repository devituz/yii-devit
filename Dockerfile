FROM php:8.1-fpm AS builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       lsb-release \
       ca-certificates \
       curl \
       git \
       unzip \
       libzip-dev \
       libicu-dev \
       libonig-dev \
       libxml2-dev \
       libjpeg-dev \
       libpng-dev \
       libfreetype6-dev \
       libcurl4-openssl-dev \
       pkg-config \
  && docker-php-ext-configure intl \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install -j$(nproc) \
       pdo_mysql \
       mbstring \
       xml \
       zip \
       curl \
       bcmath \
       intl \
       gd \
  && rm -rf /var/lib/apt/lists/*

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

FROM php:8.1-fpm

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libzip4 \
      libjpeg62-turbo \
      libpng16-16 \
      libfreetype6 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
COPY --from=builder /usr/local/bin/composer /usr/local/bin/composer

WORKDIR /var/www/html

COPY . .

RUN composer install --no-interaction --prefer-dist \
 && echo "0" | php init --env=Development --overwrite=All \
 && mkdir -p runtime web/assets \
 && chown -R www-data:www-data runtime web/assets \
 && chmod -R 777 /var/www/html

EXPOSE 9000
CMD ["php-fpm"]
