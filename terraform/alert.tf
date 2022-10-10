resource "azurerm_monitor_metric_alert" "failures" {
  name                = "failure-${local.func_name}"
  resource_group_name = azurerm_resource_group.rg.name
  scopes = [
    azurerm_application_insights.app.id
  ]
  description = "Use Terraform to create a metric Alert"

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "exceptions/count"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 2

    dimension {
      name     = "cloud/roleName"
      operator = "Include"
      values   = ["*"]
    }
  }
}
