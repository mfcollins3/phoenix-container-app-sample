// Copyright 2025 Neudesic, an IBM Company
//
// This program is confidential and proprietary to Neudesic, an IBM Company,
// and may not be reproduced, published, or disclosed to others without company
// authorization.

targetScope = 'subscription'

@description('Name of the Application Insights dashboard to be created')
param applicationInsightsDashboardName string = ''

@description('Name of the Application Insights resource to be created')
param applicationInsightsName string = ''

@description('Name of the Container Apps Environment to be created')
param containerAppsEnvironmentName string = ''

@description('Name of the Container Registry to be created')
param containerRegistryName string = ''

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Name of the Log Analytics Workspace to be created')
param logAnalyticsWorkspaceName string = ''

@description('Email address of the owner of the Azure resources')
param ownerEmail string

@description('Name of the virtual network to be created')
param virtualNetworkName string = ''

var abbrs = loadJsonContent('./abbreviations.json')

var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
  Owner: ownerEmail
}

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module monitoring 'br/public:avm/ptn/azd/monitoring:0.1.1' = {
  name: 'monitoring'
  scope: rg
  params: {
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    logAnalyticsName: !empty(logAnalyticsWorkspaceName) ? logAnalyticsWorkspaceName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    location: location
    tags: tags
  }
}

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.6.1' = {
  name: 'virtualNetwork'
  scope: rg
  params: {
    name: !empty(virtualNetworkName) ? virtualNetworkName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    addressPrefixes: [
      '10.0.0.0/16'
    ]
    subnets: [
      {
        name: 'hub'
        addressPrefix: '10.0.0.0/23'
      }
      {
        name: 'services'
        addressPrefix: '10.0.2.0/24'
      }
    ]
    location: location
    tags: tags
  }
}

module containerApps 'br/public:avm/ptn/azd/container-apps-stack:0.1.1' = {
  name: 'containerApps'
  scope: rg
  params: {
    containerAppsEnvironmentName: !empty(containerAppsEnvironmentName) ? containerAppsEnvironmentName : '${abbrs.appManagedEnvironments}${resourceToken}'
    containerRegistryName: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    logAnalyticsWorkspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
    acrAdminUserEnabled: true
    acrSku: 'Basic'
    appInsightsConnectionString: monitoring.outputs.applicationInsightsConnectionString
    daprAIInstrumentationKey: monitoring.outputs.applicationInsightsInstrumentationKey
    enableTelemetry: true
    infrastructureSubnetResourceId: virtualNetwork.outputs.subnetResourceIds[0]
    location: location
    tags: tags
    zoneRedundant: false
  }
}

output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output APPLICATIONINSIGHTS_NAME string = monitoring.outputs.applicationInsightsName
output AZURE_CONTAINER_ENVIRONMENT_NAME string = containerApps.outputs.environmentName
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerApps.outputs.registryLoginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerApps.outputs.registryName
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
