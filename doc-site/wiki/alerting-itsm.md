# Alerting и ITSM {#alerting-itsm}

## Схема оповещений

- единые rules в Azure Monitor Alerts и/или Grafana Alerting (в зависимости от политики)
- маршрутизация через `Action Group`
- каналы: MS Teams, Email, SMS через шлюзы
- RBAC ограничивает доступ к правилам/дашбордам (Azure AD groups)

## ITSM: автоматическое создание инцидентов

Паттерн:

1. Logic App получает payload алерта (from Action Group / webhook)
2. нормализует данные (severity, service, environment, fingerprints)
3. вызывает ITSM API:
   - ServiceNow: создание Incident
   - Jira: создание Issue
4. хранит `external incident key` для идемпотентности

Минимальный пример полей Incident (концептуально):

- `short_description`: `${service} ${alert_name} @ ${environment}`
- `severity`: mapping из severity алерта
- `assignment_group`: по tags/service owner
- `symptoms`: топ-лог-линии + ссылка на Grafana panel
- `source`: rule id / dashboard link
