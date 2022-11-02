# https://learn.microsoft.com/en-us/azure/azure-monitor/logs/tutorial-logs-ingestion-api

resource "azurerm_monitor_data_collection_endpoint" "example" {
  name                          = "mdce-azmonplus${random_string.unique.result}"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  kind                          = "Linux"
  public_network_access_enabled = true
  description                   = "monitor_data_collection_endpoint example"
  tags = local.tags
}



resource "azapi_resource" "dcr" {
  type = "Microsoft.Insights/dataCollectionRules@2021-09-01-preview"
  name = "mdcr-azapi-azmonplus${random_string.unique.result}"
  location = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id
  tags = local.tags
  body = jsonencode({
    properties = {
      dataCollectionEndpointId = azurerm_monitor_data_collection_endpoint.example.id
      streamDeclarations = {
          Custom-MyTableRawData = {
            columns = [
                {
                    name = "Time",
                    type = "datetime"
                },
                {
                    name = "Computer",
                    type = "string"
                },
                {
                    name = "AdditionalContext",
                    type = "string"
                }

            ]
        }
      }
       destinations = {
        logAnalytics = [
          {
            name = "logs-${random_string.unique.result}"
            workspaceResourceId = data.azurerm_log_analytics_workspace.default.id
          }
        ]
      }
      dataFlows = [
        {
          destinations = [
            "logs-${random_string.unique.result}"
          ]
          outputStream = "Custom-MyTable_CL"
          streams = [
            "Custom-MyTableRawData"
          ]
          transformKql = "source | extend jsonContext = parse_json(AdditionalContext) | project TimeGenerated = Time, Computer, AdditionalContext = jsonContext"
        }
      ]
     
      description = "using az api to create this"
     
      
    }
  })
  response_export_values = ["*"]
}