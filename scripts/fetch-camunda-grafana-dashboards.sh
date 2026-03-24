#!/usr/bin/env bash
# Скачивает официальные дашборды Camunda (ветка stable/8.8) и подставляет UID Prometheus для provisioning.
# Источники: https://docs.camunda.io/docs/self-managed/operational-guides/monitoring/metrics/
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/monitoring/grafana/provisioning/dashboards/json"
BRANCH="${CAMUNDA_GRAFANA_BRANCH:-stable/8.8}"
DS_UID="${GRAFANA_PROMETHEUS_UID:-camunda-prometheus}"

mkdir -p "$OUT_DIR"

python3 - "$OUT_DIR" "$BRANCH" "$DS_UID" <<'PY'
import json
import sys
import urllib.request

out_dir, branch, ds_uid = sys.argv[1:4]
urls = {
    "zeebe.json": f"https://raw.githubusercontent.com/camunda/camunda/{branch}/monitor/grafana/zeebe.json",
    "data_layer.json": f"https://raw.githubusercontent.com/camunda/camunda/{branch}/monitor/grafana/dashboards/data_layer.json",
}

for name, url in urls.items():
    with urllib.request.urlopen(url, timeout=120) as r:
        text = r.read().decode("utf-8")
    text = text.replace("${DS_PROMETHEUS}", ds_uid).replace("$DS_PROMETHEUS", ds_uid)
    data = json.loads(text)
    for k in ("__inputs", "__elements", "__requires"):
        data.pop(k, None)
    data["id"] = None
    if name == "zeebe.json":
        data["uid"] = "camunda-zeebe-official"
    elif name == "data_layer.json":
        data["uid"] = "camunda-data-layer-official"
    path = f"{out_dir}/{name}"
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    print("OK", path)
PY
