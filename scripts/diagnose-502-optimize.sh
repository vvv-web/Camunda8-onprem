#!/usr/bin/env bash
# Диагностика 502 Bad Gateway для /optimize/
# Запуск: на pop-os (локально) или по SSH на VPS
#
# Цель: понять, почему nginx возвращает 502 при обращении к Optimize.
# Маршрут: браузер -> VPS nginx -> pop-os:8083 (Optimize)

set -e

POP_OS_IP="${CAMUNDA_UPSTREAM:-100.69.139.22}"
VPS_IP="155.212.160.162"

echo "=== Диагностика 502 Optimize ==="
echo ""
echo "Маршрут запроса:"
echo "  Браузер -> VPS ($VPS_IP) nginx -> pop-os ($POP_OS_IP):8083 Optimize"
echo ""

# --- На pop-os (локально) ---
echo "--- 1. Pop-os: Optimize контейнер ---"
if command -v docker &>/dev/null; then
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q '^optimize$'; then
        docker ps -a --filter name=^optimize$ --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        echo "[?] Docker не доступен или контейнер optimize не найден"
    fi
else
    echo "[?] Docker не установлен"
fi
echo ""

echo "--- 2. Pop-os: порт 8083 слушает? ---"
if command -v ss &>/dev/null; then
    ss -tlnp 2>/dev/null | grep -E ':8083|:8090' || echo "[!] Порт 8083 не слушается"
elif command -v netstat &>/dev/null; then
    netstat -tlnp 2>/dev/null | grep -E ':8083|:8090' || echo "[!] Порт 8083 не слушается"
else
    echo "[?] ss/netstat не найдены"
fi
echo ""

echo "--- 3. Pop-os: Optimize отвечает локально? ---"
CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://127.0.0.1:8083/optimize/ 2>/dev/null || echo "ERR")
if [[ "$CODE" == "ERR" ]]; then
    echo "[!] curl не смог подключиться (таймаут или отказ)"
else
    echo "HTTP $CODE (ожидаем 302 или 200)"
fi
echo ""

# --- На VPS (если запускаем по SSH) ---
echo "--- 4. VPS: может ли nginx достучаться до pop-os? ---"
echo "Запустите НА VPS (ssh root@$VPS_IP):"
echo "  curl -v --connect-timeout 5 http://$POP_OS_IP:8083/optimize/"
echo ""
echo "Если 'Connection refused' или таймаут -> VPS не видит pop-os."
echo "Причина: Tailscale на VPS выключен или pop-os в другой сети."
echo ""

echo "--- 5. VPS: логи nginx (последняя ошибка 502) ---"
echo "Запустите НА VPS:"
echo "  tail -20 /var/log/nginx/error.log"
echo ""

echo "--- Итог ---"
echo "502 = nginx не получил ответ от pop-os:8083."
echo "Проверьте: 1) Optimize запущен, 2) VPS видит $POP_OS_IP (Tailscale)."
echo ""
echo "Быстрый рестарт Optimize (на pop-os):"
echo "  cd Camunda8-onprem && docker compose -f docker-compose-full.yaml restart optimize"
echo ""
