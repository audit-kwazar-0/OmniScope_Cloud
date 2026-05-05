# OmniScope: Vision of the Future Project

## Зачем нужен OmniScope

OmniScope задуман как единая облачная платформа наблюдаемости (observability) для продуктовых и платформенных команд.  
Главная идея: команда должна видеть состояние системы в реальном времени и быстро переходить от симптома к причине, не переключаясь между десятком разрозненных инструментов.

Проект решает три практические задачи:

1. **Скорость диагностики** — уменьшение MTTR за счет связки метрик, логов и трассировок.
2. **Предсказуемость релизов** — observability встроена в процесс доставки, а не добавляется постфактум.
3. **Единый стандарт эксплуатации** — общие шаблоны IaC, дашбордов, алертов и runbook.

## Философия проекта

### 1) Observability by default
Любой новый сервис в кластере должен автоматически попадать в единый контур:
- метрики,
- логи,
- трассировки,
- алерты.

### 2) Infrastructure as Product
Платформа — это продукт для внутренних команд.  
Значит, у нее есть:
- версия,
- roadmap,
- SLA/SLO,
- документация и поддерживаемые сценарии.

### 3) Everything as Code
Всё, что можно версионировать, должно жить в репозитории:
- инфраструктура (Bicep),
- Kubernetes манифесты,
- dashboard templates,
- alert rules,
- runbook и evidence.

### 4) Correlation first
Ценность observability появляется только когда сигналы связаны:
- метрика -> лог -> трейс,
- алерт -> дашборд -> runbook,
- инцидент -> воспроизводимый сценарий проверки.

## Целевое состояние архитектуры

### Platform layer (Azure)
- AKS как единая runtime-среда.
- LAW как основной слой логов.
- Application Insights как APM/tracing backend.
- Azure Monitor Workspace + Managed Grafana как слой метрик.
- Event Hub export path для OpenSearch/Elastic сценариев deep-search и long-term forensic.

### Workload layer (Kubernetes)
- Сервисы развертываются в единый namespace/контур с обязательными telemetry-конвенциями.
- OTel Collector выступает как control plane телеметрии.
- Gateway API/Ingress используется как единая точка входа.

### Operations layer
- Alert rules на инфраструктуру и прикладные SLI.
- Action Group (email/webhook) и дальнейшая интеграция с incident workflow.
- Runbook-ориентированная эксплуатация.

## Принципы реализации

1. **Incremental delivery**: сначала рабочий MVP, затем hardening.
2. **No magic defaults**: все критичные параметры документируются.
3. **Fail with context**: алерт без ссылки на контекст (дашборд/логи/трейс) считается неполным.
4. **Security baseline**: секреты вне git, least privilege, аудируемые изменения.
5. **Cost awareness**: контроль cardinality, retention и частоты сигналов.

## Этапы развития (high-level roadmap)

### Phase 1 — Foundation
- Базовый IaC контур (AKS + LAW + AppInsights + Grafana/Prometheus + alerts).
- Референсный набор сервисов и e2e smoke checks.

### Phase 2 — Standardization
- Telemetry contract для всех сервисов.
- Template-подход для dashboards/alerts.
- CI gates: validate + what-if + trace-based smoke.

### Phase 3 — Production Hardening
- Политики доступа, приватные endpoint-сценарии, compliance-практики.
- Incident workflow и postmortem templates.
- Capacity/cost optimization и SLO governance.

### Phase 4 — Platform Scale
- Подключение новых команд как self-service.
- Multi-environment/multi-cluster operating model.
- Регулярный quality review observability coverage.

## Definition of Success

OmniScope считается успешным, если:

- любой сервис подключается к observability-контуру по стандартному шаблону,
- инцидент можно разобрать end-to-end за минуты, а не часы,
- инфраструктура и мониторинг воспроизводимы из кода,
- документация остается актуальной и поддерживает ежедневную работу команд.
