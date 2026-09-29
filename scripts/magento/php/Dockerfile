# ─────────────────────────────────────────────────────────────
# stackisle — Magento PHP-FPM image
# PHP extensions required by Magento 2.4.x + Composer.
# www-data is remapped to the host user's UID/GID so files in the
# bind-mounted src/ stay owned by you (no root-owned files on the host).
# ─────────────────────────────────────────────────────────────
ARG PHP_VERSION=8.3
ARG COMPOSER_VERSION=2.8

FROM composer:${COMPOSER_VERSION} AS composer

FROM php:${PHP_VERSION}-fpm

ARG UID=1000
ARG GID=1000

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libfreetype6-dev libjpeg62-turbo-dev libpng-dev libwebp-dev \
      libicu-dev libxslt1-dev libzip-dev \
      git unzip mariadb-client \
 && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
 && docker-php-ext-install -j"$(nproc)" \
      bcmath gd intl pdo_mysql soap sockets xsl zip opcache ftp \
 && rm -rf /var/lib/apt/lists/*
# Already built into the official image: ctype curl dom fileinfo filter hash
# iconv json libxml mbstring openssl pcre simplexml sodium tokenizer xmlwriter

COPY --from=composer /usr/bin/composer /usr/local/bin/composer
COPY zz-magento.ini /usr/local/etc/php/conf.d/zz-magento.ini

# Run as the host user (non-unique ids allowed in case they already exist)
RUN groupmod -o -g "${GID}" www-data \
 && usermod  -o -u "${UID}" -g "${GID}" www-data \
 && mkdir -p /var/www/html /var/www/.composer \
 && chown -R www-data:www-data /var/www

ENV COMPOSER_HOME=/var/www/.composer \
    COMPOSER_MEMORY_LIMIT=-1

WORKDIR /var/www/html
