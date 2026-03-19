# Как удерживать публичный доступ Camunda стабильным

**Цель:** после правок nginx / Keycloak / Docker не ломать `https://camunda.acom-offer-desk.ru/*` и не трогать `app.acom-offer-desk.ru`.

---

## 1. Единый источник правды

| Что | Где в репозитории |
|-----|-------------------|
| Сниппет nginx (правильные `proxy_pass` с `/console/` и `/optimize/`) | `scripts/apply-nginx-console-optimize.sh` → блок `write_snippet` |
| Пример для ручной вставки | `NGINX_CONSOLE_OPTIMIZE_SNIPPET.conf.example` |
| Что уже ломалось и как чинили | `FIXES_APPLIED.md` разделы **15–17** |

**Правило:** меняете маршруты Camunda на VPS — сначала правите скрипт в Git, затем копируете на VPS и запускаете. Не правьте только `/etc/nginx/snippets/camunda-console-optimize.conf` на сервере без отражения в репозитории.

---

## 2. Применение nginx на VPS (после любого изменения скрипта)

```bash
scp -r /path/to/Camunda8-onprem/scripts root@155.212.160.162:/tmp/camunda-scripts
ssh root@155.212.160.162 'sudo bash /tmp/camunda-scripts/apply-nginx-console-optimize.sh'
```

Скрипт настроен так, чтобы **не трогать** vhost `app.acom-offer-desk.ru` и писать бэкап в `/tmp`.

**Критично в сниппете:**

- `proxy_pass …:8087/console/;` (не `…:8087/`)
- `proxy_pass …:8083/optimize/;` (не `…:8083/`)
- блок `location /static/` → `…:8083/optimize/static/`

Иначе снова появятся «Cannot GET /» и 404 на Optimize. См. [NGINX Reverse Proxy](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/).

---

## 3. Проверка сразу после деплоя (обязательный минимум)

```bash
curl -sI https://camunda.acom-offer-desk.ru/console/   # ожидаем 200 или 302
curl -sI https://camunda.acom-offer-desk.ru/optimize/   # ожидаем 302 на auth
curl -sI https://camunda.acom-offer-desk.ru/operate    # ожидаем 200 или 302
curl -sI https://camunda.acom-offer-desk.ru/logout      # ожидаем 302 на Keycloak logout
curl -sI https://app.acom-offer-desk.ru/               # другой проект — 200
```

---

## 4. Keycloak

- После смены домена / redirect URI: `./scripts/fix-keycloak-redirect-uris.sh`
- Если в браузере **«Client disabled»**: `./scripts/fix-keycloak-enable-clients.sh`
- В админке Keycloak не отключайте клиентов `orchestration`, `console`, `optimize`, `web-modeler` без необходимости.

Документация: [Keycloak Server Admin](https://www.keycloak.org/docs/latest/server_admin/).

---

## 5. Docker / pop-os

- Tailscale на VPS должен видеть IP pop-os (upstream в сниппете, по умолчанию `100.69.139.22`).
- После смены `HOST` в `.env` часто нужен пересоздание контейнеров с OIDC — см. `DEPLOY_STEPS.md`.

---

## 6. Автоматизация (по желанию)

- Раз в день cron на любой машине с доступом в интернет: те же `curl -sI` + уведомление при не 2xx/302.
- Или шаг в CI после merge в ветку с инфраструктурой: «dry-run» не применим к nginx на VPS, но можно проверять, что в репозитории в `apply-nginx-console-optimize.sh` есть строки `8087/console/` и `8083/optimize/` (grep в workflow).

---

## 7. Краткий чеклист «ничего не сломать»

1. Правки nginx Camunda — только через скрипт из репо → scp → запуск на VPS.
2. Не создавать в `sites-enabled` лишние симлинки «бэкапов» (они дублируют `server_name`).
3. После деплоя — четыре `curl` на camunda + один на app.
4. Keycloak: не отключать OIDC-клиентов; при проблемах — `fix-keycloak-enable-clients.sh`.

---

✅ **Reason:** стабильность = воспроизводимый деплой из Git + явные проверки + защита от известных антипаттернов (`proxy_pass` без context path).
