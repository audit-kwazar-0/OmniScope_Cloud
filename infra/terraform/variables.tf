variable "prefix" {
  description = "Naming prefix used across resources."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "westeurope"
}

variable "alert_email" {
  description = "Email receiver for Azure Monitor Action Group."
  type        = string
}

variable "log_analytics_retention_days" {
  description = "Log Analytics retention in days."
  type        = number
  default     = 30
}

variable "app_insights_retention_days" {
  description = "Application Insights retention in days."
  type        = number
  default     = 90
}

variable "tags" {
  description = "Optional tags."
  type        = map(string)
  default     = {}
}

variable "action_group_short_name" {
  description = "Action group short name (used in SMS); keep <= 12 chars."
  type        = string
  default     = "obs-pzu"
}

