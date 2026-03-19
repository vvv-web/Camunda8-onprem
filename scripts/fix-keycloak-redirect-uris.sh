#!/usr/bin/env bash
# Обновление Valid Redirect URIs в Keycloak для Console и Optimize (публичный доступ)
# Запуск: cd Camunda8-onprem && ./scripts/fix-keycloak-redirect-uris.sh
#
# Требует: docker compose -f docker-compose-full.yaml up (keycloak запущен)
# Предварительно: .env с HOST=camunda.acom-offer-desk.ru

set -e

# Берём HOST из .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

if [[ -f .env ]]; then
  source .env 2>/dev/null || true
fi

HOST="${HOST:-camunda.acom-offer-desk.ru}"
REALM="camunda-platform"
BASE="https://${HOST}"

# kcadm для Bitnami Keycloak
KCADM="docker compose -f docker-compose-full.yaml exec -T keycloak /opt/bitnami/keycloak/bin/kcadm.sh"
CONFIG_CMD="docker compose -f docker-compose-full.yaml exec -T keycloak /opt/bitnami/keycloak/bin/kcadm.sh config credentials --config /tmp/kcadm.config --server http://localhost:18080/auth --realm master --user ${KEYCLOAK_ADMIN_USER:-admin} --password ${KEYCLOAK_ADMIN_PASSWORD:-admin}"

echo "=== Keycloak: Redirect URIs для $HOST ==="
echo "Base: $BASE"
echo ""

# Конфиг kcadm (если ещё не сделано)
$CONFIG_CMD 2>/dev/null || true

update_client() {
  local client_id="$1"
  local root_url="$2"
  shift 2
  local uris=("$@")
  
  local cid
  cid=$($KCADM get clients --config /tmp/kcadm.config -r "$REALM" -q clientId="$client_id" 2>/dev/null | grep -oE '"[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}"' | head -1 | tr -d '"')
  if [[ -z "$cid" ]]; then
    echo "[WARN] Клиент $client_id не найден"
    return 1
  fi
  
  local json_uris
  json_uris=$(printf '"%s",' "${uris[@]}" | sed 's/,$//')
  json_uris="[$json_uris]"
  
  $KCADM update "clients/$cid" --config /tmp/kcadm.config -r "$REALM" \
    -s "rootUrl=$root_url" \
    -s "redirectUris=$json_uris"
  echo "[OK] $client_id: rootUrl=$root_url"
}

# Optimize: за /optimize (Optimize иногда шлёт http из-за forward headers)
update_client "optimize" "${BASE}/optimize" \
  "${BASE}/optimize" \
  "${BASE}/optimize/" \
  "${BASE}/optimize/*" \
  "${BASE}/optimize/api/authentication/callback" \
  "${BASE}/*" \
  "http://${HOST}/optimize" \
  "http://${HOST}/optimize/" \
  "http://${HOST}/optimize/api/authentication/callback" \
  "http://localhost:8083/api/authentication/callback"

# Console: за /console
update_client "console" "${BASE}/console" \
  "${BASE}/console" \
  "${BASE}/console/*" \
  "${BASE}/console/" \
  "http://localhost:8087" \
  "http://localhost:8087/"

echo ""
echo "[OK] Готово. Перезапуск не требуется."
echo "Проверка: откройте https://${HOST}/optimize/ и https://${HOST}/console/"
