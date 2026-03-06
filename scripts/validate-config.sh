#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_ENV_FILE="$ROOT_DIR/.env"
FALLBACK_ENV_FILE="$ROOT_DIR/.env.example"

if [[ $# -gt 0 ]]; then
  ENV_FILE="$1"
elif [[ -f "$DEFAULT_ENV_FILE" ]]; then
  ENV_FILE="$DEFAULT_ENV_FILE"
else
  ENV_FILE="$FALLBACK_ENV_FILE"
fi

FAIL_COUNT=0
WARN_COUNT=0

ok() {
  printf '[OK] %s\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1"
  WARN_COUNT=$((WARN_COUNT + 1))
}

fail() {
  printf '[FAIL] %s\n' "$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Команда '$1' не найдена"
  fi
}

read_env_value() {
  local key="$1"
  local value
  value="$(awk -F= -v lookup="$key" '$1 == lookup { sub(/^[^=]*=/, "", $0); print $0 }' "$ENV_FILE" | tail -n 1)"
  printf '%s' "$value"
}

check_required_env() {
  local key="$1"
  local value
  value="$(read_env_value "$key")"
  if [[ -z "$value" ]]; then
    fail "В '$ENV_FILE' отсутствует обязательная переменная $key"
    return
  fi

  if [[ "$value" =~ ^change-me- ]]; then
    warn "Переменная $key в '$ENV_FILE' всё ещё содержит шаблонное значение"
    return
  fi

  ok "Переменная $key задана"
}

check_file_contains() {
  local file="$1"
  local needle="$2"
  local description="$3"

  if grep -Fq "$needle" "$file"; then
    ok "$description"
  else
    fail "$description"
  fi
}

check_connector_secrets_template() {
  local file="$ROOT_DIR/connector-secrets.txt"
  if [[ ! -f "$file" ]]; then
    fail "Отсутствует шаблон $file"
    return
  fi

  if grep -Eq '^[A-Za-z_][A-Za-z0-9_]*=' "$file"; then
    ok "В connector-secrets.txt есть значения env_file"
  else
    warn "connector-secrets.txt сейчас выглядит как пустой шаблон без переменных"
  fi
}

check_compose_file() {
  local file="$1"
  if docker compose --env-file "$ENV_FILE" -f "$file" config -q >/dev/null 2>&1; then
    ok "Compose-файл $(basename "$file") валиден"
  else
    fail "Compose-файл $(basename "$file") не проходит 'docker compose config -q'"
  fi
}

main() {
  printf '== Camunda config validator ==\n'
  printf 'Root: %s\n' "$ROOT_DIR"
  printf 'Env file: %s\n' "$ENV_FILE"

  if [[ ! -f "$ENV_FILE" ]]; then
    fail "Файл окружения '$ENV_FILE' не найден"
  fi

  require_command docker

  check_required_env HOST
  check_required_env KEYCLOAK_HOST
  check_required_env ORCHESTRATION_CLIENT_ID
  check_required_env ORCHESTRATION_CLIENT_SECRET
  check_required_env CONNECTORS_CLIENT_ID
  check_required_env CONNECTORS_CLIENT_SECRET
  check_required_env POSTGRES_PASSWORD
  check_required_env KEYCLOAK_ADMIN_USER
  check_required_env KEYCLOAK_ADMIN_PASSWORD

  check_compose_file "$ROOT_DIR/docker-compose.yaml"
  check_compose_file "$ROOT_DIR/docker-compose-full.yaml"
  check_compose_file "$ROOT_DIR/docker-compose-web-modeler.yaml"

  check_file_contains \
    "$ROOT_DIR/.identity/application.yaml" \
    'issuer-url: "http://${HOST}:18080/auth/realms/camunda-platform"' \
    "Identity использует HOST для browser-facing issuer-url"

  check_file_contains \
    "$ROOT_DIR/.identity/application.yaml" \
    'backend-url: "http://${KEYCLOAK_HOST}:18080/auth/realms/camunda-platform"' \
    "Identity использует KEYCLOAK_HOST для backend-url"

  check_file_contains \
    "$ROOT_DIR/.identity/application.yaml" \
    'root-url: "http://${HOST:localhost}:8088"' \
    "Identity orchestration root-url параметризован через HOST"

  check_file_contains \
    "$ROOT_DIR/.orchestration/application.yaml" \
    'redirectRootUrl: "http://${HOST:localhost}:8088/operate"' \
    "Operate redirectRootUrl параметризован через HOST"

  check_file_contains \
    "$ROOT_DIR/.orchestration/application.yaml" \
    'redirectRootUrl: "http://${HOST:localhost}:8088/tasklist"' \
    "Tasklist redirectRootUrl параметризован через HOST"

  check_connector_secrets_template

  printf '\nSummary: FAIL=%d WARN=%d\n' "$FAIL_COUNT" "$WARN_COUNT"
  if (( FAIL_COUNT > 0 )); then
    exit 1
  fi
}

main "$@"
