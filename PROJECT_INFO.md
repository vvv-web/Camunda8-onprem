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

---

## Сервисы (корпоративный сервер, развёрнуты)

Zeebe, Operate, Tasklist, Keycloak, Identity, Elasticsearch, Console, Optimize, Connectors, Web Modeler, Postgres, Mailpit.

## Статус

- [x] Подготовка окружения (Docker, порты)
- [x] Развёртывание Camunda 8 (docker-compose-full)
- [x] Operate, Tasklist, Optimize доступны
- [x] Доступ пользователям через `https://camunda.acom-offer-desk.ru`
- [x] Keycloak admin доступен через `https://camunda.acom-offer-desk.ru/auth/admin/`
- [x] Web Modeler доступен через `https://camunda.acom-offer-desk.ru/modeler`
- [x] Внутренний маршрут VPS -> Tailscale -> pop-os работает
- [x] Старый Tailscale-сценарий сохранён как резервный/служебный
- [ ] Загрузка/создание BPMN-процессов
- [ ] Приёмка до 27.03.2026

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
