# Какие дашборды и панели смотреть в первую очередь

**Маршрутизация (plugin-orchestrator):** `docs-and-research` — один primary; сводка основана на [официальном списке метрик Camunda 8.8](https://docs.camunda.io/docs/self-managed/operational-guides/monitoring/metrics/) и на структуре импортированных JSON (`Zeebe`, `Data Layer`).

У вас в Grafana по сути **два официальных дашборда** (папка **Camunda**). «Самые важные» — не отдельные файлы, а **подмножество строк и панелей** внутри них.

---

## Уровень 1 — смотреть ежедневно / при инциденте

Связь с докой Camunda: разделы *Process processing metrics*, *Performance metrics*, *Health metrics* на странице [Camunda components metrics](https://docs.camunda.io/docs/self-managed/operational-guides/monitoring/metrics/).

| Приоритет | Что мониторить (смысл) | Где в Grafana (дашборд **Zeebe**) |
|-----------|-------------------------|-----------------------------------|
| **P0** | Здоровье партиций (`zeebe_health`) | Строка **General Overview** → **Health**, **Health status timeline** |
| **P0** | Инциденты и поток: `zeebe_incident_events_total`, `zeebe_pending_incidents_total`, события элементов/джобов | **Throughput** → *Process Instance Events*, *Job events*; **General Overview** → *Completed Tasks / Processes* (косвенно нагрузка) |
| **P0** | Backpressure / отбрасывание запросов: `zeebe_dropped_request_count_total`, лимит inflight | **General Overview** → **Backpressure Dropping Requests**; строка **Backpressure** → *Total Dropped Requests*, *In flight Requests* |
| **P0** | Задержка обработки: `zeebe_stream_processor_latency_bucket` | **Latency** → **Overall Processing Latency**, *Record Processing Duration* |
| **P1** | Экспорт в ES / Camunda exporter: `zeebe_exporter_events_total` | **Throughput** → **Exported Records**; строки **Elasticsearch Exporter** / **Camunda Exporter** |
| **P1** | «Застряла» ли обработка (позиции stream / export) | **Processing** → *Last processed position*, *Last exported position*, *Number of records not processed*, *Number of records not exported* |

**Дашборд Data Layer** (второй по важности для 8.8): в доке сказано, что он даёт обзор **data layer** с упором на **Camunda exporter** ([раздел Grafana → Data layer](https://docs.camunda.io/docs/self-managed/operational-guides/monitoring/metrics/)). Смотрите в первую очередь блоки **Camunda Exporter**, **Operate Importer** / **Tasklist Importer** (пропускная способность и задержки импорта).

---

## Уровень 2 — при деградации или планировании ёмкости

| Тема | Строки в **Zeebe** |
|------|---------------------|
| Память / GC / OOM-риски | **Memory**, **General Overview** → *Process memory usage* |
| CPU / троттлинг | **CPU** |
| Диск (в K8s — PVC; в Docker часть панелей может быть неактуальна) | **IO**, **General Overview** → *PVC Disk Usage* |
| Gateway и клиенты | **Gateway**, **gRPC** |
| Raft / репликация (кластер) | **Raft** |
| RocksDB | **RocksDB** |

---

## Уровень 3 — низкий приоритет для вашего Docker Compose

- **Topology**, **Pod Restarts**, **PVC** — ориентированы на **Kubernetes**; в чистом Docker часто пустые или менее информативны (см. [описание официального Zeebe dashboard](https://docs.camunda.io/docs/self-managed/operational-guides/monitoring/metrics/) — topology, throughput, requests, disk, memory).
- **DNS**, **SWIM Protocol**, **Dynamic scaling**, узкие **Actor** — углублённая отладка кластера/сети.

---

## Итог: «самые важные борды» в одной фразе

1. **Zeebe** → строки **General Overview** (Health + Backpressure), **Throughput**, **Latency**, **Processing** (лаг позиций), при проблемах с данными — **Camunda Exporter** / **Elasticsearch Exporter**.  
2. **Data Layer** → **Camunda Exporter** + импортеры **Operate** / **Tasklist**.

Дополнительно (опционально): в доке Camunda для **execution latency** указано включение `ZEEBE_BROKER_EXECUTION_METRICS_EXPORTER_ENABLED=true` — иначе часть latency-панелей может быть беднее ([Execution latency metrics](https://docs.camunda.io/docs/self-managed/operational-guides/monitoring/metrics/)).

---

## Ссылка на документацию Grafana

Звёздить избранное: [Starred dashboards](https://grafana.com/docs/grafana/latest/dashboards/use-dashboards/) — помечаете в UI только **Zeebe** и **Data Layer**, чтобы не листать всю папку.
