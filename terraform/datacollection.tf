resource "azurerm_monitor_data_collection_endpoint" "example" {
  name                          = "mdce-azmonplus${random_string.unique.result}"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  kind                          = "Linux"
  public_network_access_enabled = true
  description                   = "monitor_data_collection_endpoint example"
  tags = local.tags
}

resource "azurerm_monitor_data_collection_rule" "example" {
  name                = "mdcr-azmonplus${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  destinations {
    log_analytics {
      workspace_resource_id = data.azurerm_log_analytics_workspace.default.id
      name                  = "destination-log-${random_string.unique.result}"
    }

    azure_monitor_metrics {
      name = "destination-metrics-${random_string.unique.result}"
    }
  }

  description = "data collection rule example"
  tags = local.tags
}