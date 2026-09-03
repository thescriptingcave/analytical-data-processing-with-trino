.PHONY: up wait init load verify setup reset down purge trino logs ps

up:
	docker compose up -d

wait:
	@echo "Waiting for Trino to become ready..."
	@i=0; \
	until docker compose exec -T trino trino --execute "SELECT 1" >/dev/null 2>&1; do \
		i=$$((i + 1)); \
		if [ $$i -ge 60 ]; then \
			echo "ERROR: Trino did not become ready within 120 seconds."; \
			docker compose logs trino; \
			exit 1; \
		fi; \
		sleep 2; \
	done
	@echo "Trino is ready."

init: wait
	docker compose exec -T trino \
		trino --catalog iceberg --schema analytics \
		< ddl/schema.sql

load: wait
	docker compose exec -T trino \
		trino --catalog iceberg --schema analytics \
		< data/data.sql

verify: wait
	docker compose exec -T trino \
		trino --catalog iceberg --schema analytics \
		< ddl/verify.sql

setup: up wait init load verify

reset: wait
	docker compose exec -T trino \
		trino --catalog iceberg --schema analytics \
		< ddl/reset.sql

down:
	docker compose down

purge:
	docker compose down -v --remove-orphans

trino:
	docker compose exec trino \
		trino --catalog iceberg --schema analytics

logs:
	docker compose logs -f trino

ps:
	docker compose ps