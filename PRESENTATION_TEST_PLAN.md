# План тестирования для визуальной презентации

Демонстрация возможностей Camunda 8: хранение процессов, вложенные процессы, декомпозиция, версионирование, Optimize.

---

## Подготовка (перед презентацией)

1. Убедиться, что Camunda запущена: `docker compose -f docker-compose-full.yaml up -d`
2. Открыть в браузере: https://camunda.acom-offer-desk.ru/operate
3. Войти: `demo` / `demo`
4. Установить **Desktop Modeler**: https://camunda.com/download/modeler/
5. В Modeler: подключиться к `http://10.16.66.48:8088` (или `https://camunda.acom-offer-desk.ru`), Auth: None

---

## Сценарий 1: Хранение процессов

**Цель:** Показать, что процессы сохраняются после деплоя и видны в Operate.

### Шаги

1. Открыть **Operate** → вкладка **Processes**
2. Показать список развёрнутых процессов (если есть — e.g. E2E Smoke User Task)
3. В **Desktop Modeler**: открыть `e2e-smoke-user-task.bpmn` → Deploy
4. Вернуться в Operate → Processes — процесс появился / обновился
5. Запустить инстанс: Operate → Processes → выбрать процесс → Start instance
6. Показать вкладку **Dashboard** — счётчик "Running Process Instances"

**Что сказать:** «Процессы хранятся в Zeebe/Elasticsearch, версионируются автоматически, видны в Operate».

---

## Сценарий 2: Вложенные процессы — Call Activity (декомпозиция)

**Цель:** Показать вызов дочернего процесса из родительского.

### Шаги

1. **Деплой дочернего процесса** (сначала!):
   - Desktop Modeler: открыть `demo/child-approval.bpmn`
   - Deploy
   - Проверить в Operate — процесс `child_approval` появился

2. **Деплой родительского процесса**:
   - Desktop Modeler: открыть `demo/parent-with-call-activity.bpmn`
   - Deploy
   - Проверить в Operate — процесс `parent_order_process` появился

3. **Запуск**:
   - Operate → Processes → `Parent Order Process` → Start instance
   - В Operate → Dashboard: будут **2** running instances (родитель + дочерний)
   - Открыть оба инстанса — показать иерархию (parent вызывает child)

4. **Tasklist** (если есть User Task в дочернем):
   - https://camunda.acom-offer-desk.ru/tasklist
   - Выполнить задачу → процесс завершится

**Что сказать:** «Call Activity — декомпозиция: родительский процесс вызывает дочерний. Дочерний — отдельный BPMN, переиспользуемый».

---

## Сценарий 3: Embedded Subprocess (свёрнутый подпроцесс)

**Цель:** Показать подпроцесс внутри одного процесса, возможность сворачивания.

### Шаги

1. Desktop Modeler: открыть `demo/process-with-embedded-subprocess.bpmn`
2. Показать в Modeler: внутри процесса есть **свёрнутый** подпроцесс (прямоугольник с плюсом)
3. Развернуть подпроцесс (двойной клик) — показать внутренние шаги
4. Свернуть обратно — «упрощённый вид для верхнего уровня»
5. Deploy
6. Operate → Processes → Start instance
7. Показать в Operate диаграмму — видно, что инстанс «вошёл» в подпроцесс

**Что сказать:** «Embedded Subprocess — группировка шагов внутри процесса. Можно сворачивать для многоуровневой иерархии».

---

## Сценарий 4: Версионирование

**Цель:** Показать, что при повторном деплое создаётся новая версия.

### Шаги

1. Operate → Processes → выбрать любой процесс
2. Показать колонку **Version** — например, 1, 2
3. В Desktop Modeler: изменить имя процесса (или добавить пустой элемент) → Save → Deploy
4. Operate → Processes — появилась версия 2
5. Показать: старые инстансы продолжают идти по версии 1, новые — по версии 2

**Что сказать:** «Каждый деплой создаёт новую версию. Можно привязывать Call Activity к конкретной версии через versionTag».

---

## Сценарий 5: Optimize — аналитика и группировка

**Цель:** Показать Collections и метрики.

### Шаги

1. Открыть **Optimize**: https://camunda.acom-offer-desk.ru:8083 (или через маршрут в nginx, если настроен)
   - Либо: `http://10.16.66.48:8083` (если из офиса)
2. Войти: `demo` / `demo`
3. **Collections:** создать коллекцию «Демо-процессы», добавить туда 2–3 процесса
4. **Dashboards:** открыть дашборд с метриками (если есть)
5. **Reports:** показать отчёт по процессам (instances, duration)

**Что сказать:** «Optimize — аналитика, Collections для группировки процессов, дашборды по метрикам».

---

## Чек-лист перед показом

- [ ] Camunda запущена
- [ ] Operate открывается, логин работает
- [ ] Desktop Modeler установлен, подключён к Zeebe
- [ ] Файлы `demo/*.bpmn` разложены в папке
- [ ] Optimize доступна (порт 8083)

---

## Файлы для демо

| Файл | Описание |
|------|----------|
| `e2e-smoke-user-task.bpmn` | Простой процесс (Start → User Task → End) |
| `demo/child-approval.bpmn` | Дочерний процесс для Call Activity |
| `demo/parent-with-call-activity.bpmn` | Родитель с Call Activity → child_approval |
| `demo/process-with-embedded-subprocess.bpmn` | Процесс с Embedded Subprocess |

---

## Альтернатива: деплой через скрипт

```bash
chmod +x scripts/deploy-demo.sh
./scripts/deploy-demo.sh
```

Скрипт деплоит все три демо-процесса (child, parent с Call Activity, process с Embedded Subprocess). Запускать с pop-os, где работает Camunda.

## Альтернатива: деплой через REST API (вручную)

Если Desktop Modeler недоступен, использовать curl (см. FIXES_APPLIED.md):

```bash
# 1. Токен
TOKEN=$(curl -s -X POST "http://127.0.0.1:18080/auth/realms/camunda-platform/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=orchestration&client_secret=secret&grant_type=client_credentials" | jq -r '.access_token')

# 2. Деплой (сначала child, потом parent)
curl -s -X POST "http://127.0.0.1:8088/v2/deployments" \
  -H "Authorization: Bearer $TOKEN" \
  -F "resources=@demo/child-approval.bpmn"

curl -s -X POST "http://127.0.0.1:8088/v2/deployments" \
  -H "Authorization: Bearer $TOKEN" \
  -F "resources=@demo/parent-with-call-activity.bpmn" \
  -F "resources=@demo/child-approval.bpmn"
```

---

## Ссылки

- Operate: https://camunda.acom-offer-desk.ru/operate
- Tasklist: https://camunda.acom-offer-desk.ru/tasklist
- Optimize: http://10.16.66.48:8083 (из офиса) или https://camunda.acom-offer-desk.ru/optimize (если настроен nginx)
- docs.camunda.io — иконка ? в Operate
