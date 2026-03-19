#!/usr/bin/env bash
# Применение маршрутов /console и /optimize в nginx на VPS camunda.acom-offer-desk.ru
# Запуск: на VPS 155.212.160.162 (sudo)
#
# С pop-os:
#   scp -r Camunda8-onprem/scripts root@155.212.160.162:/tmp/camunda-scripts
#   ssh root@155.212.160.162 'sudo bash /tmp/camunda-scripts/apply-nginx-console-optimize.sh'
#
# Офф. документация (sync):
#   NGINX Reverse Proxy: https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/
#   Camunda Console: https://docs.camunda.io/docs/self-managed/console-deployment/configuration
#   Camunda Optimize: docker-compose port 8083:8090

set -e

UPSTREAM="${CAMUNDA_UPSTREAM:-100.69.139.22}"
SNIPPET_DIR="/etc/nginx/snippets"
SNIPPET_FILE="${SNIPPET_DIR}/camunda-console-optimize.conf"

write_snippet() {
    mkdir -p "$SNIPPET_DIR"
    cat > "$SNIPPET_FILE" << EOF
# Console и Optimize для Camunda (добавлено apply-nginx-console-optimize.sh)

# Logout: редирект на Keycloak end_session (Camunda 8.8 не поддерживает кнопку Logout в Operate)
location = /logout {
    return 302 https://\$host/auth/realms/camunda-platform/protocol/openid-connect/logout;
}

location = /console { return 301 /console/; }
location /console/ {
    proxy_pass http://${UPSTREAM}:8087/console/;
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Forwarded-Host \$host;
}

# Optimize OAuth redirect ведёт на /static/redirect.html (без /optimize/) — workaround
location /static/ {
    proxy_pass http://${UPSTREAM}:8083/optimize/static/;
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Forwarded-Host \$host;
}

location = /optimize { return 301 /optimize/; }
location /optimize/ {
    proxy_pass http://${UPSTREAM}:8083/optimize/;
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Forwarded-Host \$host;
    proxy_connect_timeout 10s;
    proxy_read_timeout 60s;
    proxy_send_timeout 60s;
}
EOF
    echo "[OK] Создан $SNIPPET_FILE"
}

find_vhost() {
    # ТОЛЬКО vhost для camunda.acom-offer-desk.ru (не трогать app.acom-offer-desk.ru и др.)
    local f
    for d in /etc/nginx/sites-enabled /etc/nginx/conf.d /etc/nginx/sites-available; do
        [[ -d "$d" ]] || continue
        for f in $(find "$d" -maxdepth 1 -name '*camunda*' 2>/dev/null); do
            [[ -f "$f" ]] && echo "$f" && return 0
        done
    done
    # Fallback: только файлы с "camunda" в пути (исключить app, llm, webui)
    grep -rl "server_name camunda.acom-offer-desk.ru" /etc/nginx/ 2>/dev/null | grep -E '/camunda\.acom|/camunda\.' | head -1 || true
}

add_include_to_vhost() {
    local f="$1"
    local include_line="    include ${SNIPPET_FILE};"
    # Разрешаем симлинк — работаем с реальным файлом (не создаём дубли в sites-enabled)
    local real_path
    real_path=$(readlink -f "$f" 2>/dev/null || echo "$f")
    [[ -f "$real_path" ]] || real_path="$f"
    
    if grep -q "camunda-console-optimize" "$real_path" 2>/dev/null; then
        echo "[OK] include уже есть в $real_path"
        return 0
    fi
    
    local backup="/tmp/nginx-camunda-$(basename "$real_path").bak.$(date +%Y%m%d-%H%M%S)"
    echo "[INFO] Бэкап: $backup"
    cp -aL "$real_path" "$backup" 2>/dev/null || cp -a "$real_path" "$backup"
    
    if grep -q "location /modeler-ws" "$real_path"; then
        awk -v inc="$include_line" '
            /location \/modeler-ws/ { in_mw=1 }
            in_mw && /^[[:space:]]*}[[:space:]]*$/ {
                print "    # Console + Optimize (Camunda 8)"
                print inc
                in_mw=0
            }
            { print }
        ' "$real_path" > "${real_path}.new" && mv "${real_path}.new" "$real_path"
        echo "[OK] include добавлен в $real_path"
    else
        echo "[WARN] Добавьте вручную в server { } перед }:"
        echo "  $include_line"
        return 1
    fi
}

main() {
    echo "=== Camunda nginx: Console + Optimize ==="
    echo "Upstream: $UPSTREAM"
    
    write_snippet
    
    VHOST_PATH=$(find_vhost)
    if [[ -n "$VHOST_PATH" && -f "$VHOST_PATH" ]]; then
        add_include_to_vhost "$VHOST_PATH" || true
    else
        echo "[WARN] Vhost не найден автоматически. Добавьте в server { } для camunda.acom-offer-desk.ru:"
        echo "  include ${SNIPPET_FILE};"
    fi
    
    echo "[INFO] nginx -t..."
    if ! nginx -t 2>&1; then
        echo "[ERROR] nginx -t failed. Восстановите vhost из бэкапа."
        exit 1
    fi
    
    echo "[INFO] systemctl reload nginx..."
    systemctl reload nginx
    echo "[OK] Готово"
    echo ""
    echo "Проверка:"
    echo "  curl -sI https://camunda.acom-offer-desk.ru/console/"
    echo "  curl -sI https://camunda.acom-offer-desk.ru/optimize/"
    echo "  curl -sI https://camunda.acom-offer-desk.ru/logout  # 302 -> Keycloak logout"
}

main "$@"
