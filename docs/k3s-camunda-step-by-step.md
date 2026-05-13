# k3s Camunda step-by-step (canonical)

Canonical guide location moved to this repository.

## Guard-rail: realm preflight before any migration

Run preflight against local Camunda Keycloak (`namespace camunda`) and check source payload before import.

```bash
# 1) Local realm list in Camunda Keycloak
kubectl -n camunda exec camunda-keycloak-0 -- sh -lc '
  export HOME=/tmp
  /opt/bitnami/keycloak/bin/kcadm.sh config credentials \
    --server http://127.0.0.1:8080/auth \
    --realm master \
    --user "$KEYCLOAK_ADMIN" \
    --password "$KEYCLOAK_ADMIN_PASSWORD" >/dev/null
  /opt/bitnami/keycloak/bin/kcadm.sh get realms --fields realm,enabled
'

# 2) Verify source realm in export payload (example file)
jq -r '.realm // empty' /path/to/source-realm.json
```

### Stop condition (mandatory)

Stop migration immediately if:

- source realm is not exactly `camunda-platform`; or
- import payload contains project-specific realm names (`acom-offerdesk`, etc.); or
- local realm inventory already contains a foreign project realm.

Only `camunda-platform` is allowed for Camunda migrations in this contour.

## Canonical references

- Realm/issuer/redirect SSOT: `docs/camunda-keycloak-ssot.md`
- Canonical training values: `deploy/k3s/values-learning.yaml`
- Realm cleanup proof: `step12-migration-20260513T120900Z/realm-cleanup-20260513T121557Z/cleanup-summary.txt`

## Notes

- Realm `acom-offerdesk` belongs to a separate project and must not be migrated into local Camunda Keycloak.
- Current expected local realm state after cleanup: `master`, `camunda-platform`.
