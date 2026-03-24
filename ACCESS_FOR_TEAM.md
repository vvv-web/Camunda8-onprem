# Доступ к Camunda 8 для сотрудников модуля «Цифровизация проектных задач УЭ»

## Основные ссылки

| Компонент            | URL                                |
| -------------------- | ---------------------------------- |
| **Operate** (мониторинг процессов) | https://camunda.acom-offer-desk.ru/operate |
| **Tasklist** (задачи) | https://camunda.acom-offer-desk.ru/tasklist |
| **Web Modeler** (моделирование BPMN в браузере) | https://camunda.acom-offer-desk.ru/modeler |
| **Keycloak admin** (создание пользователей) | https://camunda.acom-offer-desk.ru/auth/admin/ |
| **Console** (администрирование, кластер) | https://camunda.acom-offer-desk.ru/console/ |
| **Optimize** (аналитика, дашборды) | https://camunda.acom-offer-desk.ru/optimize/ |
| **Identity** (пользователи, роли) | https://camunda.acom-offer-desk.ru/identity |
| REST API | https://camunda.acom-offer-desk.ru/v2 |
| **Logout (выйти из аккаунта)** | https://camunda.acom-offer-desk.ru/logout |

**Примечание:** Console и Optimize работают после применения nginx на VPS — см. `FIXES_APPLIED.md` раздел 15, скрипт `scripts/apply-nginx-console-optimize.sh`.

**Важно:** Для коллег основной доступ больше не требует Tailscale-клиента на ноуте. Публичная точка входа — VPS с доменом `camunda.acom-offer-desk.ru`, сам стек Camunda продолжает работать на корпоративном сервере.

**Внутренний маршрут (служебно):**  
`VPS -> https://camunda.acom-offer-desk.ru -> Nginx -> Tailscale 100.69.139.22 -> Camunda на pop-os`

**Резервный доступ через Tailscale:**  
Старый Tailscale-сценарий оставлен только как запасной/администраторский способ. Для обычных пользователей использовать домен.

**Примечание для Camunda 8.8:** URL `.../tasklist` может открывать unified UI (Operate) — это допустимое поведение orchestration cluster.

---

## Вход в систему

- **Логин:** `demo`
- **Пароль:** `demo`

Рекомендуется отказаться от общего `demo/demo` и создавать именные учётные записи коллег в Keycloak.

---

## Краткое описание

| Компонент | Назначение |
|-----------|------------|
| **Operate** | Просмотр запущенных процессов, инцидентов, переменных |
| **Tasklist** | Выполнение пользовательских задач (User Tasks) |
| **Optimize** | Аналитика процессов: метрики, дашборды, отчёты |
| **Console** | Администрирование, настройки |

---

## Logout (выход из аккаунта)

### Проблема

Кнопка «Logout» в Operate (и в других компонентах Camunda) **не выполняет полный выход**. При нажатии страница просто обновляется, пользователь остаётся залогиненным.

