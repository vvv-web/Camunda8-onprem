#!/usr/bin/env bash
# Диагностика: почему в Operate «нет доступа», хотя роль admin выдана через API.
# Проверяет: пользователь в кластере, состав role admin, claims в JWT (preferred_username).
#
# Запуск (с pop-os, стек поднят):
#   cd Camunda8-onprem && ./scripts/diagnose-orchestration-user-access.sh Rastaturin_Oleg
#
# Для декодирования JWT пробуем password grant под этим пользователем (нужен пароль):
#   CAMUNDA_SUBJECT_PASSWORD='ORastaturin' ./scripts/diagnose-orchestration-user-access.sh Rastaturin_Oleg
#
set -euo pipefail

command -v jq >/dev/null || { echo "Нужен jq"; exit 1; }
command -v python3 >/dev/null || { echo "Нужен python3"; exit 1; }

TARGET="${1:-Rastaturin_Oleg}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

if [[ ! -f .env ]]; then echo "Нужен .env"; exit 1; fi
set -a
# shellcheck disable=SC1091
source .env
set +a

ORCHESTRATION_REST="${ORCHESTRATION_REST:-http://127.0.0.1:8088}"
KEYCLOAK_BASE="${KEYCLOAK_BASE:-http://127.0.0.1:18080}"
REALM="${KEYCLOAK_REALM:-camunda-platform}"
CID="${ORCHESTRATION_CLIENT_ID:-orchestration}"
CS="${ORCHESTRATION_CLIENT_SECRET:-}"

get_demo_token() {
  curl -sS --noproxy '*' -X POST "${KEYCLOAK_BASE}/auth/realms/${REALM}/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password" \
    -d "client_id=${CID}" \
    -d "client_secret=${CS}" \
    -d "username=${CAMUNDA_GRANT_USERNAME:-demo}" \
    -d "password=${CAMUNDA_GRANT_PASSWORD:-demo}" | jq -r '.access_token // empty'
}

decode_jwt_payload() {
  python3 -c "
import json, base64, sys
t = sys.argv[1].split('.')[1]
t += '=' * ((4 - len(t) % 4) % 4)
print(json.dumps(json.loads(base64.urlsafe_b64decode(t)), indent=2))
" "$1"
}

echo "=== 1) Токен админа (demo) для запросов к API кластера ==="
if [[ -z "$CS" ]]; then
  echo "[FAIL] ORCHESTRATION_CLIENT_SECRET пуст в .env"
  exit 1
fi
ADMIN_TOK="$(get_demo_token)"
if [[ -z "$ADMIN_TOK" ]]; then
  echo "[FAIL] Не удалось получить токен demo. Включите Direct access grants: ./scripts/fix-keycloak-orchestration-direct-access-grants.sh"
  exit 1
fi

echo "=== 2) GET /v2/users/${TARGET} (есть ли пользователь в Orchestration Cluster) ==="
HTTP_U="$(curl -sS -o /tmp/c8_user.json -w "%{http_code}" --noproxy '*' \
  "${ORCHESTRATION_REST%/}/v2/users/${TARGET}" \
  -H "Authorization: Bearer ${ADMIN_TOK}")"
echo "HTTP ${HTTP_U}"
if [[ "$HTTP_U" == "200" ]]; then
  jq . /tmp/c8_user.json
elif [[ "$HTTP_U" == "403" ]]; then
  cat /tmp/c8_user.json
  echo ""
  echo "[INFO] Users API отключён в OIDC-режиме — это нормально. Права смотрите по JWT (п.4) и POST /roles/admin/users/search (п.3)."
else
  cat /tmp/c8_user.json
  echo ""
  echo "[WARN] Ожидался 200; при 404 — один раз зайдите в Operate под пользователем и повторите скрипт."
fi

echo ""
echo "=== 3) POST /v2/roles/admin/users/search — кто в роли admin ==="
curl -sS --noproxy '*' -X POST "${ORCHESTRATION_REST%/}/v2/roles/admin/users/search" \
  -H "Authorization: Bearer ${ADMIN_TOK}" \
  -H "Content-Type: application/json" \
  -d '{}' | jq .

echo ""
echo "=== 4) JWT claims для пользователя ${TARGET} (нужен CAMUNDA_SUBJECT_PASSWORD) ==="
if [[ -n "${CAMUNDA_SUBJECT_PASSWORD:-}" ]]; then
  SUB_TOK="$(curl -sS --noproxy '*' -X POST "${KEYCLOAK_BASE}/auth/realms/${REALM}/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password" \
    -d "client_id=${CID}" \
    -d "client_secret=${CS}" \
    -d "username=${TARGET}" \
    -d "password=${CAMUNDA_SUBJECT_PASSWORD}")"
  AT="$(echo "$SUB_TOK" | jq -r '.access_token // empty')"
  if [[ -z "$AT" ]]; then
    echo "Токен не получен:"
    echo "$SUB_TOK" | jq .
  else
    echo "Payload access_token (важно preferred_username vs «${TARGET}»):"
    decode_jwt_payload "$AT"
    echo ""
    PU="$(decode_jwt_payload "$AT" | jq -r '.preferred_username // empty')"
    if [[ -n "$PU" && "$PU" != "$TARGET" ]]; then
      echo "[!!!] preferred_username в токене («${PU}») ≠ логин API («${TARGET}»). Camunda берёт claim из CAMUNDA_SECURITY_AUTHENTICATION_OIDC_USERNAMECLAIM (у вас preferred_username)."
      echo "    Исправление: в Keycloak задать preferred_username=${TARGET} или сменить username claim в orchestration."
    fi
  fi
else
  echo "Пропуск (задайте CAMUNDA_SUBJECT_PASSWORD для пароля пользователя ${TARGET})."
fi

echo ""
echo "=== 5) Подсказка ==="
echo "В compose для orchestration: CAMUNDA_SECURITY_AUTHENTICATION_OIDC_USERNAMECLAIM=preferred_username"
echo "Если в п.4 preferred_username другой — Operate ищет права для другого ownerId → замок."
echo "Полный выход: https://\${HOST}/logout затем снова вход."
