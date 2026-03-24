# Мониторинг Camunda 8 (Prometheus + Grafana)

## Что развёрнуто (стек мониторинга)

В рамках этого репозитория добавлен **отдельный наблюдаемый контур** (не трогает публичный Nginx и обычный `docker compose up` без профиля):

| Компонент | Роль | Где в Compose |
|-----------|------|----------------|
| **Prometheus** | Сбор метрик (poll) с Camunda и Connectors по `/actuator/prometheus` | Сервис `prometheus`, профиль **`monitoring`** |
| **Grafana** | Визуализация; datasource Prometheus; официальные дашборды Camunda **Zeebe** и **Data Layer** (file provisioning) | Сервис `grafana`, профиль **`monitoring`** |
| **Источник метрик** | Уже был в стеке: `orchestration` (порт **9600**), **Connectors** (**8080**); scrape описан в `monitoring/prometheus.yml` | Без отдельных контейнеров |

**Запуск:** `docker compose -f docker-compose-full.yaml --profile monitoring up -d`  
**Доступ с хоста (только localhost):** Prometheus `http://127.0.0.1:19090`, Grafana `http://127.0.0.1:13000`  
**Данные:** тома Docker `prometheus_data`, `grafana_data`  
**Документация по шагам и официальным ссылкам:** разделы ниже на этой странице.

---

**Какие дашборды и строки важнее остальных:** см. [`MONITORING_DASHBOARD_PRIORITY.md`](./MONITORING_DASHBOARD_PRIORITY.md).  
**Итог по SMART (для отчётов):** [`MONITORING_SMART.md`](./MONITORING_SMART.md).

**Маршрутизация (plugin-orchestrator):** primary — `docs-and-research` / DevOps-правила; secondary не требуется до появления отдельной задачи (например CI). **Автоматизация:** не обязательна; при желании позже — отдельный контур (Alertmanager и т.д.).

Каждый шаг ниже сопоставлен **официальной** документации (проверяйте актуальность версии в URL, у вас в `.env.example` задано **Camunda 8.8.x**).

---

## Шаг 1 — Изоляция от основного стека (без поломки `docker compose up`)

**Официально:** профили в Compose — сервисы с `profiles` не запускаются, пока не указан профиль.

