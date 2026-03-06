# Camunda 8 — применённые исправления и команды

Документ фиксирует исправления, выполненные при развёртывании Camunda 8 on-prem на pop-os (LAN 10.16.66.48). Все команды — для повторения после переустановки или на другой машине.

---

## 1. Системный прокси (GNOME)

**Проблема:** Браузер получал `ERR_PROXY_CONNECTION_FAILED` из‑за включённого прокси `127.0.0.1:12334`, который не работал.

**Команда:**
```bash
gsettings set org.gnome.system.proxy mode 'none'
```

**Пояснение:** Отключает системный прокси; применяется глобально к системе, не входит в репозиторий Camunda.

---

## 2. Запуск PostgreSQL и стека

**Проблема:** Контейнер `postgres` не был запущен → Keycloak не мог резолвить хост `postgres` (`cannot resolve host "postgres"`).

**Команда:**
```bash
cd /home/cpz_ai/Desktop/Camunda8-onprem
docker compose -f docker-compose-full.yaml up -d
```

**Пояснение:** Поднимает весь стек; `postgres` должен стартовать раньше Keycloak. При запуске не по порядску — перезапуск Keycloak: `docker compose -f docker-compose-full.yaml restart keycloak`.

---

## 3. OIDC redirect URI в Keycloak (клиент orchestration)

**Проблема:** У клиента `orchestration` в realm `camunda-platform` был только `http://localhost:8088/sso-callback`. При доступе по LAN `http://10.16.66.48:8088` возникала ошибка `invalid_redirect_uri`.

**Повтор (если Keycloak уже инициализирован и не пересоздаётся из Identity):**

```bash
# Узнать ID клиента orchestration
docker exec keycloak /opt/bitnami/keycloak/bin/kcadm.sh get clients \
  --config /tmp/kcadm.config -r camunda-platform -q clientId=orchestration

# Добавить redirect URI для LAN (заменить CLIENT_UUID на полученный ID)
docker exec keycloak /opt/bitnami/keycloak/bin/kcadm.sh update clients/CLIENT_UUID \
  --config /tmp/kcadm.config -r camunda-platform \
  -s 'redirectUris=["http://localhost:8088/sso-callback","http://10.16.66.48:8088/sso-callback"]'
```

**Постоянное исправление в конфигурации:** В `.identity/application.yaml` для preset `orchestration` задано:
```yaml
root-url: "http://${HOST:localhost}:8088"
```
При `HOST=10.16.66.48` в `.env` Identity при инициализации Keycloak зарегистрирует redirect URI с LAN‑адресом. Для уже существующего realm используйте команду `kcadm` выше.

---

## 4. redirectRootUrl в Orchestration (Operate, Tasklist)

**Проблема:** В `.orchestration/application.yaml` были жёстко прописаны `localhost:8088`, из‑за чего OIDC редиректы не работали при LAN‑доступе.

**Исправление (уже внесено):**
```yaml
operate:
  identity:
    redirectRootUrl: "http://${HOST:localhost}:8088/operate"
tasklist:
  identity:
    redirectRootUrl: "http://${HOST:localhost}:8088/tasklist"
```

**Файл:** `.orchestration/application.yaml`  

**Пояснение:** `${HOST:localhost}` берёт `HOST` из `.env`; при отсутствии используется `localhost`.

---

## 5. Встроенный браузер Cursor: 502 из-за proxy

**Проблема:** во встроенном браузере Cursor открытие `http://10.16.66.48:8088/...` давало `HTTP 502`, при этом в Firefox сервисы работали.  
Причина: Cursor запускался с proxy-переменными окружения (`http_proxy/https_proxy/...`) на `127.0.0.1:12334`.

**Рабочий запуск Cursor без proxy:**
```bash
cursor --no-proxy-server
```

**Пояснение:** флаг Chromium отключает proxy для процесса Cursor и встроенного браузера.

---

## 6. Безопасные настройки Cursor (чтобы не сломать старт)

**Проблема:** некорректные поля proxy в `~/.config/Cursor/User/settings.json` могут ломать запуск Cursor.

**Рабочий минимальный шаблон:**
```json
{
  "http.proxySupport": "off",
  "http.noProxy": [
    "localhost",
    "127.0.0.1",
    "10.16.66.48"
  ],
  "cursor.general.disableHttp2": true
}
```

**Важно:**
- не использовать `http.proxy` с пустой строкой `""`;
- `http.noProxy` задавать массивом, а не строкой.

---

## 7. Поведение Tasklist в Camunda 8.8