**Причина:** В Camunda 8.8 пока нет полноценной интеграции с Keycloak по OIDC RP-Initiated Logout. Это запланировано в более новых версиях ([PR #32224](https://github.com/camunda/camunda/pull/32224) отложен).

### Обходное решение

Чтобы выйти из аккаунта, откройте:

**https://camunda.acom-offer-desk.ru/logout**

(Редирект на Keycloak end_session; маршрут `/logout` добавлен в nginx через `apply-nginx-console-optimize.sh`)

Эта ссылка сбрасывает сессию в Keycloak. После неё при следующем входе в Operate, Tasklist, Console, Optimize будет предложен экран логина.

**Рекомендация:** Добавить эту ссылку в закладки или скопировать в заметки для быстрого выхода.

---

## Моделирование BPMN

Основной вариант для команды:

- **Web Modeler**: `https://camunda.acom-offer-desk.ru/modeler`
- Для доступа нужна роль `Web Modeler` или `Web Modeler Admin` в `Management Identity`

Резервный локальный вариант для администратора:

- Скачать: https://camunda.com/download/modeler/
- Лицензия: MIT, бесплатно
- Подключение к Zeebe для локального администрирования: `http://10.16.66.48:8088` (порт `26500`), Auth: None

---

## Кратко: как выдали полный доступ `alexander_kotov`

- пользователь `alexander_kotov` уже был создан в `Keycloak`

**Учётные данные:**
- **Логин:** `alexander_kotov`
- **Пароль:** `AKotov`
- в `Identity` у пользователя была подтверждена cluster-роль `admin`
- недостающие management-роли были выданы с сервера через `kcadm`, по образцу пользователя `demo`

Назначенные роли:

- `ManagementIdentity`
- `Optimize`
- `Web Modeler`
- `Web Modeler Admin`
- `Console`
- `Orchestration`

Короткая команда, которой это сделали:

```bash
docker compose -f docker-compose-full.yaml exec -T keycloak /opt/bitnami/keycloak/bin/kcadm.sh add-roles -r camunda-platform --config /tmp/kcadm.config --uid <USER_ID> --rolename ManagementIdentity --rolename Optimize --rolename "Web Modeler" --rolename "Web Modeler Admin" --rolename Console --rolename Orchestration
```

Чем проверили:

- вход под `alexander_kotov` в `https://camunda.acom-offer-desk.ru/modeler`
- открывается `Home`
- работает `Create new project`
- `Operate` и `Identity` открываются без ошибки доступа

---

## Кратко: как выдали полный доступ `igor_bolshakov`

- пользователь `igor_bolshakov` создан в `Keycloak` (realm `camunda-platform`)
- в `Identity` у пользователя подтверждена cluster-роль `admin`
- management-роли выданы через `kcadm`, по образцу `demo` и `alexander_kotov`

**Учётные данные:**
- **Логин:** `igor_bolshakov`
- **Пароль:** `IBolshakov`

---

## Кратко: пользователь Олег Растатурин (`Rastaturin_Oleg` в Keycloak)

- **Важно (Operate / кластер):** Keycloak в токене отдаёт **`preferred_username` в нижнем регистре** (`rastaturin_oleg`). Роль **`admin` в Orchestration** должна быть выдана на **этот** id, иначе в Operate будет замок при живых ролях в Keycloak. Команда: **`./scripts/grant-orchestration-cluster-admin-role.sh rastaturin_oleg`** (не смешанный регистр `Rastaturin_Oleg`). Лишнюю выдачу на `Rastaturin_Oleg` можно снять: `CAMUNDA_FORCE_REASSIGN_ROLE=1` не поможет без смены аргумента — используйте `DELETE` через тот же API или оставьте (не мешает, если рабочая роль на `rastaturin_oleg`).
- Пользователь описан в **`.identity/application.yaml`** (`keycloak.users`), тот же набор ролей, что у `demo`.
- Применение на Keycloak: перезапуск Identity — **`./scripts/apply-identity-keycloak-users.sh`** (или **`./scripts/provision-user-rastaturin-oleg.sh`** — то же самое).
- **Operate / Tasklist (роль кластера `admin`):** при `camunda.security.authorizations.enabled: true` недостаточно только Keycloak — нужна **роль `admin` в Orchestration Cluster**. Список `defaultRoles.admin.users` в **`.orchestration/application.yaml`** в основном срабатывает при **первичной** инициализации; для **уже работающего** стенда назначьте роль так:
  - **Автоматизация:** `./scripts/grant-orchestration-cluster-admin-role.sh rastaturin_oleg` (см. блок выше про JWT). Проверка: `CAMUNDA_SUBJECT_PASSWORD='…' ./scripts/diagnose-orchestration-user-access.sh Rastaturin_Oleg`.
  - Иначе в UI **Orchestration Cluster Identity** (раздел авторизаций в доке Camunda 8.8) — пользователю роль `admin`.
  - Рестарт `orchestration` после правки YAML **не гарантирует** появление прав у нового пользователя, если кластер уже был инициализирован.
- **Если в Operate всё равно «нет доступа», а API даёт 409 на выдачу `admin`:** чаще всего в JWT **`preferred_username` ≠ логин**, под которым выдана роль (Orchestration смотрит claim из `CAMUNDA_SECURITY_AUTHENTICATION_OIDC_USERNAMECLAIM`). Диагностика: **`CAMUNDA_SUBJECT_PASSWORD='…' ./scripts/diagnose-orchestration-user-access.sh Rastaturin_Oleg`**. Повторная выдача роли: **`CAMUNDA_FORCE_REASSIGN_ROLE=1 ./scripts/grant-orchestration-cluster-admin-role.sh Rastaturin_Oleg`**. Полный выход: **`https://camunda.acom-offer-desk.ru/logout`**, затем вход снова (лучше инкогнито).
- Альтернатива без правки YAML: **`CAMUNDA_NEW_USER_PASSWORD='…' ./scripts/provision-camunda-keycloak-user.sh Rastaturin_Oleg Oleg Rastaturin email@example.com`**
- В **Identity** при необходимости назначить cluster-роль **`admin`** (как у `igor_bolshakov`), если не хватает прав на Console / другие компоненты.

**Учётные данные:**
- **Логин в Keycloak (как заводили):** `Rastaturin_Oleg` (вход обычно без учёта регистра; в JWT для Camunda — **`rastaturin_oleg`**)
- **Пароль:** `ORastaturin` (рекомендуется сменить после первого входа)

---

## Шпаргалка igor_bolshakov: логин, пароль, ссылки и офф. документация

| Логин | Пароль |
|-------|--------|
| `igor_bolshakov` | `IBolshakov` |

### Ссылки и краткое описание (с офф. документацией)

| Компонент | URL | Краткое описание | Офф. документация |
|-----------|-----|------------------|-------------------|
| **Operate** | https://camunda.acom-offer-desk.ru/operate | Мониторинг и отладка процессов: просмотр активных/завершённых инстансов, инциденты, переменные, batch-операции | [Introduction to Operate](https://docs.camunda.io/docs/components/operate/operate-introduction/) |
| **Tasklist** | https://camunda.acom-offer-desk.ru/tasklist | Выполнение пользовательских задач (User Tasks): задачи назначаются пользователям при выполнении BPMN-процессов | [Introduction to Tasklist](https://docs.camunda.io/docs/components/tasklist/introduction-to-tasklist/) |
| **Console** | https://camunda.acom-offer-desk.ru/console/ | Администрирование Camunda 8: управление кластерами, доступом, настройками | [Introduction to Console](https://docs.camunda.io/docs/components/console/introduction-to-console/) |
| **Optimize** | https://camunda.acom-offer-desk.ru/optimize/ | Аналитика процессов: метрики, дашборды, отчёты для улучшения процессов | [Getting started with Optimize](https://docs.camunda.io/docs/components/optimize/improve-processes-with-optimize/) |
| **Web Modeler** | https://camunda.acom-offer-desk.ru/modeler | Моделирование BPMN в браузере: создание и редактирование диаграмм процессов | [Web Modeler](https://docs.camunda.io/docs/components/modeler/web-modeler/) |
| **Identity** | https://camunda.acom-offer-desk.ru/identity | Управление пользователями, ролями и доступом к Console, Web Modeler, Optimize | [What is Identity](https://docs.camunda.io/docs/self-managed/identity/what-is-identity/) |
| **Keycloak admin** | https://camunda.acom-offer-desk.ru/auth/admin/ | Администрирование IdP: создание пользователей, realm, клиентов | [Connect to Keycloak](https://docs.camunda.io/docs/self-managed/identity/configuration/connect-to-an-existing-keycloak) |
| **REST API** | https://camunda.acom-offer-desk.ru/v2 | API оркестрации: старт процессов, задачи, запросы | [Camunda 8 REST API Overview](https://docs.camunda.io/docs/apis-tools/camunda-api-rest/camunda-api-rest-overview) |

*Портал Camunda 8 Docs: https://docs.camunda.io*

---

Назначенные роли:

- `ManagementIdentity`
- `Optimize`
- `Web Modeler`
- `Web Modeler Admin`
- `Console`
- `Orchestration`

Короткая команда, которой это делают:

```bash
docker compose -f docker-compose-full.yaml exec -T keycloak /opt/bitnami/keycloak/bin/kcadm.sh add-roles -r camunda-platform --config /tmp/kcadm.config --uid <USER_ID> --rolename ManagementIdentity --rolename Optimize --rolename "Web Modeler" --rolename "Web Modeler Admin" --rolename Console --rolename Orchestration
```

Чем проверили:

- вход под `igor_bolshakov` в `https://camunda.acom-offer-desk.ru/optimize/`
- вход в `https://camunda.acom-offer-desk.ru/console/`
- вход в `https://camunda.acom-offer-desk.ru/modeler`
- `Operate`, `Tasklist`, `Identity` открываются без ошибки доступа

---

## Остановка и запуск (для администратора)

```bash
cd /home/cpz_ai/Desktop/Camunda8-onprem

# Запуск
docker compose -f docker-compose-full.yaml up -d

# Остановка
docker compose -f docker-compose-full.yaml down

# Логи
docker compose -f docker-compose-full.yaml logs -f
```

---

## Документация для администратора

- **FIXES_APPLIED.md** — применённые исправления, команды и конфигурация при переустановке

---

## Контакты и поддержка

При проблемах с доступом обратитесь к администратору модуля.
