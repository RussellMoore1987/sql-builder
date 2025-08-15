# Lightweight dev/test image with Composer baked in
FROM php:8.3-cli-bookworm

# Install system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    git unzip zip \
 && rm -rf /var/lib/apt/lists/*

# Enable fast code coverage
RUN pecl install pcov \
 && docker-php-ext-enable pcov \
 && printf "pcov.enabled=0\npcov.directory=/app\n" > /usr/local/etc/php/conf.d/pcov.ini

# Add Composer from official image
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app

# Leverage Docker layer cache for deps when lock exists
COPY composer.json composer.lock* ./
RUN if [ -f composer.json ]; then composer install --no-interaction --no-plugins --no-scripts --no-progress || true; fi

# Trust the bind-mounted working dir to avoid Git 'dubious ownership' in Docker/WSL/Windows
RUN git config --global --add safe.directory /app

# App code (mounted at runtime by compose; copy keeps image usable without bind mount too)
COPY . .

# Default command can be overridden by docker compose
CMD ["php", "-v"]