**Факт:** при открытии `http://127.0.0.1:8088/tasklist` UI может открываться как unified интерфейс Operate (это ожидаемо для 8.8 orchestration cluster).

**Практический вывод:** для базовой проверки доступа достаточно успешного логина через Identity и открытия UI без 502/ошибок авторизации.

---

## 8. Практическая проверка после развёртывания (smoke test)

Дата проверки: 2026-03-05.

### Проверка сервисов (без proxy переменных)

```bash
env -u http_proxy -u https_proxy -u all_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
curl -s -o /dev/null -w "operate=%{http_code}\n" http://127.0.0.1:8088/operate

env -u http_proxy -u https_proxy -u all_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
curl -s -o /dev/null -w "tasklist=%{http_code}\n" http://127.0.0.1:8088/tasklist

env -u http_proxy -u https_proxy -u all_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
curl -s -o /dev/null -w "console=%{http_code}\n" http://127.0.0.1:8087

env -u http_proxy -u https_proxy -u all_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
curl -s -o /dev/null -w "api_v2=%{http_code}\n" http://127.0.0.1:8088/v2
```

Ожидаемо и подтверждено:
- `operate=401` (нужен логин),
- `tasklist=401` (нужен логин),
- `console=200`,
- `api_v2=401` (нужен токен).

### UI-проверка

- `Operate` открывается и доступен после логина через Identity.
- `Tasklist` URL в 8.8 может открывать unified UI (`Operate`).
- `Console` открывается (`Camunda | Console`).

### Инцидент Optimize и восстановление

Симптом:
- `optimize` периодически становился `unhealthy`,
- HTTP `http://127.0.0.1:8083` возвращал `000`.

Ошибка в логах:
- `Failed retrieving Optimize metadata document from database!`
- `no_shard_available_action_exception` для `optimize-metadata`.

Восстановление:
```bash
docker compose -f docker-compose-full.yaml restart optimize
```

Результат после восстановления:
- `optimize` перешёл в `healthy`,
- `http://127.0.0.1:8083` начал возвращать `302` (редирект на логин) — это рабочее состояние.

---

## 9. E2E пользовательский сценарий (процесс + user task)

Дата проверки: 2026-03-05.

### Что проверяли

1. Деплой простого BPMN (Start -> User Task -> End).
2. Запуск инстанса процесса.
3. Проверка появления инстанса в Operate.
4. Проверка наличия user task через Orchestration Cluster API.

### Тестовый ресурс

Файл:
- `e2e-smoke-user-task.bpmn`

Process ID:
- `e2e_smoke_user_task`

### Команды (без proxy env)

```bash
# Токен
curl -s --request POST "http://127.0.0.1:18080/auth/realms/camunda-platform/protocol/openid-connect/token" \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "client_id=orchestration" \
  --data-urlencode "client_secret=secret" \
  --data-urlencode "grant_type=client_credentials"

# Деплой BPMN
curl -s -X POST "http://127.0.0.1:8088/v2/deployments" \
  -H "Authorization: Bearer <TOKEN>" \
  -F "resources=@/home/cpz_ai/Desktop/Camunda8-onprem/e2e-smoke-user-task.bpmn"

# Старт инстанса
curl -s -X POST "http://127.0.0.1:8088/v2/process-instances" \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"processDefinitionId":"e2e_smoke_user_task","processDefinitionVersion":1,"variables":{"requestId":"SMOKE-001"}}'

# Проверка инстанса
curl -s -H "Authorization: Bearer <TOKEN>" \
  "http://127.0.0.1:8088/v2/process-instances/2251799813703909"

# Проверка user task
curl -s -X POST -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  "http://127.0.0.1:8088/v2/user-tasks/search" \
  -d '{"filter":{"processInstanceKey":"2251799813703909"}}'
```

### Результаты

- Deployment: успешно.
- Process instance: создан (`processInstanceKey=2251799813703909`, `state=ACTIVE`).
- User task: найдена (`name="Approve Request"`, `state="CREATED"`).
- Operate UI: показывает `1 Running Process Instances` и процесс `E2E Smoke User Task`.

### Проверка DoD

- UI логин проходит: **Да**.
- Operate показывает инстанс после запуска процесса: **Да**.
- API v2 отвечает: **Да** (`/v2`, `/v2/process-instances`, `/v2/user-tasks/search`).
- Нет 502 в рабочем режиме Cursor: **Да**, при запуске `cursor --no-proxy-server`.
- Контейнеры не рестартятся циклически: **Да**, критичные сервисы стабильны (restart count не растёт во времени проверки).

