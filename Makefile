# Docker Travian Makefile
# Simple commands for managing the project

.PHONY: help build up down restart logs shell test clean

# Default target
help:
	@echo "Docker Travian - Make Commands"
	@echo "=============================="
	@echo "make build    - Build Docker images"
	@echo "make up       - Start all services"
	@echo "make down     - Stop all services"
	@echo "make restart  - Restart all services"
	@echo "make logs     - View logs"
	@echo "make shell    - Enter app container"
	@echo "make test     - Run tests"
	@echo "make clean    - Clean up containers and volumes"
	@echo "make install  - Install dependencies"
	@echo "make migrate  - Run database migrations"
	@echo "make quality  - Run quality checks"

# Build Docker images
build:
	docker-compose build --no-cache

# Start services
up:
	docker-compose up -d
	@echo "Services started! Access at http://localhost:8080"

# Stop services  
down:
	docker-compose down

# Restart services
restart: down up

# View logs
logs:
	docker-compose logs -f

# Shell into app container
shell:
	docker-compose exec app /bin/bash

# Run tests
test:
	docker-compose exec app vendor/bin/phpunit
	docker-compose exec app npm test

# Clean everything
clean:
	docker-compose down -v
	docker system prune -af

# Install dependencies
install:
	docker-compose exec app composer install
	docker-compose exec app npm install

# Run migrations
migrate:
	docker-compose exec app php artisan migrate

# Quality checks
quality:
	./scripts/quality-gate.sh
