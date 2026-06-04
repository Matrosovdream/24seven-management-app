# ============================================================================
#  Laravel — Makefile
#
#  Dev  uses compose.dev.yaml  (commands run in the `workspace` container).
#  Prod uses compose.prod.yaml (commands run in the `php-fpm` container).
#
#  Run `make` or `make help` to see all targets.
# ============================================================================

DEV_FILE  ?= compose.dev.yaml
PROD_FILE ?= compose.prod.yaml

DC      := docker compose
DC_DEV  := $(DC) -f $(DEV_FILE)
DC_PROD := $(DC) -f $(PROD_FILE)

DEV_WS   := $(DC_DEV) exec workspace      # PHP CLI + Composer + Node
PROD_PHP := $(DC_PROD) exec php-fpm

# Pass extra args, e.g.  make dev-seed ARGS="--class=DatabaseSeeder"
ARGS ?=

.DEFAULT_GOAL := help

.PHONY: help \
        dev-build dev-up dev-down dev-restart dev-logs dev-shell dev-bash \
        dev-migrate dev-seed dev-wipe dev-test dev-generate-key dev-wait-db \
        dev-npm dev-vite dev-horizon-logs dev-reverb-logs dev-es-health \
        prod-build prod-down prod-restart prod-shell prod-bash prod-migrate \
        prod-seed prod-wipe prod-test prod-generate-key

help: ## Show this help
	@echo "Laravel — available make targets:"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ============================================================================
#  DEVELOPMENT  (compose.dev.yaml)
# ============================================================================
dev-build: ## Build images, start the dev stack and run migrations
	$(DC_DEV) up -d --build
	$(MAKE) --no-print-directory dev-wait-db
	$(DEV_WS) php artisan migrate

dev-up: ## Start the dev stack (no rebuild)
	$(DC_DEV) up -d

dev-down: ## Stop and remove dev containers (keeps volumes/data)
	$(DC_DEV) down

dev-restart: ## Restart the dev stack
	$(DC_DEV) restart

dev-logs: ## Tail logs for all dev services (ARGS="web php-fpm")
	$(DC_DEV) logs -f $(ARGS)

dev-shell: ## Open a bash shell in the workspace container
	$(DEV_WS) bash

dev-bash: ## Open a bash shell in the php-fpm (app) container
	$(DC_DEV) exec php-fpm bash

dev-migrate: ## Run migrations
	$(DEV_WS) php artisan migrate $(ARGS)

dev-seed: ## Run database seeders (ARGS="--class=...")
	$(DEV_WS) php artisan db:seed $(ARGS)

dev-wipe: ## Drop all tables, views and types
	$(DEV_WS) php artisan db:wipe

dev-test: ## Run the test suite (ARGS="--filter=Foo")
	$(DEV_WS) php artisan test $(ARGS)

dev-generate-key: ## Generate the application key
	$(DEV_WS) php artisan key:generate

dev-npm: ## Run an npm command in workspace (ARGS="install" / "run build")
	$(DEV_WS) bash -lc "npm $(ARGS)"

dev-vite: ## Start the Vite dev server in workspace (HMR on $VITE_PORT)
	$(DEV_WS) bash -lc "npm run dev -- --host 0.0.0.0"

dev-horizon-logs: ## Tail the Horizon worker logs
	$(DC_DEV) logs -f horizon

dev-reverb-logs: ## Tail the Reverb websocket server logs
	$(DC_DEV) logs -f reverb

dev-es-health: ## Show the Elasticsearch cluster health
	$(DC_DEV) exec elasticsearch curl -s http://localhost:9200/_cluster/health?pretty

dev-wait-db:
	@echo "⏳  Waiting for Postgres..."
	@until $(DC_DEV) exec -T postgres pg_isready -q >/dev/null 2>&1; do sleep 1; done
	@echo "✅  Postgres is ready"

# ============================================================================
#  PRODUCTION  (compose.prod.yaml)
# ============================================================================
prod-build: ## Build images, start the prod stack (waits for health) and migrate
	$(DC_PROD) up -d --build --wait
	$(PROD_PHP) php artisan migrate --force

prod-down: ## Stop and remove prod containers (keeps volumes/data)
	$(DC_PROD) down

prod-restart: ## Restart the prod stack
	$(DC_PROD) restart

prod-shell: ## Open an sh shell in the prod php-fpm container
	$(PROD_PHP) sh

prod-bash: ## Open a bash shell in the prod php-fpm container
	$(PROD_PHP) bash

prod-migrate: ## Run migrations (--force)
	$(PROD_PHP) php artisan migrate --force $(ARGS)

prod-seed: ## Run seeders (--force) (ARGS="--class=...")
	$(PROD_PHP) php artisan db:seed --force $(ARGS)

prod-wipe: ## DANGER: drop all tables, views and types (--force)
	$(PROD_PHP) php artisan db:wipe --force

prod-test: ## Run the test suite (requires dev dependencies)
	$(PROD_PHP) php artisan test $(ARGS)

prod-generate-key: ## Generate the application key (--force)
	$(PROD_PHP) php artisan key:generate --force
