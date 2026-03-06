# Camunda 8 — подводные камни и best practices

---

## Критичные риски

### 1. Диск и Elasticsearch

- **Проблема:** Elasticsearch требует ≥20% свободного места. При нехватке — падает при старте и может не запуститься после освобождения места.
- **Источник:** GitHub #41726
- **Решение:** Держать ≥20% свободного места; при сбое — удалить lock-файлы или переустановить.

### 2. Exporter без продвижения

- **Проблема:** Если exporter не двигает read position (например, Debug Exporter), event log Zeebe растёт бесконечно → диск переполняется.
- **Решение:** Не использовать «мёртвые» exporters; мониторить доступность Elasticsearch для exporter-а.

### 3. Конфликт портов

- **Проблема:** 8080/8081 часто заняты → Camunda не стартует.
- **Решение:** Свои порты (на pop-os: 9090, 9091, 9092).

### 4. Неверная версия Java

- **Проблема:** Camunda 8 Run требует OpenJDK 21–23.
- **Решение:** Проверить `java -version` и `JAVA_HOME`.

### 5. Camunda 8.8 — Bitnami

- **Проблема:** Bitnami subcharts (PostgreSQL, Elasticsearch, Keycloak) отключены по умолчанию.
- **Решение:** Разворачивать инфраструктуру отдельно (официальный ES, Keycloak, PostgreSQL).

### 6. Keycloak и SSL

- **Проблема:** Keycloak требует SSL для «внешних» запросов; неверный `redirectUrl` при HTTP→HTTPS редиректе.
- **Решение:** Совпадение `redirectUrl` с реальным HTTPS URL; проверить whitelist IP Keycloak.

### 7. Production и Docker Compose

- **Проблема:** Docker Compose — только для dev, не для production.
- **Решение:** Production — Kubernetes + Helm или manual install.

---

## Best practices

1. **Диск:** ≥20% свободного + 50–100 GB под Camunda.
2. **Версии:** Все компоненты из одной мажорной/минорной ветки.
3. **Мониторинг:** Следить за Elasticsearch и exporter.
4. **Резервирование:** Бэкапы Zeebe и Elasticsearch отдельно.
5. **Метрики:** Задать целевые PI/сек, задачи/сек, латентность.
6. **Upgrade:** Только последний patch 8.7.x → 8.8.y.

---

## Совместимость (кратко)

| Компонент | Версия |
|-----------|--------|
| Java (C8Run) | 21–23 |
| Elasticsearch | 7.x, 8.x |
| Camunda 8.8 | Один общий Elasticsearch |
| Upgrade path | 8.7.x → 8.8.y только |
