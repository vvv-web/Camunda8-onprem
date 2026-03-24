#!/usr/bin/env bash
# Олег Растатурин: пользователь описан в .identity/application.yaml; применить — перезапуск Identity.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT/scripts/apply-identity-keycloak-users.sh"
