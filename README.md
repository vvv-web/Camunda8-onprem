# Camunda 8 Self-Managed - Docker Compose

## Документация проекта

| Файл | Описание |
|------|----------|
| `PROJECT_INFO.md` | Обзор, статус, сервисы, URL, тест на ноуте |
| `ACCESS_FOR_TEAM.md` | Доступ коллегам по LAN и через Tailscale |
| `DEPLOY_STEPS.md` | Команды развёртывания и проверки |
| `FIXES_APPLIED.md` | Исправления (в т.ч. Keycloak sslRequired, ошибки One-Click скрипта) |
| `PITFALLS_AND_BEST_PRACTICES.md` | Риски и рекомендации |
| `scripts/validate-config.sh` | Локальная проверка compose, `.env` и URL-консистентности |

## One-Click для Windows (Tailscale + Camunda)

Архив `Camunda-OneClick-Windows-AutoInstall.zip` — на Desktop (`/home/cpz_ai/Desktop/`).  
Содержит: `camunda-windows-oneclick-fullauto.ps1`, `START_CAMUNDA.cmd`.  
Распаковать, запустить `START_CAMUNDA.cmd` — устанавливает Tailscale, подключает к tailnet, открывает Operate/Tasklist. Логин: demo/demo.

## Локальная валидация перед пушем

1. Скопировать `.env.example` в `.env` и заполнить рабочими значениями.
2. Запустить `./scripts/validate-config.sh`.
3. Убедиться, что в отчёте нет строк `[FAIL]`.

## Usage

For end user usage, please check the official documentation of [Camunda 8 Self-Managed Docker Compose](https://docs.camunda.io/docs/next/self-managed/quickstart/developer-quickstart/docker-compose/).
