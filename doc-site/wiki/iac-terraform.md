# IaC через Terraform {#iac-terraform}

## Структура модулей

```text
terraform/
  modules/
    observability-core/
      log-analytics/
      managed-prometheus/
      open-search/
      application-insights/
      otel/
      grafana/
    policy-diagnostics/
    alerting/
      action-groups/
      logic-apps-itsm/
  envs/
    prod/
      main.tf
      subscription.tfvars
```

## Diagnostic Settings для “всех типов ресурсов”

В Terraform сложнее “покрыть все resource types” без инвентаризации и учёта изменений.
Рекомендация: **Azure Policy** вместо ручного перечисления.

Концептуальный пример policy skeleton (idea):

```json
{
  "mode": "All",
  "policyRule": {
    "if": {
      "field": "type",
      "in": [
        "Microsoft.Compute/virtualMachines",
        "Microsoft.Web/sites",
        "Microsoft.Sql/servers",
        "Microsoft.ContainerService/managedClusters"
      ]
    },
    "then": {
      "effect": "DeployIfNotExists",
      "details": {
        "type": "Microsoft.Insights/diagnosticSettings",
        "deployment": {
          "properties": {
            "workspaceId": "<log-analytics-id>",
            "eventhubAuthRuleId": "<optional-eventhub-id>"
          }
        }
      }
    }
  }
}
```
