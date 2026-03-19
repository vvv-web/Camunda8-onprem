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
| `.env` | `HOST=camunda.acom-offer-desk.ru`; `KEYCLOAK_HOST=keycloak` |
| `.identity/application.yaml` | browser-facing `issuer-url` и `root-url` переведены на `https://${HOST}` |
| `.orchestration/application.yaml` | `redirectRootUrl` переведён на `https://${HOST}/operate` и `/tasklist` |
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

## 12. Публичный домен через VPS без установки Tailscale пользователям

**Цель:** Пользователи команды открывают Camunda по домену `camunda.acom-offer-desk.ru`, при этом сам стек продолжает работать на корпоративном сервере `pop-os`.

**Что сделано:**
```bash
# На VPS:
# 1. создан отдельный nginx vhost camunda.acom-offer-desk.ru
# 2. проксирование:
#    /      -> http://100.69.139.22:8088
#    /auth/ -> http://100.69.139.22:18080/auth/
# 3. выпущен отдельный Let's Encrypt сертификат
```

**Изменения в Camunda:**
- `HOST` в `.env` переведён на `camunda.acom-offer-desk.ru`
- browser-facing OIDC URL переведены на `https://${HOST}/auth/...`
- `redirectRootUrl` для Operate/Tasklist переведены на `https://${HOST}/operate` и `https://${HOST}/tasklist`
- в Keycloak добавлены корректные redirect URI для клиента `orchestration`
- для Keycloak включены `KC_HOSTNAME=https://${HOST}/auth` и `KC_PROXY_HEADERS=xforwarded`

**Проверка:**
```bash
curl -I https://camunda.acom-offer-desk.ru/auth/
curl -I https://camunda.acom-offer-desk.ru/operate

ACCESS_TOKEN=$(curl -s --request POST "https://camunda.acom-offer-desk.ru/auth/realms/camunda-platform/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "client_id=orchestration" \
  --data-urlencode "client_secret=secret" \
  --data-urlencode "grant_type=client_credentials")
```

**Результат:**
- `https://camunda.acom-offer-desk.ru/auth/` отвечает и редиректит на HTTPS admin path корректно
- `https://camunda.acom-offer-desk.ru/operate` отвечает через VPS
- публичный API `https://camunda.acom-offer-desk.ru/v2/process-definitions/search` отвечает `200`
- существующие проекты `app.acom-offer-desk.ru`, `llm.acom-offer-desk.ru`, `webui.acom-offer-desk.ru` продолжают работать

**Проверка Keycloak admin-функции:**
- временный пользователь `camunda-smoke-user` был создан через `kcadm`, ему был установлен пароль, затем пользователь удалён
- это подтверждает, что контур для создания коллег работает

**Важно:**
- пользователям больше не требуется Tailscale-клиент для обычного входа в Camunda
- Tailscale остаётся только как внутренний защищённый канал между VPS и корпоративным сервером

---

## 13. Web Modeler через публичный домен - интеграция, ошибки, итог

**Цель:** Включить `Web Modeler` для команды через `https://camunda.acom-offer-desk.ru/modeler` без поломки уже работающих `Operate`, `Tasklist`, `Identity` и `Keycloak`.

**Что изменили в проекте:**
- в `docker-compose-full.yaml` и `docker-compose-web-modeler.yaml` browser-facing URL для Web Modeler переведены с `localhost` на `https://${HOST}/modeler`
- для websocket добавлен отдельный публичный путь `/modeler-ws`
- в `web-modeler-webapp` включены:
  - `CLIENT_PUSHER_HOST=${HOST}`
  - `CLIENT_PUSHER_PORT=443`
  - `CLIENT_PUSHER_PATH=/modeler-ws`
  - `CLIENT_PUSHER_FORCE_TLS=true`
- в `web-modeler-restapi` backend issuer переведён на `https://${HOST}/auth/realms/camunda-platform`
- в `.identity/application.yaml` root URL для `web-modeler` переведён на `https://${HOST}/modeler`
- в `orchestration` добавлена аудитория `web-modeler`
- в `scripts/validate-config.sh` добавлены проверки на URL, websocket path и audience для Web Modeler
- создан файл `NGINX_WEB_MODELER_SNIPPET.conf.example` с готовыми `location /modeler` и `location /modeler-ws`
- обновлены `ACCESS_FOR_TEAM.md`, `DEPLOY_STEPS.md`, `PROJECT_INFO.md`

