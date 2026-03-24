#!/usr/bin/env bash
# После изменения keycloak.users в .identity/application.yaml — синхронизация в Keycloak
# через перезапуск Identity (штатный механизм Camunda Identity).
#
# Использование:
#   cd .../Camunda8-onprem && ./scripts/apply-identity-keycloak-users.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

COMPOSE=(docker compose -f docker-compose-full.yaml)

echo "=== Перезапуск identity (подхват .identity/application.yaml) ==="
"${COMPOSE[@]}" restart identity

# Actuator в образе Identity на :8082 внутри контейнера (см. healthcheck в docker-compose-full.yaml);
# на хост проброшен только :8084 под приложение — curl на 127.0.0.1:8084/actuator часто даёт таймаут.
echo "=== Ожидание готовности identity (до ~3 мин: Docker health + fallback :8082 внутри контейнера) ==="
for _ in $(seq 1 60); do
  st="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-health{{end}}' identity 2>/dev/null || echo missing)"
  if [[ "$st" == "healthy" ]]; then
    echo "Identity: контейнер в состоянии healthy."
    exit 0
  fi
  if [[ "$st" == "unhealthy" ]]; then
    echo "[FAIL] Identity unhealthy. Логи:"
    "${COMPOSE[@]}" logs identity --tail 60
    exit 1
  fi
  if "${COMPOSE[@]}" exec -T identity sh -c 'wget -q -O- --spider http://127.0.0.1:8082/actuator/health' 2>/dev/null; then
    echo "Identity: actuator http://127.0.0.1:8082/actuator/health внутри контейнера отвечает."
    exit 0
  fi
  sleep 3
done

echo "[WARN] Identity не стал healthy за отведённое время. Смотрите: ${COMPOSE[*]} logs identity --tail 80"
exit 1
