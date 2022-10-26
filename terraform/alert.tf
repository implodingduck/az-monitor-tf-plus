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

resource "azurerm_monitor_metric_alert" "avgduration" {
  name                = "avgduration-${local.func_name}"
  resource_group_name = azurerm_resource_group.rg.name
  scopes = [
    azurerm_application_insights.app.id
  ]
  description = "Average Duration in App Insights"
  window_size = "PT15M"
  frequency = "PT15M"
  criteria {
    metric_namespace = "Azure.ApplicationInsights"
    metric_name      = "HttpTrigger AvgDurationMs"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 150

  }
}

resource "azurerm_monitor_metric_alert" "availability" {
  name                = "availability-${local.func_name}"
  resource_group_name = azurerm_resource_group.rg.name
  scopes = [
    azurerm_application_insights.app.id
  ]
  description = "Average Duration in App Insights"
  window_size = "PT15M"
  frequency = "PT15M"
  criteria {
    metric_namespace = "Microsoft.Insights/components"
    metric_name      = "availabilityResults/availabilityPercentage"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 90

  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "request_count" {
  name = "requestcount-${local.func_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  criteria {
    operator = "GreaterThan"
    threshold = "5"
    time_aggregation_method = "Total"
    metric_measure_column = "totalCount"
    query = <<-QUERY
      requests
        | summarize totalCount=sum(itemCount)
      QUERY
  }
  evaluation_frequency = "PT10M"
  scopes = [
    azurerm_application_insights.app.id
  ]
  severity = 4
  window_duration = "PT10M"
}