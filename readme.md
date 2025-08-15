# PHP + PHPUnit (Docker)

## Common commands
Build image:
  docker compose build

Build container
  docker compose up

Open app CLI / get into app container:
  docker exec -it sql-builder-app bash

Run tests:
  composer test

Run coverage in terminal:
  composer test:coverage
