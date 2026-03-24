# Проект: Camunda 8 On-Prem для модуля «Цифровизация проектных задач УЭ»

**Цель:** Внедрение и развёртывание on-prem Camunda 8 для:
- систематизации, анализа и хранения иерархического списка бизнес-процессов
- отрисовки и визуализации процессов для сотрудников модуля

**Срок:** до 27.03.2026  
**Утверждено:** непосредственным руководителем

---

## Инфраструктура

| Параметр | Значение |
|----------|----------|
| Хост | pop-os |
| Доступ | Корпоративный сервер + публичный вход через VPS-домен |
| RAM | 62 GB (~40 free) |
| CPU | 24 ядра |
| Диск | 1.4 TB free |
| Порты Camunda | 9090, 9091, 9092, 26500, 9200 |
| Мониторинг (локально) | 127.0.0.1:19090 (Prometheus), 127.0.0.1:13000 (Grafana), профиль `monitoring` |

---

## Сервисы (корпоративный сервер, развёрнуты)

Zeebe, Operate, Tasklist, Keycloak, Identity, Elasticsearch, Console, Optimize, Connectors, Web Modeler, Postgres, Mailpit.

**Мониторинг (опционально, профиль Docker Compose `monitoring`):** Prometheus + Grafana, scrape метрик с orchestration и connectors; UI только на **127.0.0.1** (порты **19090** / **13000**). Подробно: [`MONITORING.md`](MONITORING.md).

## Статус

- [x] Подготовка окружения (Docker, порты)
- [x] Развёртывание Camunda 8 (docker-compose-full)
- [x] Operate, Tasklist, Optimize доступны
- [x] Доступ пользователям через `https://camunda.acom-offer-desk.ru`
- [x] Keycloak admin доступен через `https://camunda.acom-offer-desk.ru/auth/admin/`
- [x] Web Modeler доступен через `https://camunda.acom-offer-desk.ru/modeler`
- [x] Внутренний маршрут VPS -> Tailscale -> pop-os работает
- [x] Старый Tailscale-сценарий сохранён как резервный/служебный
- [x] Стек мониторинга Prometheus + Grafana (профиль `monitoring`, см. `MONITORING.md`)
- [x] Автоматизированные E2E (Playwright): `tests/*.spec.ts` — логины Operate, Tasklist, Web Modeler, Console, Optimize (см. `DEPLOY_STEPS_TEST_CHECKLIST.md`, `npm test` в каталоге `tests/`)
- [x] Smoke / E2E сценарий Camunda: деплой `e2e-smoke-user-task.bpmn`, инстанс в Operate, REST API v2, Call Activity / Embedded Subprocess — см. `READY_FOR_SUPERVISOR_TEST.md`, `FIXES_APPLIED.md`
- [x] Ручные проверки по домену (скрины, UI): `SCREENSHOT_REPORT.md`
- [ ] Полное наполнение **реальными** BPMN модуля ЦПЗ / иерархия процессов УЭ (не путать с демо-smoke)
- [ ] Прикладная приёмка сотрудниками УЭ на своих процессах; формальное закрытие цели до 27.03.2026

## Тест на ноуте (отдельный от корпоративного ПК)

Сценарий: установка Tailscale на ноут коллеги → запуск `START_CAMUNDA.cmd` из архива → вход в Camunda под demo/demo.  
**Результат:** Camunda успешно развёрнута и доступна с ноута (это отдельный тест, не на корпоративном ПК).

## URL (фактические)

| Компонент | URL |
|-----------|-----|
| Operate | https://camunda.acom-offer-desk.ru/operate |
| Tasklist | https://camunda.acom-offer-desk.ru/tasklist |
| Web Modeler | https://camunda.acom-offer-desk.ru/modeler |
| Keycloak admin | https://camunda.acom-offer-desk.ru/auth/admin/ |
| REST API | https://camunda.acom-offer-desk.ru/v2 |
| Внутренний upstream | http://100.69.139.22:8088 |

## Web Modeler - статус

- Публичный маршрут через VPS настроен
- Browser smoke-test пройден: открывается `Home`, работает создание нового проекта
- Подробности интеграции и список ошибок/исправлений: `FIXES_APPLIED.md`

---

## Репозиторий Git (актуально)

- **Remote:** `github.com/vvv-web/Camunda8-onprem`, ветка **`main`**.
- **Что в истории `main` (смотреть `git log -20 --oneline`):** стабилизация публичного доступа; пользователь **Rastaturin_Oleg** и кластерный id **`rastaturin_oleg`** (детали в `ACCESS_FOR_TEAM.md`); опциональный стек **мониторинга** (профиль `monitoring`, `MONITORING.md`); правки `docker-compose-full.yaml`, `validate-config.sh`, `.env.example`.
