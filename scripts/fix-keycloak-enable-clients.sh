#!/usr/bin/env bash
# Включить OIDC-клиентов Keycloak (исправление «Client disabled»)
# Запуск: cd Camunda8-onprem && ./scripts/fix-keycloak-enable-clients.sh
#
# Офф. документация Keycloak Admin REST:
# https://www.keycloak.org/docs-api/latest/rest-api/index.html

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

REALM="camunda-platform"
KCADM="docker compose -f docker-compose-full.yaml exec -T keycloak /opt/bitnami/keycloak/bin/kcadm.sh"

if [[ -f .env ]]; then
  # shellcheck source=/dev/null
  source .env 2>/dev/null || true
fi

echo "=== Keycloak: включение клиентов realm $REALM ==="

docker compose -f docker-compose-full.yaml exec -T keycloak /opt/bitnami/keycloak/bin/kcadm.sh config credentials \
  --config /tmp/kcadm.config \
  --server http://localhost:18080/auth \
  --realm master \
  --user "${KEYCLOAK_ADMIN_USER:-admin}" \
  --password "${KEYCLOAK_ADMIN_PASSWORD:-admin}"

enable_client() {
  local cid
  cid=$($KCADM get clients --config /tmp/kcadm.config -r "$REALM" -q "clientId=$1" 2>/dev/null \
    | grep -oE '"[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}"' | head -1 | tr -d '"')
  if [[ -z "$cid" ]]; then
    echo "[WARN] Клиент $1 не найден"
    return 1
  fi
  $KCADM update "clients/$cid" --config /tmp/kcadm.config -r "$REALM" -s enabled=true
  echo "[OK] $1: enabled=true"
}

for id in orchestration console optimize web-modeler identity; do
  enable_client "$id" || true
done

echo ""
echo "Проверка: откройте https://\${HOST}/operate и https://\${HOST}/optimize/"
