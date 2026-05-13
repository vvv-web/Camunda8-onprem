#!/usr/bin/env bash
set -euo pipefail

ALLOWED_REALMS_REGEX='^(master|camunda-platform)$'
IMPORT_FILE="${1:-}"

if [[ -z "${IMPORT_FILE}" ]]; then
  echo "usage: $0 /path/to/realm-export.json" >&2
  exit 2
fi

if [[ ! -f "${IMPORT_FILE}" ]]; then
  echo "import file not found: ${IMPORT_FILE}" >&2
  exit 2
fi

SOURCE_REALM="$(jq -r '.realm // empty' "${IMPORT_FILE}")"
if [[ -z "${SOURCE_REALM}" ]]; then
  echo "realm field is missing in ${IMPORT_FILE}" >&2
  exit 2
fi

if [[ ! "${SOURCE_REALM}" =~ ${ALLOWED_REALMS_REGEX} ]]; then
  echo "DENY: source realm '${SOURCE_REALM}' is not in whitelist [master, camunda-platform]" >&2
  exit 1
fi

echo "PASS: source realm '${SOURCE_REALM}' is allowed"

if command -v kubectl >/dev/null 2>&1 && kubectl get ns camunda >/dev/null 2>&1; then
  echo "Checking realms in cluster Keycloak..."
  REALMS="$(
    kubectl -n camunda exec camunda-keycloak-0 -- sh -lc '
      export HOME=/tmp
      /opt/bitnami/keycloak/bin/kcadm.sh config credentials \
        --server http://127.0.0.1:8080/auth \
        --realm master \
        --user "$KEYCLOAK_ADMIN" \
        --password "$KEYCLOAK_ADMIN_PASSWORD" >/dev/null
      /opt/bitnami/keycloak/bin/kcadm.sh get realms --fields realm \
        | jq -r ".[].realm"
    '
  )"

  while IFS= read -r realm; do
    [[ -z "${realm}" ]] && continue
    if [[ ! "${realm}" =~ ${ALLOWED_REALMS_REGEX} ]]; then
      echo "DENY: foreign realm detected in cluster: ${realm}" >&2
      exit 1
    fi
  done <<< "${REALMS}"

  echo "PASS: cluster realms match whitelist"
else
  echo "INFO: cluster check skipped (camunda namespace or kubectl unavailable)"
fi
