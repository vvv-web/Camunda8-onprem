# Camunda 8 Self-Managed - Docker Compose

## Документация проекта

| Файл | Описание |
|------|----------|
| `PROJECT_INFO.md` | Обзор, статус, сервисы, URL, тест на ноуте, публичный домен |
| `ACCESS_FOR_TEAM.md` | Доступ коллегам через публичный домен и admin-доступ |
| `DEPLOY_STEPS.md` | Команды развёртывания и проверки |
| `FIXES_APPLIED.md` | Исправления (в т.ч. Keycloak sslRequired, ошибки One-Click скрипта) |
| `PITFALLS_AND_BEST_PRACTICES.md` | Риски и рекомендации |
| `scripts/validate-config.sh` | Локальная проверка compose, `.env` и URL-консистентности |
| `scripts/apply-nginx-console-optimize.sh` | Применение маршрутов /console и /optimize на VPS nginx |
| `MAINTAIN_PUBLIC_ACCESS.md` | Как не ломать публичные ссылки: nginx, Keycloak, проверки |
| `scripts/fix-keycloak-enable-clients.sh` | Включить OIDC-клиентов при «Client disabled» |
| `PRESENTATION_TEST_PLAN.md` | План тестирования для визуальной презентации (хранение, Call Activity, Embedded Subprocess, версии, Optimize) |
| `scripts/deploy-demo.sh` | Деплой демо-процессов для презентации |

## Основной доступ для команды

Основной пользовательский вход:

- `https://camunda.acom-offer-desk.ru/operate`
- `https://camunda.acom-offer-desk.ru/tasklist`

Keycloak admin для создания пользователей:

- `https://camunda.acom-offer-desk.ru/auth/admin/`

## One-Click для Windows (Tailscale + Camunda)

Архив `Camunda-OneClick-Windows-AutoInstall.zip` — на Desktop (`/home/cpz_ai/Desktop/`).  
Содержит: `camunda-windows-oneclick-fullauto.ps1`, `START_CAMUNDA.cmd`.  
Сейчас рассматривается как запасной/служебный способ доступа. Основной пользовательский доступ переведён на публичный домен через VPS.

## Локальная валидация перед пушем

1. Скопировать `.env.example` в `.env` и заполнить рабочими значениями.
2. Запустить `./scripts/validate-config.sh`.
3. Убедиться, что в отчёте нет строк `[FAIL]`.

## Usage

For end user usage, please check the official documentation of [Camunda 8 Self-Managed Docker Compose](https://docs.camunda.io/docs/next/self-managed/quickstart/developer-quickstart/docker-compose/).