- Документ: [Use profiles with Compose](https://docs.docker.com/compose/how-tos/profiles/) (Docker Docs).

**Что сделано в репозитории:** `prometheus` и `grafana` в `docker-compose-full.yaml` с `profiles: ["monitoring"]`. Обычный запуск без профиля **не поднимает** эти контейнеры и **не меняет** Nginx / Keycloak / OIDC.

---

## Шаг 2 — Endpoint метрик Camunda (orchestration)

**Официально:** для Prometheus используется **polling**; endpoint на management-контексте, по умолчанию **`:9600/actuator/prometheus`**; в примере scrape указаны `metrics_path: /actuator/prometheus`, `scheme: http`, target с портом **9600**.

- Документ: [Camunda components metrics](https://docs.camunda.io/docs/self-managed/operational-guides/monitoring/metrics/) → разделы *Polling*, *Prometheus*, пример scrape job.

**Что уже в проекте:** порт `9600:9600` у сервиса `orchestration`, в `.orchestration/application.yaml` — `management.endpoints.web.exposure.include: ... prometheus` (Spring Boot Actuator).

---

## Шаг 3 — Конфигурация Prometheus (`scrape_configs`)

**Официально:** описание блока `scrape_config` в конфигурации Prometheus.

- Документ: [Configuration / scrape_config](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#scrape_config).

**Файл:** `monitoring/prometheus.yml` — jobs для `orchestration:9600` и `connectors:8080` (второй — опционально; при ошибках scrape отключите job в файле).

---

## Шаг 4 — Grafana: источник данных через provisioning

**Официально:** provisioning data sources из каталога `provisioning/datasources`.

- Документ: [Provisioning / Data sources](https://grafana.com/docs/grafana/latest/administration/provisioning/#data-sources).

**Файл:** `monitoring/grafana/provisioning/datasources/prometheus.yaml` → URL `http://prometheus:9090` (имя сервиса из Compose).

---

## Шаг 5 — Готовые дашборды Camunda (источник + UID Prometheus)

**Официально (Camunda):** в разделе *Grafana* перечислены предсобранные дашборды:

- **Zeebe** — файл в репозитории Camunda: `monitor/grafana/zeebe.json` (для 8.8 — ветка `stable/8.8`).
- **Data layer** — `monitor/grafana/dashboards/data_layer.json` (Camunda **≥ 8.8**, фокус на exporter).

Ссылки на те же файлы в GitHub (raw), с которых синхронизированы копии в репозитории:

- [zeebe.json (stable/8.8)](https://raw.githubusercontent.com/camunda/camunda/stable/8.8/monitor/grafana/zeebe.json)
- [data_layer.json (stable/8.8)](https://raw.githubusercontent.com/camunda/camunda/stable/8.8/monitor/grafana/dashboards/data_layer.json)

Документ: [Camunda components metrics — Grafana](https://docs.camunda.io/docs/self-managed/operational-guides/monitoring/metrics/) (подзаголовки *Zeebe*, *Data layer*).

**Официально (Grafana):** дашборды подхватываются **file provisioning**, без ручного импорта в UI.

- Документ: [Provisioning — Dashboards](https://grafana.com/docs/grafana/latest/administration/provisioning/#dashboards).

**Что в репозитории:**

| Файл | Назначение |
|------|------------|
| `monitoring/grafana/provisioning/dashboards/camunda.yaml` | provider, папка **Camunda** |
| `monitoring/grafana/provisioning/dashboards/json/zeebe.json` | официальный Zeebe (в JSON подставлен UID datasource `camunda-prometheus`) |
| `monitoring/grafana/provisioning/dashboards/json/data_layer.json` | официальный data layer |

Обновить JSON с upstream: `./scripts/fetch-camunda-grafana-dashboards.sh` (ветка `stable/8.8`).

**Замечание:** дашборд Zeebe ориентирован в т.ч. на Kubernetes (`namespace`, `pod`). В Docker Compose часть панелей может быть пустой, пока нет таких меток — это ожидаемо; метрики `zeebe_*` с `job`/`instance` всё равно собираются Prometheus.

**Версия Grafana:** образ по умолчанию **12.0.2** — в оригинальном `zeebe.json` в `__requires` указана Grafana ~12.0.x (поля `__requires` в закоммиченной копии удалены как служебные для импорта).

---

## Шаг 6 — Запуск только мониторинга (при уже работающем стеке)

Из каталога `Camunda8-onprem`:

```bash
docker compose -f docker-compose-full.yaml --profile monitoring up -d
```

UI (только **localhost**, не проброшено на все интерфейсы):

- Prometheus: `http://127.0.0.1:19090`
- Grafana: `http://127.0.0.1:13000`

Переменные (опционально, см. `.env.example`): `PROMETHEUS_VERSION`, `GRAFANA_VERSION`, `GRAFANA_ADMIN_USER`, `GRAFANA_ADMIN_PASSWORD`.

---

## Безопасность

Не публикуйте Prometheus/Grafana на VPS без TLS и сильной аутентификации. Текущие порты привязаны к `127.0.0.1` на хосте с Docker — доступ с других машин по сети **не открыт** этими строками `ports:`.

---

## Если scrape возвращает 403/401

**Официально (Camunda):** в доке по метрикам приведены свойства `management.endpoint.prometheus.access` и экспорт Prometheus (см. тот же раздел [Configuration / Prometheus](https://docs.camunda.io/docs/self-managed/operational-guides/monitoring/metrics/)).

При необходимости согласуйте с [Spring Boot Actuator / Metrics](https://docs.spring.io/spring-boot/reference/actuator/metrics.html) (версия Spring Boot в образе Camunda должна соответствовать доке).

**Не меняйте** публичные URL и nginx-сниппеты, если проблема только во внутреннем scrape: сначала проверьте `curl` из контейнера `camunda-prometheus` или с хоста на `127.0.0.1:9600/actuator/prometheus`.

---

## Проверка после запуска (чеклист)

**Официально (Grafana):** состояние и список источников данных доступны через [HTTP API](https://grafana.com/docs/grafana/latest/developer-resources/http-api/data-source/) (например `GET /api/datasources` с basic auth).

**Официально (Prometheus):** активные цели scrape — [Querying API / Targets](https://prometheus.io/docs/prometheus/latest/querying/api/#targets) (`GET /api/v1/targets`).

Минимальный набор проверок на хосте с Docker:

```bash
# Grafana жива
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:13000/api/health   # ожидается 200

# Prometheus: цели UP
curl -s "http://127.0.0.1:19090/api/v1/targets?state=active" | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Grafana: источник Prometheus (замените учётные данные при смене в .env)
curl -s -u admin:admin http://127.0.0.1:13000/api/datasources | jq '.[] | {name, uid, type, url}'
```

В UI: `http://127.0.0.1:13000` → вход → **Dashboards** → папка **Camunda** → дашборды **Zeebe** и **Data Layer** (datasource в переменных — **Prometheus**, uid `camunda-prometheus`).