**С чем столкнулись:**

| Проблема | Причина | Как исправили |
|----------|---------|---------------|
| `web-modeler-restapi` unhealthy, `issuer mismatch` | backend ожидал внутренний issuer `http://keycloak:18080/...`, а Keycloak публиковал внешний `https://${HOST}/auth/...` | выровняли `RESTAPI_OAUTH2_TOKEN_ISSUER_BACKEND_URL` на внешний HTTPS issuer |
| `web-modeler-webapp` не поднимался стабильно | frontend и backend были настроены на разные browser-facing URL и аудитории | синхронизировали `SERVER_URL`, audience и websocket-параметры |
| публичный `https://camunda.acom-offer-desk.ru/modeler` отдавал `404` | на VPS в `nginx` не было отдельных маршрутов для `Web Modeler` | в vhost `camunda.acom-offer-desk.ru` добавлены `location /modeler` -> `http://100.69.139.22:8070` и `location /modeler-ws` -> `http://100.69.139.22:8060` |
| риск сломать действующие маршруты `/` и `/auth/` | `Web Modeler` публиковался поверх уже работающего домена | добавлены только два новых `location`, существующие маршруты не менялись |
| `curl` на `/modeler-ws` возвращает `404` | websocket endpoint не предназначен для обычной HTTP-проверки через простой `curl` | приняли это как некритично, потому что браузерный сценарий `Web Modeler` работает |

**Что проверили:**
```bash
# локально на pop-os
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8070/modeler
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8088/operate
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8084

# публично через VPS
curl -k -I https://camunda.acom-offer-desk.ru/modeler
curl -k -I https://camunda.acom-offer-desk.ru/modeler/login
curl -k -I https://camunda.acom-offer-desk.ru/operate
curl -k -I https://camunda.acom-offer-desk.ru/auth/
```

**Фактический результат проверки:**
- `https://camunda.acom-offer-desk.ru/modeler` отвечает `302` на `/modeler/login`
- `https://camunda.acom-offer-desk.ru/modeler/login` отвечает `200`
- `https://camunda.acom-offer-desk.ru/operate` продолжает отвечать штатно
- `https://camunda.acom-offer-desk.ru/auth/` продолжает отвечать штатно
- в браузере `Web Modeler` открывается, загружается домашний экран `Modeler | Home`
- кнопка `Create new project` работает, открывается экран `Modeler | New project`

**Вывод:**
- `Web Modeler` безопасно встроен в существующий on-prem стек
- публичный вход для команды работает через домен
- уже работающие компоненты Camunda не сломаны

---

## 14. Выдача полного доступа пользователю `alexander_kotov`

**Что сделали:**
- проверили, что у `alexander_kotov` уже есть cluster-роль `admin` в `Identity`
- сравнили набор realm-ролей пользователя `demo` и `alexander_kotov` через `kcadm`
- выдали `alexander_kotov` такой же management-набор ролей, как у `demo`

**Назначенные роли:**
- `ManagementIdentity`
- `Optimize`
- `Web Modeler`
- `Web Modeler Admin`
- `Console`
- `Orchestration`

**Команда:**
```bash
docker compose -f docker-compose-full.yaml exec -T keycloak /opt/bitnami/keycloak/bin/kcadm.sh add-roles \
  -r camunda-platform \
  --config /tmp/kcadm.config \
  --uid 29eeb7de-0c43-4185-8337-ba99e8caca12 \
  --rolename ManagementIdentity \
  --rolename Optimize \
  --rolename "Web Modeler" \
  --rolename "Web Modeler Admin" \
  --rolename Console \
  --rolename Orchestration
```

**Чем проверили:**
- под `alexander_kotov` открылся `Web Modeler`
- работает `Create new project`
- `Operate` открывается штатно
- `Identity` открывается без ошибки доступа

**Итог:**
- пользователь `alexander_kotov` получил полный рабочий доступ к текущему стенду Camunda по нашей схеме доступа

---

## 15. Публичные маршруты /console и /optimize на VPS nginx

**Проблема:** `https://camunda.acom-offer-desk.ru/console` и `/optimize` возвращали 404 — в nginx на VPS не было соответствующих `location`.

