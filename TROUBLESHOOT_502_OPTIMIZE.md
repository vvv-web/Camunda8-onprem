# 502 Bad Gateway для Optimize — диагностика и исправление

## Объяснение «как ребёнку»

**502 Bad Gateway** — это когда **nginx** (посредник на VPS) не смог получить ответ от **Optimize** (приложение на pop-os).

Схема:

```
Ты (браузер) -> VPS (nginx) -> pop-os (Optimize)
                    ↑
              502 = здесь сломалось
```

nginx говорит: «Я попросил Optimize ответить, но не получил нормальный ответ».

---

## Что может быть не так

### 1. Optimize не работает или «упал»

**Как понять:** контейнер `optimize` в Docker помечен как `unhealthy` или не запущен.

**Что делать:**
```bash
cd Camunda8-onprem
docker compose -f docker-compose-full.yaml restart optimize
```

Через 1–2 минуты снова проверь: https://camunda.acom-offer-desk.ru/optimize/

---

### 2. VPS не видит pop-os (Tailscale)

**Как понять:** nginx на VPS пытается подключиться к `100.69.139.22` (это Tailscale-адрес pop-os), но соединение не устанавливается.

**Почему так:** `100.69.139.22` — это «внутренний» адрес в Tailscale. Если Tailscale на VPS выключен или pop-os в другой сети — VPS до него не доберётся.

**Что проверить на VPS:**
```bash
# Подключись к VPS
ssh root@155.212.160.162

# Попробуй достучаться до Optimize
curl -v --connect-timeout 5 http://100.69.139.22:8083/optimize/
```

- Если **Connection refused** или **timeout** — VPS не видит pop-os. Нужно включить Tailscale на VPS и убедиться, что pop-os в той же сети.
- Если **302** — соединение есть, тогда проблема в другом (например, в настройках nginx).

---

### 3. Таймаут (Optimize отвечает слишком медленно)

Иногда Optimize поднимается долго. nginx по умолчанию ждёт 60 секунд. Если сервис отвечает дольше — 502.

**Что делать:** увеличить таймауты в nginx. Скрипт `apply-nginx-console-optimize.sh` можно дополнить, например:

```
proxy_connect_timeout 120s;
proxy_read_timeout 120s;
proxy_send_timeout 120s;
```

---

### 4. Неправильный upstream в nginx

В скрипте `apply-nginx-console-optimize.sh` используется:
- `100.69.139.22` — Tailscale IP pop-os

Если IP pop-os в Tailscale изменился, nginx будет стучаться не туда.

**Проверка:** на pop-os выполни `tailscale ip` и сравни с `100.69.139.22`. Если адрес другой — перезапусти скрипт с правильным IP:

```bash
CAMUNDA_UPSTREAM=НОВЫЙ_IP ssh root@155.212.160.162 'sudo bash /tmp/camunda-scripts/apply-nginx-console-optimize.sh'
```

---

## Быстрый чеклист

| Шаг | Где | Команда | Ожидаемый результат |
|-----|-----|---------|----------------------|
| 1 | pop-os | `docker ps \| grep optimize` | `Up` (желательно healthy) |
| 2 | pop-os | `curl -sI http://127.0.0.1:8083/optimize/` | HTTP 302 или 200 |
| 3 | VPS | `curl -sI http://100.69.139.22:8083/optimize/` | HTTP 302 или 200 |
| 4 | VPS | `tail -5 /var/log/nginx/error.log` | Последние ошибки nginx |

---

## Автоматическая диагностика (на pop-os)

```bash
cd Camunda8-onprem
bash scripts/diagnose-502-optimize.sh
```

Скрипт проверит контейнер, порт и локальный ответ. Команды для VPS нужно будет выполнить отдельно по SSH.

---

## Ссылки на документацию

- **NGINX proxy_pass:** https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/
- **502 Bad Gateway:** nginx возвращает 502, когда upstream не ответил или вернул некорректный ответ
- **Camunda Optimize deployment:** https://docs.camunda.io/docs/self-managed/optimize-deployment/install-and-start/
