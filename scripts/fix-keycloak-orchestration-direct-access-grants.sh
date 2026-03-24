#!/usr/bin/env bash
# Включает для клиента realm camunda-platform с id «orchestration» опцию Direct Access Grants
# (Resource Owner Password Credentials), чтобы скрипт grant-orchestration-cluster-admin-role.sh
# мог получить токен пользователя demo без копирования Bearer из браузера.
#
# Запуск: cd Camunda8-onprem && ./scripts/fix-keycloak-orchestration-direct-access-grants.sh
#
# Безопасность: password grant удобен для админ-скриптов во внутренней сети; в публичном Keycloak
# ограничьте использование или отключите опцию после выдачи ролей.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

REALM="${KEYCLOAK_REALM:-camunda-platform}"
CLIENT_ID="${ORCHESTRATION_CLIENT_ID:-orchestration}"

KCADM=(docker compose -f docker-compose-full.yaml exec -T keycloak /opt/bitnami/keycloak/bin/kcadm.sh)
CONFIG="/tmp/kcadm.config"

echo "=== kcadm: вход (realm master) ==="
"${KCADM[@]}" config credentials \
  --config "$CONFIG" \
  --server http://localhost:18080/auth \
  --realm master \
  --user "${KEYCLOAK_ADMIN_USER:-admin}" \
  --password "${KEYCLOAK_ADMIN_PASSWORD:-admin}"

echo "=== Поиск internal id клиента ${CLIENT_ID} ==="
CID="$("${KCADM[@]}" get clients --config "$CONFIG" -r "$REALM" -q "clientId=$CLIENT_ID" 2>/dev/null \
  | grep -oE '"[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}"' | head -1 | tr -d '"')"

if [[ -z "$CID" ]]; then
  echo "[FAIL] Клиент ${CLIENT_ID} не найден в realm ${REALM}"
  exit 1
fi

echo "=== directAccessGrantsEnabled=true для clients/${CID} ==="
"${KCADM[@]}" update "clients/${CID}" --config "$CONFIG" -r "$REALM" \
  -s directAccessGrantsEnabled=true

echo "[OK] Клиент «${CLIENT_ID}»: Direct access grants включены."
echo "Проверка: ./scripts/grant-orchestration-cluster-admin-role.sh Rastaturin_Oleg"
