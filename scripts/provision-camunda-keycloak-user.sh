#!/usr/bin/env bash
# Провижининг пользователя в Keycloak (realm camunda-platform) без правки Identity YAML.
# Полезно, если стек уже поднят и пользователя нельзя добавить только через application.yaml.
#
# Использование:
#   CAMUNDA_NEW_USER_PASSWORD='секрет' \
#   ./scripts/provision-camunda-keycloak-user.sh <username> <firstName> <lastName> [email]
#
# Пример:
#   CAMUNDA_NEW_USER_PASSWORD='ORastaturin' \
#   ./scripts/provision-camunda-keycloak-user.sh Rastaturin_Oleg Oleg Rastaturin oleg.rastaturin@example.com
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ $# -lt 3 ]]; then
  echo "Usage: CAMUNDA_NEW_USER_PASSWORD='...' $0 <username> <firstName> <lastName> [email]"
  exit 1
fi

if [[ ! -f .env ]]; then
  echo "Нет .env — скопируйте из .env.example, заполните KEYCLOAK_ADMIN_*"
  exit 1
fi

command -v jq >/dev/null || { echo "Нужен jq"; exit 1; }

USERNAME="$1"
FIRST="$2"
LAST="$3"
EMAIL="${4:-${USERNAME}@example.com}"
PASSWORD="${CAMUNDA_NEW_USER_PASSWORD:-}"
if [[ -z "${PASSWORD}" ]]; then
  PASSWORD="$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-16)"
  echo "Сгенерирован пароль (сохраните): ${PASSWORD}"
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

KCADM=(docker compose -f docker-compose-full.yaml exec -T keycloak /opt/bitnami/keycloak/bin/kcadm.sh)
CONFIG="/tmp/kcadm.config"

"${KCADM[@]}" config credentials \
  --config "$CONFIG" \
  --server http://localhost:18080/auth \
  --realm master \
  --user "${KEYCLOAK_ADMIN_USER}" \
  --password "${KEYCLOAK_ADMIN_PASSWORD}"

EXISTING="$("${KCADM[@]}" get users -r camunda-platform --config "$CONFIG" -q "username=${USERNAME}" | jq 'length')"
if [[ "${EXISTING}" -gt 0 ]]; then
  echo "Пользователь ${USERNAME} уже есть в Keycloak."
  exit 1
fi

"${KCADM[@]}" create users -r camunda-platform --config "$CONFIG" \
  -s "username=${USERNAME}" \
  -s enabled=true \
  -s "email=${EMAIL}" \
  -s "firstName=${FIRST}" \
  -s "lastName=${LAST}"

"${KCADM[@]}" set-password -r camunda-platform --config "$CONFIG" \
  --username "${USERNAME}" \
  --new-password "${PASSWORD}" \
  --temporary false

RAW="$("${KCADM[@]}" get users -r camunda-platform --config "$CONFIG" -q "username=${USERNAME}" --fields id,username)"
USER_ID="$(echo "$RAW" | jq -r '.[0].id')"
if [[ -z "$USER_ID" || "$USER_ID" == "null" ]]; then
  echo "Не удалось получить id: ${RAW}"
  exit 1
fi

"${KCADM[@]}" add-roles -r camunda-platform --config "$CONFIG" \
  --uid "$USER_ID" \
  --rolename ManagementIdentity \
  --rolename Optimize \
  --rolename "Web Modeler" \
  --rolename "Web Modeler Admin" \
  --rolename Console \
  --rolename Orchestration

echo "Готово: ${USERNAME} / пароль см. выше. В Identity назначьте cluster role admin при необходимости."
