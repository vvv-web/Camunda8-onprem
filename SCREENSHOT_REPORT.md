# Camunda 8 — скрин-отчёт (igor_bolshakov)

**Дата:** 2026-03-19  
**Пользователь:** igor_bolshakov (ibolshakov@alabuga.ru) / Большаков Игорь Александрович (№0118)  
**Пароль:** IBolshakov

---

## Статус компонентов по скринам

| Компонент | URL | Статус | Примечание |
|-----------|-----|--------|------------|
| **Operate** | https://camunda.acom-offer-desk.ru/operate | ✅ Работает | 2 инстанса с incidents (известная проблема Multi-instance) |
| **Tasklist** | https://camunda.acom-offer-desk.ru/tasklist | ✅ Работает | Welcome to Tasklist |
| **Web Modeler** | https://camunda.acom-offer-desk.ru/modeler | ✅ Работает | Igor Bolshakov залогинен |
| **Console** | https://camunda.acom-offer-desk.ru/console/ | ❌ Пустая страница | Требуется fix redirect_uri |
| **Optimize** | https://camunda.acom-offer-desk.ru/optimize/ | ❌ Invalid redirect_uri | Требуется fix в Keycloak |
| **Keycloak Admin** | https://camunda.acom-offer-desk.ru/auth/admin/ | ⚠️ Permission denied | Ожидаемо: igor — не admin, только обычный пользователь |

---

## Выявленные проблемы

### 1. Invalid parameter: redirect_uri (Optimize, др.)
**Скрин:** Log in to… → «We are sorry… Invalid parameter: redirect_uri»

**Причина:** В Keycloak для клиентов `optimize` и `console` указаны redirect URI для localhost, в Keycloak нет публичных URI для https://camunda.acom-offer-desk.ru.

**Решение:** Обновить Valid Redirect URIs в Keycloak (скрипт `scripts/fix-keycloak-redirect-uris.sh`).

### 2. Console — пустая страница
**Скрин:** https://camunda.acom-offer-desk.ru/console/ — белый экран

**Причина:** Тот же сценарий: неверный redirect_uri или base URL. Console и Optimize в `.identity/application.yaml` имели root-url для localhost.

**Решение:** Изменён root-url в `.identity/application.yaml` и скрипт обновления Keycloak.

### 3. Permission denied в Keycloak Admin
**Скрин:** /auth/admin/master/console/ → «You do not have permission»

**Причина:** igor_bolshakov — обычный пользователь Camunda, не администратор Keycloak. Admin Console доступен только realm admin.

**Решение:** Не требуется. Для админки Keycloak используется отдельный admin-аккаунт.

---

## Исправления внесены

1. **.identity/application.yaml**
   - Console: `root-url: "https://${HOST}/console"`
   - Optimize: `root-url: "https://${HOST}/optimize"`

2. ** scripts/fix-keycloak-redirect-uris.sh**
   - Обновляет Valid Redirect URIs для `optimize` и `console` в Keycloak.

---

## Применение исправлений

На pop-os (где запущен Camunda):

```bash
cd /home/cpz_ai/Desktop/Camunda8-onprem

# 1. Обновить redirect URI в Keycloak
./scripts/fix-keycloak-redirect-uris.sh

# 2. Пересоздать identity (чтобы конфиг Identity совпадал с Keycloak)
docker compose -f docker-compose-full.yaml up -d --force-recreate identity
```

---

## Ссылки для igor_bolshakov

| Компонент | Ссылка |
|-----------|--------|
| Operate | https://camunda.acom-offer-desk.ru/operate |
| Tasklist | https://camunda.acom-offer-desk.ru/tasklist |
| Console | https://camunda.acom-offer-desk.ru/console/ |
| Optimize | https://camunda.acom-offer-desk.ru/optimize/ |
| Web Modeler | https://camunda.acom-offer-desk.ru/modeler |

**Логин:** igor_bolshakov | **Пароль:** IBolshakov
