resource "azurerm_monitor_data_collection_endpoint" "example" {
  name                          = "mdce-azmonplus${random_string.unique.result}"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  kind                          = "Linux"
  public_network_access_enabled = true
  description                   = "monitor_data_collection_endpoint example"
  tags = local.tags
}

# resource "azapi_resource" "dcr" {
#   type = "Microsoft.Insights/dataCollectionRules@2021-09-01-preview"
#   name = "mdcr-azapi-azmonplus${random_string.unique.result}"
#   location = azurerm_resource_group.rg.location
#   parent_id = azurerm_resource_group.rg.id
#   tags = local.tags
#   body = jsonencode({
#     properties = {
#       dataCollectionEndpointId = azurerm_monitor_data_collection_endpoint.example.id
#       dataFlows = [
#         {
#           destinations = [
#             "Custom-MyTableRawData"
#           ]
#           outputStream = "string"
#           streams = [
#             "string"
#           ]
#           transformKql = "string"
#         }
#       ]
     
#       description = "using az api to create this"
#       destinations = {
#         azureMonitorMetrics = {
#           name = "string"
#         }
#         logAnalytics = [
#           {
#             name = "string"
#             workspaceResourceId = "string"
#           }
#         ]
#       }
#       streamDeclarations = {
#           Custom-MyTableRawData = {
#             columns = [
#                 {
#                     name = "instant"
#                     type = "map"
#                 }
#                 {
#                     name = "thread",
#                     type = "string"
#                 },
#                 {
#                     name = "level",
#                     type = "string"
#                 },
#                 {
#                     name = "loggerName",
#                     type = "string"
#                 },
#                 {
#                     name = "message",
#                     type = "string"
#                 },
#                 {
#                     name = "threadId",
#                     type = "number"
#                 },
#                 {
#                     name = "threadPriority",
#                     type =  "number"
#                 }

#             ]
#         }
#       }
#     }
#     kind = "Linux"
#   })
# }