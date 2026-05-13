# Camunda Keycloak SSOT

This file is the single source of truth for local Camunda Keycloak realm policy in this repository.

## Canonical realm policy

- Camunda realm in this contour: `camunda-platform` (only).
- Allowed local realms after migration/post-check: `master`, `camunda-platform`.
- Forbidden in local Camunda Keycloak: realms from other projects (`acom-offerdesk` and similar).

## Canonical local issuer and redirects

- Issuer (local via port-forward): `http://127.0.0.1:18081/auth/realms/camunda-platform`
- Operate redirect callback: `http://127.0.0.1:18082/identity-callback`
- Tasklist redirect callback: `http://127.0.0.1:18083/identity-callback`

Keep `redirectRootUrl` on base URLs (without `/operate` or `/tasklist` suffix) to avoid redirect loops.

## Hard guardrails

1. Before any import/migration, run realm preflight (see `docs/k3s-camunda-step-by-step.md`).
2. If source realm is not exactly `camunda-platform`, stop migration.
3. Never import full realm dumps from unrelated projects into local Camunda Keycloak.
4. If a foreign realm appears by mistake, remove only that foreign realm and re-run post-check.

## Evidence of current clean state

- Cleanup artifact: `step12-migration-20260513T120900Z/realm-cleanup-20260513T121557Z/cleanup-summary.txt`
- Expected post-check realms: `camunda-platform`, `master`
