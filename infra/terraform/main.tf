locals {
  rg_name               = "${var.prefix}-rg"
  log_analytics_name   = "${var.prefix}-law"
  app_insights_name    = "${var.prefix}-appi"
  action_group_name    = "${var.prefix}-ag"
}

resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = local.log_analytics_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku               = "PerGB2018"
  retention_in_days = var.log_analytics_retention_days

  tags = var.tags
}

resource "azurerm_application_insights" "appinsights" {
  name                = local.app_insights_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  application_type = "web"
  workspace_id     = azurerm_log_analytics_workspace.law.id
  retention_in_days = var.app_insights_retention_days

  tags = var.tags
}

resource "azurerm_monitor_action_group" "action_group" {
  name                = local.action_group_name
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = var.action_group_short_name

  email_receiver {
    name                    = "oncall-email"
    email_address          = var.alert_email
    use_common_alert_schema = true
  }
}

