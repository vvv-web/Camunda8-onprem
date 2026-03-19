# Чеклист тестов для каждого шага развёртывания

**Цель:** обязательная проверка после каждого шага (DoD). Не переходить к следующему шагу без зелёных проверок.

**Источники:** [NGINX Reverse Proxy](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/), [Camunda Console Configuration](https://docs.camunda.io/docs/self-managed/console-deployment/configuration), `docker-compose-full.yaml`.

---

## Шаг 1: Подготовка (порты и Docker)

### Тесты
```bash
# Порт 8088 (orchestration), 8083 (optimize), 8087 (console)
ss -tlnp | grep -E '8088|8083|8087|9200|26500|9300|18080'

# Docker и Compose
docker --version && docker compose version
```

### Критерий успеха
- Docker и Compose установлены, версии выводятся
- Порты свободны или уже заняты контейнерами Camunda

---

## Шаг 2: Запуск compose

### Команда
```bash
cd /home/cpz_ai/Desktop/Camunda8-onprem
docker compose -f docker-compose-full.yaml up -d
```

### Тесты
```bash
# Все контейнеры в состоянии Up
docker compose -f docker-compose-full.yaml ps

# Локальная доступность
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8088/operate   # 401 OK
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8088/tasklist # 401 OK
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8083/         # 302 или 200
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8087/         # 302 или 200
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8070/        # Web Modeler
```

### Критерий успеха
- Все сервисы `Up`
- HTTP коды: 401 (требует логин), 302 (редирект), 200 — допустимы; 404/502 — провал

---

## Шаг 3: Валидация конфигов (перед любыми изменениями)

### Команда
```bash
./scripts/validate-config.sh
```

### Тест
```bash
./scripts/validate-config.sh; echo "Exit: $?"
```

### Критерий успеха
- Exit code 0
- Нет строк `[FAIL]`

---

## Шаг 4: Playwright E2E (локальный доступ)

### Команда
```bash
cd tests
npm ci
npx playwright test
```

### Критерий успеха
- Все тесты проходят (console_login, optimize_login, operate_login, tasklist_login, web_modeler_login)

---

## Шаг 5: Публичный доступ (DNS + VPS nginx)

### Тесты (с pop-os или машины с доступом в интернет)
```bash
# DNS
dig +short camunda.acom-offer-desk.ru
# Ожидается: 155.212.160.162

# HTTPS
curl -sI https://camunda.acom-offer-desk.ru/operate   # 401 или 302
curl -sI https://camunda.acom-offer-desk.ru/auth/    # 200 или 302
curl -sI https://camunda.acom-offer-desk.ru/modeler   # 200 или 302
curl -sI https://camunda.acom-offer-desk.ru/console/ # НЕ 404
curl -sI https://camunda.acom-offer-desk.ru/optimize/# НЕ 404
```

### Критерий успеха
- DNS → 155.212.160.162
- `/console/` и `/optimize/` — 302 или 200 (не 404)

---

## Шаг 6: Применение nginx (Console + Optimize) на VPS

### Команды (см. VPS_ACCESS.md)
```bash
scp -r /home/cpz_ai/Desktop/Camunda8-onprem/scripts root@155.212.160.162:/tmp/camunda-scripts
ssh root@155.212.160.162 'sudo bash /tmp/camunda-scripts/apply-nginx-console-optimize.sh'
```

### Тесты после скрипта
```bash
# На VPS
nginx -t
curl -sI https://camunda.acom-offer-desk.ru/console/
curl -sI https://camunda.acom-offer-desk.ru/optimize/
```

### Критерий успеха
- `nginx -t` — syntax is ok
- `/console/` и `/optimize/` — 302 или 200 (не 404)

---

## Сводка DoD по шагам

| Шаг | Тест | Ожидание |
|-----|------|----------|
| 1 | ss + docker version | Порты видны, Docker установлен |
| 2 | curl localhost:8088,8083,8087 | 401/302/200 |
| 3 | validate-config.sh | Exit 0 |
| 4 | playwright test | Все тесты passed |
| 5 | curl https://camunda.../operate,auth,modeler | 401/200/302 |
| 6 | curl https://camunda.../console/,/optimize/ | 302/200 |

---

**Официальные источники:**
- NGINX: https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/
- Camunda Console: https://docs.camunda.io/docs/self-managed/console-deployment/configuration
- Camunda Optimize: https://docs.camunda.io/docs/self-managed/optimize-deployment/configuration/system-configuration
