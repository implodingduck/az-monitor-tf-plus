#!/bin/bash

# https://learn.microsoft.com/en-us/azure/azure-monitor/logs/tutorial-logs-ingestion-api

source .env

ACCESS_TOKEN=$(curl -s -X POST -d "client_id=$APP_CLIENT_ID&scope=https%3A%2F%2Fmonitor.azure.com%2F%2F.default&client_secret=$APP_CLIENT_SECRET&grant_type=client_credentials" "https://login.microsoftonline.com/$APP_TENANT_ID/oauth2/v2.0/token" | jq -r .access_token)
echo $ACCESS_TOKEN
# 2009-06-15T13:45:30.0000000Z
CURRENT_TIME=$(date +"%Y-%m-%dT%T.0000000Z")
JSON_BODY="[{\"Time\": \"$CURRENT_TIME\",\"Computer\": \"Computer1\",\"AdditionalContext\": { \"InstanceName\": \"user1\", \"TimeZone\": \"Pacific Time\", \"Level\": 4, \"CounterName\": \"AppMetric1\",\"CounterValue\": 15.3 }}]"
JSON_BODY="{\"Time\": \"$CURRENT_TIME\",\"Computer\": \"Computer1\",\"AdditionalContext\": { \"InstanceName\": \"user1\", \"TimeZone\": \"Pacific Time\", \"Level\": 4, \"CounterName\": \"AppMetric1\",\"CounterValue\": 15.3 }}"

echo $JSON_BODY

curl -vvv -X POST -H "Content-Encoding: gzip" -H "Content-Type: application/json" -H "Authorization: Bearer $ACCESS_TOKEN" -d "$JSON_BODY" "$DATA_COLLECTION_ENDPOINT/dataCollectionRules/$DATA_RULE_ID/streams/Custom-MyTableRawData?api-version=2021-11-01-preview"