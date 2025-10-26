# Multi-stage Dockerfile for Docker Travian PHP Application
# Optimized for production with security and performance best practices

# Build stage for Composer dependencies
FROM composer:2.6 AS composer-build
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader --no-scripts --no-interaction

# Build stage for Node.js assets
FROM node:20-alpine AS node-build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

# Production PHP runtime
FROM php:8.2-fpm-alpine AS production

# Install system dependencies and PHP extensions
RUN apk add --no-cache \
    nginx \
    supervisor \
    mysql-client \
    redis \
    curl \
    zip \
    unzip \
    git \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    icu-dev \
    oniguruma-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo \
        pdo_mysql \
        mysqli \
        gd \
        zip \
        intl \
        mbstring \
        opcache \
        bcmath \
        sockets \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# Create application user (non-root)
RUN addgroup -g 1000 -S travian && \
    adduser -u 1000 -S travian -G travian -h /var/www -s /bin/sh

# Set working directory
WORKDIR /var/www/html

# Copy application files
COPY --chown=travian:travian . .
COPY --from=composer-build --chown=travian:travian /app/vendor ./vendor
COPY --from=node-build --chown=travian:travian /app/public/build ./public/build

# Copy configuration files
COPY docker/app/php.ini /usr/local/etc/php/conf.d/99-travian.ini
COPY docker/app/php-fpm.conf /usr/local/etc/php-fpm.d/www.conf
COPY docker/app/nginx.conf /etc/nginx/nginx.conf
COPY docker/app/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create necessary directories and set permissions
RUN mkdir -p \
    /var/www/html/var/cache \
    /var/www/html/var/sessions \
    /var/www/html/var/uploads \
    /var/www/html/logs \
    /var/log/nginx \
    /var/log/php \
    /run/nginx \
    /run/php \
    && chown -R travian:travian \
        /var/www/html/var \
        /var/www/html/logs \
        /var/log/nginx \
        /var/log/php \
        /run/nginx \
        /run/php \
    && chmod -R 755 /var/www/html/var \
    && chmod -R 755 /var/www/html/logs

# Security: Remove sensitive files
RUN rm -f \
    /var/www/html/.env.example \
    /var/www/html/docker-compose.yml \
    /var/www/html/Dockerfile \
    /var/www/html/README.md

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Copy entrypoint script
COPY docker/app/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose port
EXPOSE 8080

# Switch to non-root user
USER travian

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Metadata
LABEL maintainer="Docker Travian Team <devops@docker-travian.game>" \
      version="1.0.0" \
      description="Enterprise-grade containerized Travian game server" \
      org.opencontainers.image.title="Docker Travian" \
      org.opencontainers.image.description="Containerized Travian game server with PHP 8.2, Nginx, and Redis" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.vendor="Docker Travian Team" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/ghenghis/docker-travian"
