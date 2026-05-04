output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.law.id
}

output "application_insights_id" {
  value = azurerm_application_insights.appinsights.id
}

output "action_group_id" {
  value = azurerm_monitor_action_group.action_group.id
}

