# Доступ к Camunda 8 для сотрудников модуля «Цифровизация проектных задач УЭ»

## Ссылки (офисная LAN)

| Компонент            | URL                                |
| -------------------- | ---------------------------------- |
| **Operate** (мониторинг процессов) | http://10.16.66.48:8088/operate  |
| **Tasklist** (задачи) | http://10.16.66.48:8088/tasklist |
| **Optimize** (аналитика) | http://10.16.66.48:8083          |
| REST API             | http://10.16.66.48:8088/v2        |
| Console              | http://10.16.66.48:8087            |

**Важно:** Доступ только из офисной сети 10.16.x.

**Доступ с ноутов через Tailscale (Wi‑Fi Alabuga и др.):**  
Скачать архив `Camunda-OneClick-Windows-AutoInstall.zip` с Desktop сервера, извлечь, запустить `START_CAMUNDA.cmd`. После установки Tailscale и входа в tailnet откроются `http://100.69.139.22:8088/operate` и `.../tasklist`. Логин: demo / demo.

**Примечание для Camunda 8.8:** URL `.../tasklist` может открывать unified UI (Operate) — это допустимое поведение orchestration cluster.

---

## Вход в систему

- **Логин:** `demo`
- **Пароль:** `demo`

Рекомендуется сменить пароль после первого входа (через Identity или Keycloak).

---

## Краткое описание

| Компонент | Назначение |
|-----------|------------|
| **Operate** | Просмотр запущенных процессов, инцидентов, переменных |
| **Tasklist** | Выполнение пользовательских задач (User Tasks) |
| **Optimize** | Аналитика процессов: метрики, дашборды, отчёты |
| **Console** | Администрирование, настройки |

---

## Моделирование BPMN

Для отрисовки процессов используйте **Desktop Modeler** (не Web Modeler):

- Скачать: https://camunda.com/download/modeler/
- Лицензия: MIT, бесплатно
- Подключение к Zeebe: `http://10.16.66.48:8088` (порт 26500), Auth: None

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
