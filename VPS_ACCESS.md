# Доступ к VPS Camunda (155.212.160.162)

## SSH

**IP:** 155.212.160.162  
**Hostname:** zvezda.smerti148.fvds.ru  
**Пользователь:** `root` (по планам и истории развёртывания)

### Подключение
```bash
ssh root@155.212.160.162
```

### Рекомендуемый SSH host (добавить в `~/.ssh/config`)

```
Host camunda-vps
    HostName 155.212.160.162
    User root
    # IdentityFile ~/.ssh/id_ed25519   # если есть ключ
```

После добавления:
```bash
ssh camunda-vps
```

---

## Применение nginx для Console и Optimize

С pop-os (или другой машины с SSH-доступом к VPS):

```bash
scp -r /home/cpz_ai/Desktop/Camunda8-onprem/scripts root@155.212.160.162:/tmp/camunda-scripts
ssh root@155.212.160.162 'sudo bash /tmp/camunda-scripts/apply-nginx-console-optimize.sh'
```

**Upstream:** 100.69.139.22 (Tailscale IP pop-os). Переопределить:
```bash
CAMUNDA_UPSTREAM=100.69.139.22 ssh root@155.212.160.162 'sudo bash /tmp/camunda-scripts/apply-nginx-console-optimize.sh'
```

---

## Plugin-Orchestrator Handoff (контекст)

```text
Goal: Применить nginx для /console и /optimize на VPS, проверить доступ
Constraints: Не трогать проект, следовать офф. доке, тесты обязательны
Already checked: apply-nginx-console-optimize.sh, NGINX_CONSOLE_OPTIMIZE_SNIPPET.conf.example
Files inspected: scripts/apply-nginx-console-optimize.sh, DEPLOY_STEPS.md, FIXES_APPLIED.md
Open questions: SSH root vs cpz_ai (cpz_ai ранее давал Permission denied)
Versions: nginx (на VPS), Camunda 8.8
Official docs: NGINX Reverse Proxy, Camunda Console Configuration
Compatibility: proxy_pass + proxy_set_header — соответствует NGINX docs
Current step: Применение скрипта на VPS
Previous: Скрипт создан, vhost ищется по camunda.acom-offer-desk.ru
Next depends on: nginx -t, reload, curl проверки
Primary workflow: docs-and-research
Secondary: framework-docs-researcher (nginx, Camunda)
Do not repeat: Не перезапускать Docker, не менять .env
```

---

## Проверка после применения

```bash
curl -sI https://camunda.acom-offer-desk.ru/console/
curl -sI https://camunda.acom-offer-desk.ru/optimize/
```

Ожидаемо: `HTTP/2 302` или `200` (не 404).
