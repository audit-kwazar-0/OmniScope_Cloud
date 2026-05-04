# Автоматическая регистрация ресурсов {#auto-registration}

Для enterprise-масштаба рекомендуем стандартный механизм: **Azure Policy** + (при необходимости) **Event Grid/Functions**.

## Путь A (primary): Azure Policy (DeployIfNotExists)

Идея:

- назначить policy assignment на уровень Subscription / Management Group
- policy автоматически создает/включает `Diagnostic Settings` и маршрутизацию в нужные sink’и
- политика применяется к новым ресурсам и к ресурсам при изменениях (если включить соответствующие параметры)

## Путь B (secondary): Event-driven (Activity Log → Event Grid → Function)

Если нужно “регистрировать” не только Diagnostic Settings, но и, например:

- автоматическое связывание ресурсов с ITSM командами/assignment groups
- обновление конфигурации OTel routing

Тогда:

- подписка на события изменений через Activity Log → Event Grid
- Azure Function читает event, затем через Resource Graph получает сведения о ресурсе
- Function выполняет идемпотентные операции (создание связей/метаданных/вызов ARM REST при необходимости)
