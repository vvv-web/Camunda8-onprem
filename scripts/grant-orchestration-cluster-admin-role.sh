#!/usr/bin/env bash
# Назначить пользователю Orchestration Cluster роль «admin» (Operate / Tasklist / API).
# Список в .orchestration/application.yaml (defaultRoles.admin.users) применяется в основном
# при первичной инициализации; для уже живого кластера используйте этот скрипт или Identity UI.
#
# Использование:
#   cd .../Camunda8-onprem
#   ./scripts/grant-orchestration-cluster-admin-role.sh [username]
#
# Аутентификация (один из вариантов):
#   1) Задать CAMUNDA_ACCESS_TOKEN (Bearer от пользователя с правом assign role, обычно demo).
#   2) Или задать CAMUNDA_GRANT_USERNAME / CAMUNDA_GRANT_PASSWORD и в Keycloak у клиента
#      orchestration включить «Direct access grants» — тогда скрипт возьмёт токен через password grant.
#
# Пример с токеном из браузера (Network → запрос с Authorization: Bearer …):
#   CAMUNDA_ACCESS_TOKEN='eyJ…' ./scripts/grant-orchestration-cluster-admin-role.sh Rastaturin_Oleg
#
# Принудительно снять и снова назначить роль (если подозрение на «битое» состояние):
#   CAMUNDA_FORCE_REASSIGN_ROLE=1 ./scripts/grant-orchestration-cluster-admin-role.sh Rastaturin_Oleg
#
set -euo pipefail

command -v jq >/dev/null || { echo "Нужен jq"; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Важно: логин должен совпадать с preferred_username в JWT (у Keycloak часто lowercase).
TARGET_USER="${1:-rastaturin_oleg}"
ROLE_ID="admin"

if [[ ! -f .env ]]; then
  echo "Нужен файл .env в корне Camunda8-onprem"
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

ORCHESTRATION_REST="${ORCHESTRATION_REST:-http://127.0.0.1:8088}"
KEYCLOAK_BASE="${KEYCLOAK_BASE:-http://127.0.0.1:18080}"
REALM="${KEYCLOAK_REALM:-camunda-platform}"

TOKEN="${CAMUNDA_ACCESS_TOKEN:-}"

if [[ -z "${TOKEN}" ]]; then
  GU="${CAMUNDA_GRANT_USERNAME:-demo}"
  GP="${CAMUNDA_GRANT_PASSWORD:-demo}"
  CID="${ORCHESTRATION_CLIENT_ID:-orchestration}"
  CS="${ORCHESTRATION_CLIENT_SECRET:-}"

  if [[ -z "${CS}" ]]; then
    echo "Задайте CAMUNDA_ACCESS_TOKEN или ORCHESTRATION_CLIENT_SECRET в .env для password grant."
    exit 1
  fi

  echo "=== Получение токена (password grant, пользователь ${GU}) ==="
  RESP="$(curl -sS --noproxy '*' -X POST "${KEYCLOAK_BASE}/auth/realms/${REALM}/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password" \
    -d "client_id=${CID}" \
    -d "client_secret=${CS}" \
    -d "username=${GU}" \
    -d "password=${GP}")"

  TOKEN="$(echo "${RESP}" | jq -r '.access_token // empty')"
  if [[ -z "${TOKEN}" || "${TOKEN}" == "null" ]]; then
    echo "Не удалось получить токен. Ответ Keycloak:"
    echo "${RESP}" | jq . 2>/dev/null || echo "${RESP}"
    echo ""
    echo "Включите Direct access grants для клиента ${CID}:"
    echo "  ./scripts/fix-keycloak-orchestration-direct-access-grants.sh"
    echo "Либо задайте токен вручную: CAMUNDA_ACCESS_TOKEN='…' $0 ${TARGET_USER}"
    exit 1
  fi
fi

# Безопасные логины без кодирования; иначе задайте CAMUNDA_ACCESS_TOKEN и проверьте URL вручную
if [[ ! "${TARGET_USER}" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
  echo "Логин содержит нестандартные символы — используйте ручной вызов API или поправьте скрипт."
  exit 1
fi

URL="${ORCHESTRATION_REST%/}/v2/roles/${ROLE_ID}/users/${TARGET_USER}"

if [[ "${CAMUNDA_FORCE_REASSIGN_ROLE:-0}" == "1" ]]; then
  echo "=== DELETE ${URL} (CAMUNDA_FORCE_REASSIGN_ROLE=1) ==="
  DEL_CODE="$(curl -sS -o /tmp/camunda_grant_role_del.txt -w "%{http_code}" --noproxy '*' \
    -X DELETE "${URL}" \
    -H "Authorization: Bearer ${TOKEN}")"
  echo "DELETE HTTP ${DEL_CODE}"
  [[ "$DEL_CODE" == "204" ]] || [[ "$DEL_CODE" == "404" ]] || { cat /tmp/camunda_grant_role_del.txt; exit 1; }
  sleep 2
fi

echo "=== PUT ${URL} ==="
HTTP_CODE="$(curl -sS -o /tmp/camunda_grant_role_body.txt -w "%{http_code}" --noproxy '*' \
  -X PUT "${URL}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json")"

if [[ "${HTTP_CODE}" == "204" ]]; then
  echo "Роль «${ROLE_ID}» назначена пользователю «${TARGET_USER}» (204)."
  echo "Выйдите из Operate (лучше https://camunda.acom-offer-desk.ru/logout) и войдите снова под ${TARGET_USER}."
  exit 0
fi

# Идемпотентность API: повторный PUT — 409 ALREADY_EXISTS (роль уже была)
if [[ "${HTTP_CODE}" == "409" ]]; then
  echo "Роль «${ROLE_ID}» у пользователя «${TARGET_USER}» уже была (409 ALREADY_EXISTS) — менять ничего не нужно."
  echo "Если в Operate всё ещё «нет доступа»: полный выход https://camunda.acom-offer-desk.ru/logout , другой браузер/окно инкогнито,"
  echo "проверьте, что в JWT claim preferred_username совпадает с «${TARGET_USER}» (логин в Keycloak)."
  exit 0
fi

echo "Ожидался HTTP 204 или 409, получен ${HTTP_CODE}. Тело:"
cat /tmp/camunda_grant_role_body.txt
echo ""
exit 1
