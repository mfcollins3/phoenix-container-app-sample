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

@description('Name of the Key Vault to be created')
param keyVaultName string = ''

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Name of the Log Analytics Workspace to be created')
param logAnalyticsWorkspaceName string = ''

@description('Email address of the owner of the Azure resources')
param ownerEmail string

@description('Login name of the PostgreSQL server administrator to be created')
param postgresAdministratorLogin string = 'postgres'

@description('Password of the PostgreSQL server administrator to be created')
@secure()
param postgresAdministratorLoginPassword string

param postgresPrivateEndpointName string = ''

@description('Name of the PostgreSQL server to be created')
param postgresServerName string = ''

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

module postgresPrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.1' = {
  name: 'postgresPrivateDnsZone'
  scope: rg
  params: {
    name: 'privatelink.postgres.database.azure.com'
    location: 'global'
    tags: tags
    virtualNetworkLinks: [
      {
        name: 'postgresPrivateDnsZoneLink'
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
        registrationEnabled: false
      }
    ]
  }
}

module postgres 'br/public:avm/res/db-for-postgre-sql/flexible-server:0.11.0' = {
  name: 'postgres'
  scope: rg
  params: {
    name: !empty(postgresServerName) ? postgresServerName : '${abbrs.dBforPostgreSQLServers}${resourceToken}'
    skuName: 'Standard_B1ms'
    tier: 'Burstable'
    administratorLogin: postgresAdministratorLogin
    administratorLoginPassword: postgresAdministratorLoginPassword
    location: location
    tags: tags
    version: '16'
    highAvailability: 'Disabled'
    geoRedundantBackup: 'Disabled'
    privateEndpoints: [
      {
        subnetResourceId: virtualNetwork.outputs.subnetResourceIds[1]
        service: 'postgresqlServer'
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: postgresPrivateDnsZone.outputs.resourceId
            }
          ]
        }
      }
    ]
  }
}

module keyVaultPrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.1' = {
  name: 'keyVaultPrivateDnsZone'
  scope: rg
  params: {
    name: 'privatelink.vaultcore.azure.net'
    location: 'global'
    tags: tags
    virtualNetworkLinks: [
      {
        name: 'keyVaultPrivateDnsZoneLink'
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
        registrationEnabled: false
      }
    ]
  }
}

module keyVault 'br/public:avm/res/key-vault/vault:0.12.1' = {
  name: 'keyVault'
  scope: rg
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}hub-${resourceToken}'
    enableRbacAuthorization: true
    privateEndpoints: [
      {
        subnetResourceId: virtualNetwork.outputs.subnetResourceIds[1]
        service: 'vault'
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: keyVaultPrivateDnsZone.outputs.resourceId
            }
          ]
        }
      }
    ]
    sku: 'standard'
    secrets: [
      {
        name: 'EctoDatabaseURL'
        value: 'ecto://${postgresAdministratorLogin}:${postgresAdministratorLoginPassword}@${postgres.outputs.name}.privatelink.postgres.database.azure.com:5432/hub-prod'
      }
    ]
    enablePurgeProtection: false
    enableSoftDelete: false
    location: location
    tags: tags
  }
}

output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output APPLICATIONINSIGHTS_NAME string = monitoring.outputs.applicationInsightsName
output AZURE_CONTAINER_ENVIRONMENT_NAME string = containerApps.outputs.environmentName
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerApps.outputs.registryLoginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerApps.outputs.registryName
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output POSTGRES_HOST string = postgres.outputs.fqdn