**Решение:**
1. Создан `NGINX_CONSOLE_OPTIMIZE_SNIPPET.conf.example` с готовыми `location` для Console (порт 8087) и Optimize (порт 8083).
2. Создан скрипт `scripts/apply-nginx-console-optimize.sh` для безопасного применения на VPS.

**Применение на VPS 155.212.160.162:**

```bash
# С pop-os (или машины с SSH-доступом к VPS):
scp -r /home/cpz_ai/Desktop/Camunda8-onprem/scripts root@155.212.160.162:/tmp/camunda-scripts
ssh root@155.212.160.162 'sudo bash /tmp/camunda-scripts/apply-nginx-console-optimize.sh'
```

Скрипт:
- создаёт `/etc/nginx/snippets/camunda-console-optimize.conf`
- ищет vhost для `camunda.acom-offer-desk.ru` и добавляет `include`
- делает бэкап перед изменениями
- выполняет `nginx -t` перед `reload`
- при ошибке не выполняет `reload`

**Ручное применение** (если скрипт не подходит):
- Добавить блоки из `NGINX_CONSOLE_OPTIMIZE_SNIPPET.conf.example` в server { } vhost для camunda.acom-offer-desk.ru.
- Выполнить `nginx -t && systemctl reload nginx`.

**Проверка:**
```bash
curl -sI https://camunda.acom-offer-desk.ru/console/
curl -sI https://camunda.acom-offer-desk.ru/optimize/
```
Ожидаемо: `302` или `200` (не 404).

---

## 16. Invalid parameter: redirect_uri для Console и Optimize (igor_bolshakov)

**Проблема:** При входе под igor_bolshakov на `/console` и `/optimize` — ошибка `Invalid parameter: redirect_uri`. В Keycloak у клиентов `console` и `optimize` были root-url и redirect URIs только для localhost.

**Решение:**
1. Обновлён `.identity/application.yaml`: root-url для `console` и `optimize` переведены на `https://${HOST}/console` и `https://${HOST}/optimize`.
2. Создан скрипт `scripts/fix-keycloak-redirect-uris.sh` — обновляет Keycloak clients через kcadm.

**Применение:**
```bash
cd /home/cpz_ai/Desktop/Camunda8-onprem
./scripts/fix-keycloak-redirect-uris.sh
```

**Источники:** [Camunda Identity Configuration](https://docs.camunda.io/docs/self-managed/identity/miscellaneous/configuration-variables/), [Keycloak Redirect URIs](https://www.keycloak.org/docs/latest/server_admin/#_redirect-uris).

---

## 17. Неверный proxy_pass для Console/Optimize и «Client disabled»

**Симптомы:**
- `/console/` — «Cannot GET /» или 404 (Express);
- `/optimize/` — HTTP 404;
- Keycloak — «We are sorry… Client disabled».

**Причина 1 (nginx):** В сниппете были `proxy_pass http://UPSTREAM:8087/` и `…:8083/` **без** суффиксов `/console/` и `/optimize/`. По правилам nginx URI после `location` отрезается, на бэкенд уходит `/` вместо `/console/` и `/optimize/`. У Camunda Console задан `CAMUNDA_CONSOLE_CONTEXT_PATH: console`, Optimize — `SERVER_SERVLET_CONTEXT_PATH: /optimize`; корень `/` там не обслуживается.

**Правильно:**
```nginx
proxy_pass http://100.69.139.22:8087/console/;
proxy_pass http://100.69.139.22:8083/optimize/;
```
Плюс `location /static/` → `…:8083/optimize/static/` для OAuth redirect.

**Офф. справка по proxy_pass:** [NGINX Reverse Proxy](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/).

**Причина 2 (Keycloak):** Клиент OIDC отключён (`enabled=false`). Включить:

```bash
cd Camunda8-onprem
./scripts/fix-keycloak-enable-clients.sh
```

Скрипт: `scripts/fix-keycloak-enable-clients.sh` — `enabled=true` для `orchestration`, `console`, `optimize`, `web-modeler`.

**Проверка:**
```bash
curl -sI https://camunda.acom-offer-desk.ru/console/   # 200
curl -sI https://camunda.acom-offer-desk.ru/optimize/ # 302 на auth
```

---

[шаг завершён]
