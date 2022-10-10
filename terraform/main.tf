terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.21.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.1.0"
    }
  }
  backend "azurerm" {

  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = var.subscription_id
}

locals {
  func_name      = "func${random_string.unique.result}"
  loc_for_naming = lower(replace(var.location, " ", ""))
  gh_repo        = replace(var.gh_repo, "implodingduck/", "")
  tags = {
    "managed_by" = "terraform"
    "repo"       = local.gh_repo
  }
}

resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}


data "azurerm_client_config" "current" {}

data "azurerm_log_analytics_workspace" "default" {
  name                = "DefaultWorkspace-${data.azurerm_client_config.current.subscription_id}-EUS"
  resource_group_name = "DefaultResourceGroup-EUS"
}


resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.gh_repo}-${random_string.unique.result}-${local.loc_for_naming}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_application_insights" "app" {
  name                = "${local.func_name}-insights"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  application_type    = "other"
  workspace_id        = data.azurerm_log_analytics_workspace.default.id
}


resource "azurerm_storage_account" "sa" {
  name                     = "sa${local.func_name}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "asp" {
  name                = "asp-${local.func_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_function_app" "func" {
  name                       = local.func_name
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  storage_account_name       = azurerm_storage_account.sa.name
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key
  service_plan_id            = azurerm_service_plan.asp.id


  site_config {
    application_insights_key = azurerm_application_insights.app.instrumentation_key
    application_stack {
      node_version = "16"
    }

  }

  app_settings = {
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "1"
    "BUILD_FLAGS"                    = "UseExpressBuild"
    "ENABLE_ORYX_BUILD"              = "true"
    "XDG_CACHE_HOME"                 = "/tmp/.cache"
    "FUNC_TYPE"                      = "USELOCAL"
  }

}

resource "local_file" "localsettings" {
  content  = <<-EOT
{
  "IsEncrypted": false,
  "Values": {
    "FUNCTIONS_WORKER_RUNTIME": "node",
    "AzureWebJobsStorage": ""
  }
}
EOT
  filename = "../func/local.settings.json"
}

resource "null_resource" "publish_func" {
  depends_on = [
    azurerm_linux_function_app.func,
    local_file.localsettings
  ]
  triggers = {
    index = "${timestamp()}"
  }
  provisioner "local-exec" {
    working_dir = "../func"
    command     = "sleep 10 && timeout 10m func azure functionapp publish ${azurerm_linux_function_app.func.name} --build remote"

  }
}

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

resource "azurerm_portal_dashboard" "board" {
  name                 = "tf-dashboard-${local.func_name}"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  tags                 = local.tags
  dashboard_properties = <<DASH
{
    "lenses": {
      "0": {
        "order": 0,
        "parts": {
          "0": {
            "position": {
              "x": 0,
              "y": 0,
              "colSpan": 2,
              "rowSpan": 1
            },
            "metadata": {
              "inputs": [
                {
                  "name": "id",
                  "value": "${azurerm_application_insights.app.id}"
                },
                {
                  "name": "Version",
                  "value": "1.0"
                }
              ],
              "type": "Extension/AppInsightsExtension/PartType/AspNetOverviewPinnedPart",
              "asset": {
                "idInputName": "id",
                "type": "ApplicationInsights"
              },
              "defaultMenuItemId": "overview"
            }
          },
          "1": {
            "position": {
              "x": 2,
              "y": 0,
              "colSpan": 1,
              "rowSpan": 1
            },
            "metadata": {
              "inputs": [
                {
                  "name": "ComponentId",
                  "value": {
                    "Name": "${azurerm_application_insights.app.name}",
                    "SubscriptionId": "${data.azurerm_client_config.current.subscription_id}",
                    "ResourceGroup": "${azurerm_resource_group.rg.name}"
                  }
                },
                {
                  "name": "Version",
                  "value": "1.0"
                }
              ],
              "type": "Extension/AppInsightsExtension/PartType/ProactiveDetectionAsyncPart",
              "asset": {
                "idInputName": "ComponentId",
                "type": "ApplicationInsights"
              },
              "defaultMenuItemId": "ProactiveDetection"
            }
          },
          "2": {
            "position": {
              "x": 3,
              "y": 0,
              "colSpan": 1,
              "rowSpan": 1
            },
            "metadata": {
              "inputs": [
                {
                  "name": "ComponentId",
                  "value": {
                    "Name": "${azurerm_application_insights.app.name}",
                    "SubscriptionId": "${data.azurerm_client_config.current.subscription_id}",
                    "ResourceGroup": "${azurerm_resource_group.rg.name}"
                  }
                },
                {
                  "name": "ResourceId",
                  "value": "${azurerm_application_insights.app.id}"
                }
              ],
              "type": "Extension/AppInsightsExtension/PartType/QuickPulseButtonSmallPart",
              "asset": {
                "idInputName": "ComponentId",
                "type": "ApplicationInsights"
              }
            }
          },
          "3": {
            "position": {
              "x": 4,
              "y": 0,
              "colSpan": 1,
              "rowSpan": 1
            },
            "metadata": {
              "inputs": [
                {
                  "name": "ComponentId",
                  "value": {
                    "Name": "${azurerm_application_insights.app.name}",
                    "SubscriptionId": "${data.azurerm_client_config.current.subscription_id}",
                    "ResourceGroup": "${azurerm_resource_group.rg.name}"
                  }
                },
                {
                  "name": "TimeContext",
                  "value": {
                    "durationMs": 86400000,
                    "endTime": null,
                    "createdTime": "2018-05-04T01:20:33.345Z",
                    "isInitialTime": true,
                    "grain": 1,
                    "useDashboardTimeRange": false
                  }
                },
                {
                  "name": "Version",
                  "value": "1.0"
                }
              ],
              "type": "Extension/AppInsightsExtension/PartType/AvailabilityNavButtonPart",
              "asset": {
                "idInputName": "ComponentId",
                "type": "ApplicationInsights"
              }
            }
          },
          "4": {
            "position": {
              "x": 5,
              "y": 0,
              "colSpan": 1,
              "rowSpan": 1
            },
            "metadata": {
              "inputs": [
                {
                  "name": "ComponentId",
                  "value": {
                    "Name": "${azurerm_application_insights.app.name}",
                    "SubscriptionId": "${data.azurerm_client_config.current.subscription_id}",
                    "ResourceGroup": "${azurerm_resource_group.rg.name}"
                  }
                },
                {
                  "name": "TimeContext",
                  "value": {
                    "durationMs": 86400000,
                    "endTime": null,
                    "createdTime": "2018-05-08T18:47:35.237Z",
                    "isInitialTime": true,
                    "grain": 1,
                    "useDashboardTimeRange": false
                  }
                },
                {
                  "name": "ConfigurationId",
                  "value": "78ce933e-e864-4b05-a27b-71fd55a6afad"
                }
              ],
              "type": "Extension/AppInsightsExtension/PartType/AppMapButtonPart",
              "asset": {
                "idInputName": "ComponentId",
                "type": "ApplicationInsights"
              }
            }
          },
          "5": {
            "position": {
              "x": 0,
              "y": 1,
              "colSpan": 3,
              "rowSpan": 1
            },
            "metadata": {
              "inputs": [],
              "type": "Extension/HubsExtension/PartType/MarkdownPart",
              "settings": {
                "content": {
                  "settings": {
                    "content": "# Usage",
                    "title": "",
                    "subtitle": ""
                  }
                }
              }
            }
          },
          "6": {
            "position": {
              "x": 3,
              "y": 1,
              "colSpan": 1,
              "rowSpan": 1
            },
            "metadata": {
              "inputs": [
                {
                  "name": "ComponentId",
                  "value": {
                    "Name": "${azurerm_application_insights.app.name}",
                    "SubscriptionId": "${data.azurerm_client_config.current.subscription_id}",
                    "ResourceGroup": "${azurerm_resource_group.rg.name}"
                  }
                },
                {
                  "name": "TimeContext",
                  "value": {
                    "durationMs": 86400000,
                    "endTime": null,
                    "createdTime": "2018-05-04T01:22:35.782Z",
                    "isInitialTime": true,
                    "grain": 1,
                    "useDashboardTimeRange": false
                  }
                }
              ],
              "type": "Extension/AppInsightsExtension/PartType/UsageUsersOverviewPart",
              "asset": {
                "idInputName": "ComponentId",
                "type": "ApplicationInsights"
              }
            }
          },
          "7": {
            "position": {
              "x": 4,
              "y": 1,
              "colSpan": 3,
              "rowSpan": 1
            },
            "metadata": {
              "inputs": [],
              "type": "Extension/HubsExtension/PartType/MarkdownPart",
              "settings": {
                "content": {
                  "settings": {
                    "content": "# Reliability",
                    "title": "",
                    "subtitle": ""
                  }
                }
              }
            }
          },
          "8": {
            "position": {
              "x": 7,
              "y": 1,
              "colSpan": 1,
              "rowSpan": 1
            },
            "metadata": {
              "inputs": [
                {
                  "name": "ResourceId",
                  "value": "${azurerm_application_insights.app.id}"
                },
                {
                  "name": "DataModel",
                  "value": {
                    "version": "1.0.0",
                    "timeContext": {
                      "durationMs": 86400000,
                      "createdTime": "2018-05-04T23:42:40.072Z",
                      "isInitialTime": false,
                      "grain": 1,
                      "useDashboardTimeRange": false
                    }
                  },
                  "isOptional": true
                },
                {
                  "name": "ConfigurationId",
                  "value": "8a02f7bf-ac0f-40e1-afe9-f0e72cfee77f",
                  "isOptional": true
                }
              ],
              "type": "Extension/AppInsightsExtension/PartType/CuratedBladeFailuresPinnedPart",
              "isAdapter": true,
              "asset": {
                "idInputName": "ResourceId",
                "type": "ApplicationInsights"
              },
              "defaultMenuItemId": "failures"
            }
          },
          "9": {
            "position": {
              "x": 8,
              "y": 1,
              "colSpan": 3,
              "rowSpan": 1
            },
            "metadata": {
              "inputs": [],
              "type": "Extension/HubsExtension/PartType/MarkdownPart",
              "settings": {
                "content": {
                  "settings": {
                    "content": "# Responsiveness\r\n",
                    "title": "",
                    "subtitle": ""
                  }
                }
              }
            }
          },
          "10": {
            "position": {
              "x": 11,
              "y": 1,
              "colSpan": 1,
              "rowSpan": 1
            },
            "metadata": {
              "inputs": [
                {
                  "name": "ResourceId",
                  "value": "${azurerm_application_insights.app.id}"
                },
                {
                  "name": "DataModel",
                  "value": {
                    "version": "1.0.0",
                    "timeContext": {
                      "durationMs": 86400000,
                      "createdTime": "2018-05-04T23:43:37.804Z",
                      "isInitialTime": false,
                      "grain": 1,
                      "useDashboardTimeRange": false
                    }
                  },
                  "isOptional": true
                },
                {
                  "name": "ConfigurationId",
                  "value": "2a8ede4f-2bee-4b9c-aed9-2db0e8a01865",
                  "isOptional": true
                }
              ],
              "type": "Extension/AppInsightsExtension/PartType/CuratedBladePerformancePinnedPart",
              "isAdapter": true,
              "asset": {
                "idInputName": "ResourceId",
                "type": "ApplicationInsights"
              },
              "defaultMenuItemId": "performance"
            }
          },
          "13": {
            "position": {
              "x": 0,
              "y": 2,
              "colSpan": 4,
              "rowSpan": 3
            },
            "metadata": {
              "inputs": [
                {
                  "name": "options",
                  "value": {
                    "chart": {
                      "metrics": [
                        {
                          "resourceMetadata": {
                            "id": "${azurerm_application_insights.app.id}"
                          },
                          "name": "sessions/count",
                          "aggregationType": 5,
                          "namespace": "microsoft.insights/components/kusto",
                          "metricVisualization": {
                            "displayName": "Sessions",
                            "color": "#47BDF5"
                          }
                        },
                        {
                          "resourceMetadata": {
                            "id": "${azurerm_application_insights.app.id}"
                          },
                          "name": "users/count",
                          "aggregationType": 5,
                          "namespace": "microsoft.insights/components/kusto",
                          "metricVisualization": {
                            "displayName": "Users",
                            "color": "#7E58FF"
                          }
                        }
                      ],
                      "title": "Unique sessions and users",
                      "visualization": {
                        "chartType": 2,
                        "legendVisualization": {
                          "isVisible": true,
                          "position": 2,
                          "hideSubtitle": false
                        },
                        "axisVisualization": {
                          "x": {
                            "isVisible": true,
                            "axisType": 2
                          },
                          "y": {
                            "isVisible": true,
                            "axisType": 1
                          }
                        }
                      },
                      "openBladeOnClick": {
                        "openBlade": true,
                        "destinationBlade": {
                          "extensionName": "HubsExtension",
                          "bladeName": "ResourceMenuBlade",
                          "parameters": {
                            "id": "${azurerm_application_insights.app.id}",
                            "menuid": "segmentationUsers"
                          }
                        }
                      }
                    }
                  }
                },
                {
                  "name": "sharedTimeRange",
                  "isOptional": true
                }
              ],
              "type": "Extension/HubsExtension/PartType/MonitorChartPart",
              "settings": {}
            }
          },
          "14": {
            "position": {
              "x": 4,
              "y": 2,
              "colSpan": 4,
              "rowSpan": 3
            },
            "metadata": {
              "inputs": [
                {
                  "name": "options",
                  "value": {
                    "chart": {
                      "metrics": [
                        {
                          "resourceMetadata": {
                            "id": "${azurerm_application_insights.app.id}"
                          },
                          "name": "requests/failed",
                          "aggregationType": 7,
                          "namespace": "microsoft.insights/components",
                          "metricVisualization": {
                            "displayName": "Failed requests",
                            "color": "#EC008C"
                          }
                        }
                      ],
                      "title": "Failed requests",
                      "visualization": {
                        "chartType": 3,
                        "legendVisualization": {
                          "isVisible": true,
                          "position": 2,
                          "hideSubtitle": false
                        },
                        "axisVisualization": {
                          "x": {
                            "isVisible": true,
                            "axisType": 2
                          },
                          "y": {
                            "isVisible": true,
                            "axisType": 1
                          }
                        }
                      },
                      "openBladeOnClick": {
                        "openBlade": true,
                        "destinationBlade": {
                          "extensionName": "HubsExtension",
                          "bladeName": "ResourceMenuBlade",
                          "parameters": {
                            "id": "${azurerm_application_insights.app.id}",
                            "menuid": "failures"
                          }
                        }
                      }
                    }
                  }
                },
                {
                  "name": "sharedTimeRange",
                  "isOptional": true
                }
              ],
              "type": "Extension/HubsExtension/PartType/MonitorChartPart",
              "settings": {}
            }
          },
          "15": {
            "position": {
              "x": 8,
              "y": 2,
              "colSpan": 4,
              "rowSpan": 3
            },
            "metadata": {
              "inputs": [
                {
                  "name": "options",
                  "value": {
                    "chart": {
                      "metrics": [
                        {
                          "resourceMetadata": {
                            "id": "${azurerm_application_insights.app.id}"
                          },
                          "name": "requests/duration",
                          "aggregationType": 4,
                          "namespace": "microsoft.insights/components",
                          "metricVisualization": {
                            "displayName": "Server response time",
                            "color": "#00BCF2"
                          }
                        }
                      ],
                      "title": "Server response time",
                      "visualization": {
                        "chartType": 2,
                        "legendVisualization": {
                          "isVisible": true,
                          "position": 2,
                          "hideSubtitle": false
                        },
                        "axisVisualization": {
                          "x": {
                            "isVisible": true,
                            "axisType": 2
                          },
                          "y": {
                            "isVisible": true,
                            "axisType": 1
                          }
                        }
                      },
                      "openBladeOnClick": {
                        "openBlade": true,
                        "destinationBlade": {
                          "extensionName": "HubsExtension",
                          "bladeName": "ResourceMenuBlade",
                          "parameters": {
                            "id": "${azurerm_application_insights.app.id}",
                            "menuid": "performance"
                          }
                        }
                      }
                    }
                  }
                },
                {
                  "name": "sharedTimeRange",
                  "isOptional": true
                }
              ],
              "type": "Extension/HubsExtension/PartType/MonitorChartPart",
              "settings": {}
            }
          },
          "17": {
            "position": {
              "x": 0,
              "y": 5,
              "colSpan": 4,
              "rowSpan": 3
            },
            "metadata": {
              "inputs": [
                {
                  "name": "options",
                  "value": {
                    "chart": {
                      "metrics": [
                        {
                          "resourceMetadata": {
                            "id": "${azurerm_application_insights.app.id}"
                          },
                          "name": "availabilityResults/availabilityPercentage",
                          "aggregationType": 4,
                          "namespace": "microsoft.insights/components",
                          "metricVisualization": {
                            "displayName": "Availability",
                            "color": "#47BDF5"
                          }
                        }
                      ],
                      "title": "Average availability",
                      "visualization": {
                        "chartType": 3,
                        "legendVisualization": {
                          "isVisible": true,
                          "position": 2,
                          "hideSubtitle": false
                        },
                        "axisVisualization": {
                          "x": {
                            "isVisible": true,
                            "axisType": 2
                          },
                          "y": {
                            "isVisible": true,
                            "axisType": 1
                          }
                        }
                      },
                      "openBladeOnClick": {
                        "openBlade": true,
                        "destinationBlade": {
                          "extensionName": "HubsExtension",
                          "bladeName": "ResourceMenuBlade",
                          "parameters": {
                            "id": "${azurerm_application_insights.app.id}",
                            "menuid": "availability"
                          }
                        }
                      }
                    }
                  }
                },
                {
                  "name": "sharedTimeRange",
                  "isOptional": true
                }
              ],
              "type": "Extension/HubsExtension/PartType/MonitorChartPart",
              "settings": {}
            }
          },
          "18": {
            "position": {
              "x": 4,
              "y": 5,
              "colSpan": 4,
              "rowSpan": 3
            },
            "metadata": {
              "inputs": [
                {
                  "name": "options",
                  "value": {
                    "chart": {
                      "metrics": [
                        {
                          "resourceMetadata": {
                            "id": "${azurerm_application_insights.app.id}"
                          },
                          "name": "exceptions/server",
                          "aggregationType": 7,
                          "namespace": "microsoft.insights/components",
                          "metricVisualization": {
                            "displayName": "Server exceptions",
                            "color": "#47BDF5"
                          }
                        },
                        {
                          "resourceMetadata": {
                            "id": "${azurerm_application_insights.app.id}"
                          },
                          "name": "dependencies/failed",
                          "aggregationType": 7,
                          "namespace": "microsoft.insights/components",
                          "metricVisualization": {
                            "displayName": "Dependency failures",
                            "color": "#7E58FF"
                          }
                        }
                      ],
                      "title": "Server exceptions and Dependency failures",
                      "visualization": {
                        "chartType": 2,
                        "legendVisualization": {
                          "isVisible": true,
                          "position": 2,
                          "hideSubtitle": false
                        },
                        "axisVisualization": {
                          "x": {
                            "isVisible": true,
                            "axisType": 2
                          },
                          "y": {
                            "isVisible": true,
                            "axisType": 1
                          }
                        }
                      }
                    }
                  }
                },
                {
                  "name": "sharedTimeRange",
                  "isOptional": true
                }
              ],
              "type": "Extension/HubsExtension/PartType/MonitorChartPart",
              "settings": {}
            }
          },
          "19": {
            "position": {
              "x": 8,
              "y": 5,
              "colSpan": 4,
              "rowSpan": 3
            },
            "metadata": {
              "inputs": [
                {
                  "name": "options",
                  "value": {
                    "chart": {
                      "metrics": [
                        {
                          "resourceMetadata": {
                            "id": "${azurerm_application_insights.app.id}"
                          },
                          "name": "performanceCounters/processorCpuPercentage",
                          "aggregationType": 4,
                          "namespace": "microsoft.insights/components",
                          "metricVisualization": {
                            "displayName": "Processor time",
                            "color": "#47BDF5"
                          }
                        },
                        {
                          "resourceMetadata": {
                            "id": "${azurerm_application_insights.app.id}"
                          },
                          "name": "performanceCounters/processCpuPercentage",
                          "aggregationType": 4,
                          "namespace": "microsoft.insights/components",
                          "metricVisualization": {
                            "displayName": "Process CPU",
                            "color": "#7E58FF"
                          }
                        }
                      ],
                      "title": "Average processor and process CPU utilization",
                      "visualization": {
                        "chartType": 2,
                        "legendVisualization": {
                          "isVisible": true,
                          "position": 2,
                          "hideSubtitle": false
                        },
                        "axisVisualization": {
                          "x": {
                            "isVisible": true,
                            "axisType": 2
                          },
                          "y": {
                            "isVisible": true,
                            "axisType": 1
                          }
                        }
                      }
                    }
                  }
                },
                {
                  "name": "sharedTimeRange",
                  "isOptional": true
                }
              ],
              "type": "Extension/HubsExtension/PartType/MonitorChartPart",
              "settings": {}
            }
          },
          
          "21": {
            "position": {
              "x": 0,
              "y": 8,
              "colSpan": 4,
              "rowSpan": 3
            },
            "metadata": {
              "inputs": [
                {
                  "name": "options",
                  "value": {
                    "chart": {
                      "metrics": [
                        {
                          "resourceMetadata": {
                            "id": "${azurerm_application_insights.app.id}"
                          },
                          "name": "availabilityResults/count",
                          "aggregationType": 7,
                          "namespace": "microsoft.insights/components",
                          "metricVisualization": {
                            "displayName": "Availability test results count",
                            "color": "#47BDF5"
                          }
                        }
                      ],
                      "title": "Availability test results count",
                      "visualization": {
                        "chartType": 2,
                        "legendVisualization": {
                          "isVisible": true,
                          "position": 2,
                          "hideSubtitle": false
                        },
                        "axisVisualization": {
                          "x": {
                            "isVisible": true,
                            "axisType": 2
                          },
                          "y": {
                            "isVisible": true,
                            "axisType": 1
                          }
                        }
                      }
                    }
                  }
                },
                {
                  "name": "sharedTimeRange",
                  "isOptional": true
                }
              ],
              "type": "Extension/HubsExtension/PartType/MonitorChartPart",
              "settings": {}
            }
          },
          "22": {
            "position": {
              "x": 4,
              "y": 8,
              "colSpan": 4,
              "rowSpan": 3
            },
            "metadata": {
              "inputs": [
                {
                  "name": "options",
                  "value": {
                    "chart": {
                      "metrics": [
                        {
                          "resourceMetadata": {
                            "id": "${azurerm_application_insights.app.id}"
                          },
                          "name": "performanceCounters/processIOBytesPerSecond",
                          "aggregationType": 4,
                          "namespace": "microsoft.insights/components",
                          "metricVisualization": {
                            "displayName": "Process IO rate",
                            "color": "#47BDF5"
                          }
                        }
                      ],
                      "title": "Average process I/O rate",
                      "visualization": {
                        "chartType": 2,
                        "legendVisualization": {
                          "isVisible": true,
                          "position": 2,
                          "hideSubtitle": false
                        },
                        "axisVisualization": {
                          "x": {
                            "isVisible": true,
                            "axisType": 2
                          },
                          "y": {
                            "isVisible": true,
                            "axisType": 1
                          }
                        }
                      }
                    }
                  }
                },
                {
                  "name": "sharedTimeRange",
                  "isOptional": true
                }
              ],
              "type": "Extension/HubsExtension/PartType/MonitorChartPart",
              "settings": {}
            }
          },
          "23": {
            "position": {
              "x": 8,
              "y": 8,
              "colSpan": 4,
              "rowSpan": 3
            },
            "metadata": {
              "inputs": [
                {
                  "name": "options",
                  "value": {
                    "chart": {
                      "metrics": [
                        {
                          "resourceMetadata": {
                            "id": "${azurerm_application_insights.app.id}"
                          },
                          "name": "performanceCounters/memoryAvailableBytes",
                          "aggregationType": 4,
                          "namespace": "microsoft.insights/components",
                          "metricVisualization": {
                            "displayName": "Available memory",
                            "color": "#47BDF5"
                          }
                        }
                      ],
                      "title": "Average available memory",
                      "visualization": {
                        "chartType": 2,
                        "legendVisualization": {
                          "isVisible": true,
                          "position": 2,
                          "hideSubtitle": false
                        },
                        "axisVisualization": {
                          "x": {
                            "isVisible": true,
                            "axisType": 2
                          },
                          "y": {
                            "isVisible": true,
                            "axisType": 1
                          }
                        }
                      }
                    }
                  }
                },
                {
                  "name": "sharedTimeRange",
                  "isOptional": true
                }
              ],
              "type": "Extension/HubsExtension/PartType/MonitorChartPart",
              "settings": {}
            }
          }
        }
      }
    }
}
DASH
}

resource "azurerm_dashboard_grafana" "grafana" {
  name                              = "${local.func_name}-grafana"
  resource_group_name               = azurerm_resource_group.rg.name
  location                          = azurerm_resource_group.rg.location
  api_key_enabled                   = true
  deterministic_outbound_ip_enabled = true
  public_network_access_enabled     = true

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

resource "azurerm_role_assignment" "reader" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.grafana.identity[0].principal_id
}