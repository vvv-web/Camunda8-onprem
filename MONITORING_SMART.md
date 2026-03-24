# Итог работ по мониторингу Camunda (формулировка SMART)

Ниже — что сделано по критериям **SMART** (конкретно, измеримо, достижимо, релевантно, ограничено по времени/контексту).

---

## S — Specific (конкретно)

- Развёрнут **наблюдаемый контур** в том же Docker Compose-проекте, что и Camunda 8:
  - **Prometheus** — опрос метрик по HTTP с сервисов **orchestration** (порт 9600, путь `/actuator/prometheus`) и **connectors** (порт 8080).
  - **Grafana** — источник данных Prometheus, автозагрузка официальных дашбордов Camunda **Zeebe** и **Data Layer** (ветка `stable/8.8`), папка в UI **Camunda**.
- Сервисы мониторинга включены **только** через профиль Compose **`monitoring`** — обычный `docker compose up` без профиля **не** поднимает Prometheus/Grafana и **не** меняет Nginx, Keycloak и публичные URL.
- Документированы: шаги с официальными ссылками (`MONITORING.md`), приоритет панелей (`MONITORING_DASHBOARD_PRIORITY.md`), проверки после запуска, скрипт обновления JSON дашбордов с GitHub.

---

## M — Measurable (измеримо)

- **Prometheus:** цели scrape в состоянии **UP** для jobs `camunda-orchestration` и `camunda-connectors` (проверка: `GET http://127.0.0.1:19090/api/v1/targets` или UI **Status → Targets**).
- **Grafana:** `GET /api/health` возвращает **200**; в `GET /api/datasources` есть Prometheus с **uid** `camunda-prometheus` и URL `http://prometheus:9090`.
- **UI:** в Grafana доступны минимум **два** provisioned-дашборда с UID `camunda-zeebe-official` и `camunda-data-layer-official`.
- **Валидация репозитория:** `scripts/validate-config.sh` проверяет наличие `monitoring/prometheus.yml` и файлов дашбордов в `monitoring/grafana/provisioning/dashboards/json/`.

---

## A — Achievable / Assignable (достижимо и понятно ответственным)

- Запуск на хосте с уже работающим стеком: одна команда  
  `docker compose -f docker-compose-full.yaml --profile monitoring up -d`.
- Версии образов задаются в `.env` / дефолтах в compose (Prometheus, Grafana **12.0.2**); обновление официальных JSON — `./scripts/fetch-camunda-grafana-dashboards.sh`.
- Доступ к UI **только с localhost** (127.0.0.1:19090 и :13000) — не требует немедленной настройки reverse-proxy для команды.

---

## R — Relevant (релевантно целям проекта)

- Соответствует **on-prem Camunda 8** и официальной доке [Camunda components metrics](https://docs.camunda.io/docs/self-managed/operational-guides/monitoring/metrics/): polling Prometheus, готовые дашборды Grafana.
- Поддерживает эксплуатацию: здоровье Zeebe, backpressure, throughput, data layer / exporter без смешивания с публичным доступом пользователей к Operate/Tasklist.

---

## T — Time-bound (привязка во времени)

- Работа **завершена** в рамках итерации разработки репозитория: конфиги и документация закоммичены; проверка «поднять профиль + health/targets + вход в Grafana» выполняется **за минуты** после деплоя.
- Для отчёта по срокам проекта (например, приёмка до 27.03.2026) пункт зафиксирован в `PROJECT_INFO.md` как выполненный: стек мониторинга (профиль `monitoring`).

---

## Краткая формулировка одной строкой (для слайда/письма)

> **S:** Prometheus + Grafana в профиле `monitoring`, scrape orchestration и connectors. **M:** targets UP, Grafana health 200, два официальных дашборда. **A:** одна команда compose, документация и скрипт обновления дашбордов. **R:** официальные метрики Camunda 8.8, без вмешательства в публичный доступ. **T:** готово к использованию; статус отражён в `PROJECT_INFO.md`.