---

## Сводка файлов

| Файл | Изменение |
|------|-----------|
| `.env` | `HOST=10.16.66.48` (LAN) или `100.69.139.22` (Tailscale); `KEYCLOAK_HOST=keycloak` |
| `.identity/application.yaml` | `root-url: "http://${HOST:localhost}:8088"` для orchestration |
| `.orchestration/application.yaml` | `redirectRootUrl` через `${HOST:localhost}` для operate/tasklist |
| `Camunda-OneClick-Windows-AutoInstall.zip` | На Desktop: `/home/cpz_ai/Desktop/` — скрипт для доступа с ноутов через Tailscale |

---

## При переустановке

1. Убедиться, что `.env` содержит `HOST` с нужным значением.
2. Выполнить `docker compose -f docker-compose-full.yaml up -d`.
3. Если Keycloak был пересоздан с нуля — Identity при старте обновит redirect URI из `.identity/application.yaml`.
4. Если Keycloak уже существовал и не пересоздавался — выполнить команду `kcadm` из раздела 3.

---

## 10. Keycloak SSL Required для доступа через Tailscale

**Проблема:** При доступе к Camunda через Tailscale (IP `100.69.x.x`) Keycloak показывал «Требуется HTTPS» и в логах: `LOGIN_ERROR ... error="ssl_required"`.

**Причина:** По умолчанию realm `camunda-platform` имеет `sslRequired=external`. Tailscale использует IP из CGNAT-диапазона `100.64.0.0/10`, который Keycloak считает «внешним» (не private 10.x/192.168.x/172.16.x), поэтому требует HTTPS.

**Исправление:**
```bash
docker compose -f docker-compose-full.yaml exec -T keycloak /opt/bitnami/keycloak/bin/kcadm.sh config credentials --config /tmp/kcadm.config --server http://localhost:18080/auth --realm master --user admin --password admin
docker compose -f docker-compose-full.yaml exec -T keycloak /opt/bitnami/keycloak/bin/kcadm.sh update realms/camunda-platform --config /tmp/kcadm.config -s sslRequired=NONE
```

**Важно:** `sslRequired=NONE` допустим только для dev/demo. В production — использовать HTTPS или настраивать trusted proxies.

---

## 11. One-Click скрипт (Windows) — ошибки и исправления

**Назначение:** Скрипт для коллег: установка Tailscale, подключение к tailnet, открытие Operate/Tasklist на ноуте с доступом к корпоративному серверу Camunda.

**Архив:** `/home/cpz_ai/Desktop/Camunda-OneClick-Windows-AutoInstall.zip`  
Содержит: `camunda-windows-oneclick-fullauto.ps1`, `START_CAMUNDA.cmd`.

### Ошибки и исправления

| Ошибка | Причина | Исправление |
|--------|---------|-------------|
| `param(...)` — «Недопустимое условие назначения» | В PowerShell блок `param` должен быть первой конструкцией в файле; перед ним стояла строка `$ErrorActionPreference` | Перенести `param(...)` в самое начало скрипта |
| «Аргумент ... не существует» | Запуск `.cmd` из ZIP preview (временная папка) — рядом нет `.ps1` | Добавить проверку `if not exist "%SCRIPT_PATH%"` и инструкцию «Extract All» |
| Окно CMD мигает и закрывается | Скрипт падал рано, launcher не делал `pause` | Добавить `pause` в конец `.cmd`, писать лог в `camunda-run.log` |
| `1) Right-click` — «Непредвиденное появление» | В batch внутри `if (...)` скобки `)` в `echo 1)` парсились как конец блока | Экранировать: `echo 1^)` |
| UAC-эскалация → Exit code 1 | Запрос админ-прав ломался при передаче аргументов | Запрашивать админ только при первой установке Tailscale; если Tailscale уже есть — работать без UAC |
| «Требуется HTTPS» после логина | Keycloak realm `sslRequired=external` не разрешает HTTP с Tailscale IP (100.x) | Выполнить `kcadm ... update realms/camunda-platform -s sslRequired=NONE` (раздел 10) |

### Доступ через Tailscale

- На сервере в `.env`: `HOST=100.69.139.22` (Tailscale IP pop-os).
- После `docker compose ... up -d --force-recreate keycloak identity orchestration`.
- На ноуте: установить Tailscale, войти в тот же tailnet, открыть `http://100.69.139.22:8088/operate` и `.../tasklist`.

---

[шаг завершён]
