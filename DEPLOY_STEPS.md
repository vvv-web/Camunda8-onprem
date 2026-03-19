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

# Запуск full-конфига (Operate, Tasklist, Optimize, Keycloak, Identity, Web Modeler)
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
curl -s -o /dev/null -w "%{http_code}" http://localhost:8070
curl -s -o /dev/null -w "%{http_code}" http://localhost:8060/up
curl -k -s -o /dev/null -w "%{http_code}" https://camunda.acom-offer-desk.ru/operate
curl -k -s -o /dev/null -w "%{http_code}" https://camunda.acom-offer-desk.ru/auth/
curl -k -s -o /dev/null -w "%{http_code}" https://camunda.acom-offer-desk.ru/modeler
curl -k -s -o /dev/null -w "%{http_code}" https://camunda.acom-offer-desk.ru/console/
curl -k -s -o /dev/null -w "%{http_code}" https://camunda.acom-offer-desk.ru/optimize/
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
- сверяет, что `HOST` и `KEYCLOAK_HOST` параметризуют URL в Identity, Orchestration и Web Modeler
- завершает работу с кодом `1`, если найдены ошибки `[FAIL]`

## Остановка

```bash
docker compose -f docker-compose-full.yaml down

# С удалением данных (volumes):
docker compose -f docker-compose-full.yaml down -v
```

## Конфигурация

- **.env** — переменные окружения (HOST, KEYCLOAK_HOST, секреты)
- **HOST=camunda.acom-offer-desk.ru** — основной browser-facing hostname через VPS
- **KEYCLOAK_HOST=keycloak** — для связи между контейнерами

При смене HOST пересоздать: `docker compose -f docker-compose-full.yaml up -d --force-recreate keycloak identity orchestration console optimize`

## Публичный доступ через VPS

1. DNS: `camunda.acom-offer-desk.ru -> 155.212.160.162`
2. На VPS отдельный `nginx` vhost для `camunda.acom-offer-desk.ru`
3. Основной proxy:
   - `/` -> `http://100.69.139.22:8088`
   - `/auth/` -> `http://100.69.139.22:18080/auth/`
   - `/modeler` -> `http://100.69.139.22:8070`
   - `/modeler-ws` -> `http://100.69.139.22:8060`
4. HTTPS: отдельный Let's Encrypt сертификат только для `camunda.acom-offer-desk.ru`
5. Для маршрутов Web Modeler использовать готовый шаблон:
   - `NGINX_WEB_MODELER_SNIPPET.conf.example`
6. Проверка:
   ```bash
   curl -I https://camunda.acom-offer-desk.ru/operate
   curl -I https://camunda.acom-offer-desk.ru/auth/
   curl -I https://camunda.acom-offer-desk.ru/modeler
   ```

## Browser smoke-check для Web Modeler

1. Открыть `https://camunda.acom-offer-desk.ru/modeler`
2. Проверить редирект на `/modeler/login` или прямое открытие домашней страницы
3. После входа убедиться, что виден экран `Modeler | Home`
4. Нажать `Create new project`
5. Убедиться, что открывается экран `Modeler | New project`

Если `/modeler` отвечает `404`:

- проверить vhost `nginx` на VPS `155.212.160.162`
- убедиться, что добавлены оба маршрута:
  - `/modeler` -> `http://100.69.139.22:8070`
  - `/modeler-ws` -> `http://100.69.139.22:8060`
- выполнить `nginx -t && systemctl reload nginx`
