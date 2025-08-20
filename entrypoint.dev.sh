#!/usr/bin/env sh
set -eu

log() { printf "\033[1;36m[entrypoint]\033[0m %s\n" "$*"; }

git -C /app rev-parse >/dev/null 2>&1 && git config --global --add safe.directory /app || true

export COMPOSER_MEMORY_LIMIT="${COMPOSER_MEMORY_LIMIT:--1}"
export COMPOSER_PROCESS_TIMEOUT="${COMPOSER_PROCESS_TIMEOUT:-1200}"

if [ ! -d vendor ] || [ ! -f vendor/autoload.php ] || [ ! -f .docker/composer.lock.hash ] || ! cmp -s composer.lock .docker/composer.lock.hash 2>/dev/null; then
  log "Installing Composer dependencies…"
  mkdir -p .docker
  composer install --no-interaction --prefer-dist --no-progress
  cp -f composer.lock .docker/composer.lock.hash 2>/dev/null || true
else
  log "Deps up to date; skipping composer install."
fi

log "The Docker container is up and running and ready to use."
# 👇 Hand off to Compose's command (["tail","-f","/dev/null"]) so the container stays up
exec "$@"