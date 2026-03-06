# Пошаговые команды развёртывания Camunda 8

## Подготовка

1. Проверить порты:
   ```bash
   ss -tlnp | grep -E '8088|8083|9200|26500|9300|18080|5432'
   ```

2. Убедиться, что Docker и Docker Compose установлены:
   ```bash
   docker --version
   docker compose version
   ```

## Развёртывание (уже выполнено)

```bash
cd /home/cpz_ai/Desktop/Camunda8-onprem

# Запуск full-конфига (Operate, Tasklist, Optimize, Keycloak, Identity)
docker compose -f docker-compose-full.yaml up -d

# Ожидание ~3–5 минут. Проверка логов:
docker compose -f docker-compose-full.yaml logs -f
```

## Проверка

```bash
# Статус контейнеров
docker compose -f docker-compose-full.yaml ps

# Проверка доступности
curl -s -o /dev/null -w "%{http_code}" http://localhost:8088/operate   # 401 = OK (нужен логин)
curl -s -o /dev/null -w "%{http_code}" http://localhost:8088/tasklist
curl -s -o /dev/null -w "%{http_code}" http://localhost:8083
```

Если в терминале настроены proxy переменные и `curl` возвращает `502`, проверить без proxy:

```bash
env -u http_proxy -u https_proxy -u all_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8088/operate
```

Если встроенный браузер Cursor даёт `502`, запускать Cursor без proxy:

```bash
cursor --no-proxy-server
```

## Локальная валидация конфигов

```bash
cd /home/cpz_ai/Desktop/Camunda8-onprem
cp .env.example .env   # если рабочего .env ещё нет
./scripts/validate-config.sh
```

Скрипт:
- проверяет обязательные переменные в `.env`
- прогоняет `docker compose config -q` для всех compose-файлов
- сверяет, что `HOST` и `KEYCLOAK_HOST` параметризуют URL в Identity и Orchestration
- завершает работу с кодом `1`, если найдены ошибки `[FAIL]`

## Остановка

```bash
docker compose -f docker-compose-full.yaml down

# С удалением данных (volumes):
docker compose -f docker-compose-full.yaml down -v
```

## Конфигурация

- **.env** — переменные окружения (HOST, KEYCLOAK_HOST, секреты)
- **HOST=10.16.66.48** — для доступа по LAN
- **HOST=100.69.139.22** — для доступа через Tailscale (с ноутов)
- **KEYCLOAK_HOST=keycloak** — для связи между контейнерами

При смене HOST пересоздать: `docker compose -f docker-compose-full.yaml up -d --force-recreate keycloak identity orchestration`
