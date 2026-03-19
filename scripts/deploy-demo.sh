#!/bin/bash
# Деплой демо-процессов для презентации
# Запускать с pop-os (где Camunda) или с машины с доступом к Keycloak:18080 и orchestration:8088

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

KEYCLOAK_URL="${KEYCLOAK_URL:-http://127.0.0.1:18080}"
ORCHESTRATION_URL="${ORCHESTRATION_URL:-http://127.0.0.1:8088}"

# Обход прокси для доступа к localhost/LAN
export no_proxy="${no_proxy:-*,127.0.0.1,10.16.66.48,localhost}"
export NO_PROXY="${NO_PROXY:-$no_proxy}"

echo "=== Токен от Keycloak ==="
TOKEN=$(curl -s --noproxy '*' -X POST "${KEYCLOAK_URL}/auth/realms/camunda-platform/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=orchestration&client_secret=secret&grant_type=client_credentials" | jq -r '.access_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "Ошибка: не удалось получить токен. Проверьте Keycloak ($KEYCLOAK_URL) и client_credentials."
  exit 1
fi

echo "Токен получен."

echo ""
echo "=== Деплой child_approval ==="
curl -s --noproxy '*' -X POST "${ORCHESTRATION_URL}/v2/deployments" \
  -H "Authorization: Bearer $TOKEN" \
  -F "resources=@demo/child-approval.bpmn" | jq .

echo ""
echo "=== Деплой parent_with_call_activity ==="
curl -s --noproxy '*' -X POST "${ORCHESTRATION_URL}/v2/deployments" \
  -H "Authorization: Bearer $TOKEN" \
  -F "resources=@demo/parent-with-call-activity.bpmn" \
  -F "resources=@demo/child-approval.bpmn" | jq .

echo ""
echo "=== Деплой process_with_embedded_subprocess ==="
curl -s --noproxy '*' -X POST "${ORCHESTRATION_URL}/v2/deployments" \
  -H "Authorization: Bearer $TOKEN" \
  -F "resources=@demo/process-with-embedded-subprocess.bpmn" | jq .

echo ""
echo "Деплой завершён. Проверьте Operate: https://camunda.acom-offer-desk.ru/operate"
