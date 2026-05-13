# FluxCD branch runbook: k3s-local Camunda

## Purpose of this branch

This branch introduces a FluxCD-ready structure for running Camunda 8 and Headlamp SSO in local `k3s`, with explicit dependency ordering and realm guardrails.

- Branch: `gitops/flux-camunda-k3s-bootstrap`
- Scope: local cluster only (`k3s-local`)
- Realm safety rule: only `master` and `camunda-platform` are allowed.

## Repository structure

- `clusters/k3s-local/`
  - Flux cluster entrypoint (`GitRepository` + Flux `Kustomization` chain)
- `apps/platform/`
  - platform prerequisites (`ingress-nginx` service mode, identity policy, realm guardrails)
- `apps/camunda/`
  - Camunda HelmRepository + HelmRelease (`camunda-platform` chart)
- `apps/headlamp/`
  - Headlamp HelmRepository + HelmRelease + oauth2-proxy manifests/ingress
- `runbooks/preflight-realm-whitelist.sh`
  - mandatory guardrail script before any realm import

## Dependency chain (dependsOn)

1. `platform`
2. `camunda` depends on `platform`
3. `headlamp` depends on `platform` and `camunda`

This ordering keeps ingress/identity prerequisites in place before app reconciliation.

## Prerequisites

- `kubectl` configured to local `k3s`
- `flux` CLI installed
- `jq` installed
- Cluster has network access to:
  - `https://github.com/vvv-web/Camunda8-onprem.git`
  - `https://helm.camunda.io`
  - `https://kubernetes-sigs.github.io/headlamp/`
- Secret for oauth2-proxy exists (or will be created) in namespace `headlamp`:
  - `headlamp-oauth2-proxy-secret` with keys `client-id`, `client-secret`, `cookie-secret`

## Bootstrap (safe path)

```bash
# 1) Install Flux controllers (idempotent)
flux install

# 2) Apply Flux source + Kustomization chain for k3s-local
kubectl apply -k clusters/k3s-local

# 3) Create/update oauth2-proxy secret (replace placeholders)
kubectl -n headlamp create secret generic headlamp-oauth2-proxy-secret \
  --from-literal=client-id='headlamp-oauth2-proxy' \
  --from-literal=client-secret='<KEYCLOAK_CLIENT_SECRET>' \
  --from-literal=cookie-secret='<RANDOM_COOKIE_SECRET>' \
  --dry-run=client -o yaml | kubectl apply -f -

# 4) Force reconcile in dependency order
flux reconcile source git camunda8-onprem -n flux-system
flux reconcile kustomization platform -n flux-system --with-source
flux reconcile kustomization camunda -n flux-system --with-source
flux reconcile kustomization headlamp -n flux-system --with-source
```

## Verify

```bash
# Flux health
flux get all -A
kubectl -n flux-system get gitrepositories,kustomizations,helmreleases

# App workloads
kubectl -n camunda get pods
kubectl -n headlamp get pods,svc,ingress
kubectl -n ingress-nginx get svc ingress-nginx-controller

# Guardrail preflight before import
./runbooks/preflight-realm-whitelist.sh /path/to/realm-export.json
```

Expected:
- Flux objects are `Ready=True`.
- `camunda` and `headlamp` workloads are Running.
- ingress controller service type is `LoadBalancer`.
- preflight exits with `PASS` and no foreign realm.

## Rollback

```bash
# Suspend reconciliation first
flux suspend kustomization headlamp -n flux-system
flux suspend kustomization camunda -n flux-system
flux suspend kustomization platform -n flux-system

# Remove Flux-managed objects for this branch path
kubectl delete -k clusters/k3s-local --ignore-not-found

# Optional: remove Flux controllers entirely (if this cluster should not run Flux)
flux uninstall --silent
```

## Known pitfalls

- **Realm scope:** never import realm dumps from other projects (`acom-offerdesk`, etc.).
- **Secret management:** `headlamp-oauth2-proxy-secret` is not stored in git by design.
- **Ingress exposure:** on k3s, `LoadBalancer` uses `svclb-*`; ensure host mapping for `camunda.local` and `headlamp.local`.
- **Public repo pin:** Flux source tracks branch `gitops/flux-camunda-k3s-bootstrap`; if branch name changes, update `clusters/k3s-local/flux-system/source-camunda8-onprem.yaml`.
