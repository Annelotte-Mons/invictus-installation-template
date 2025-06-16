@allowed([
  'westeurope'
  'northeurope'
  'germanynorth'
  'germanywestcentral'
])
param location string
@allowed([
  'd'
  't'
  'a'
  'p'
])

//Network related parameters
param ResourceGroupName string
param vnetName string
@description('VNET address space the NSG is created for in CIDR notation. E.g.: 192.168.0.0/24')
param vnetAddressSpace string

param snetContainersName string
param snetDevOpsACAName string
param snetPvtEndpointName string

param routeTableName string
param nsgName string

param privateDnsZonesToDeploy array = [
  'privatelink.azurecr.io'
  'privatelink.blob.core.windows.net'
  'privatelink.file.core.windows.net'
  'privatelink.mongo.cosmos.azure.com'
  'privatelink.queue.core.windows.net'
  'privatelink.servicebus.windows.net'
  'privatelink.table.core.windows.net'
  'privatelink.table.cosmos.azure.com'
  'privatelink.vaultcore.azure.net'
  'privatelink.germanywestcentral.azurecontainerapps.io'
]

param resourceTags object

// Subnets configuration
var subnets = [
  {
    name: snetContainersName
    addressPrefix: cidrSubnet(vnetAddressSpace, 24, 0) // /24 (256 IPs)
    delegations: [
      {
        name: 'containerenvsdel'
        properties: {
          serviceName: 'Microsoft.App/environments'
        }
      }
    ]
    serviceEndpoints: [
      {
        service: 'Microsoft.AzureCosmosDB'
        locations: [location]
      }
            {
        service: 'Microsoft.EventHub'
        locations: [location]
      }
            {
        service: 'Microsoft.KeyVault'
        locations: [location]
      }
            {
        service: 'Microsoft.ServiceBus'
        locations: [location]
      }
            {
        service: 'Microsoft.Storage'
        locations: [location]
      }
    ]
  }
  {
    name: snetPvtEndpointName
    addressPrefix: cidrSubnet(vnetAddressSpace, 26, 4) // 26 (64 IPs)
    serviceEndpoints: [
      {
        service: 'Microsoft.AzureCosmosDB'
        locations: [location]
      }
            {
        service: 'Microsoft.EventHub'
        locations: [location]
      }
            {
        service: 'Microsoft.KeyVault'
        locations: [location]
      }
            {
        service: 'Microsoft.ServiceBus'
        locations: [location]
      }
            {
        service: 'Microsoft.Storage'
        locations: [location]
      }
    ]
  }
  {
    name: snetDevOpsACAName
    addressPrefix: cidrSubnet(vnetAddressSpace, 27, 10) // 27 (32 IPs)
    delegations: [
      {
        name: 'containerenvsdel'
        properties: {
          serviceName: 'Microsoft.App/environments'
        }
      }
    ]
  }
]

targetScope = 'subscription'
resource vnetRG 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: ResourceGroupName
}

module vnet 'br:mcr.microsoft.com/bicep/avm/res/network/virtual-network:0.2.0' = {
  name: vnetName
  scope: resourceGroup(vnetRG.name)
  params: {
    name: vnetName
    location: location
    tags: resourceTags
    addressPrefixes: array(vnetAddressSpace)
    dnsServers: null // No custom DNS servers
    subnets: [
      for subnet in subnets: {
        name: subnet.name
        addressPrefix: subnet.addressPrefix
        routeTableResourceId: rt.outputs.resourceId
        networkSecurityGroupResourceId: nsg.outputs.resourceId
        serviceEndpoints: subnet.?serviceEndpoints ?? []
        delegations: subnet.?delegations ?? []
      }
    ]
  }
}

/*
* NSG
*/
module nsg './microsegmentation-nsg.bicep' = {
  name: nsgName
  scope: resourceGroup(vnetRG.name)
  params: {
    nsgName: nsgName
    subnets: subnets
    location: location
    vNetAddressSpace: vnetAddressSpace
    resourceTags: resourceTags
    nsgRules: [
      // Allow ACA workloads of Invictus to communicate to ACR
      {
        name: 'allow-aca-outbound-acr'
        access: 'Allow'
        protocol: 'Tcp'
        direction: 'Outbound'
        sourceAddressPrefix: subnets[0].addressPrefix // ACA subnet
        sourcePortRange: '*'
        destinationAddressPrefix: subnets[1].addressPrefix
        destinationPortRange: '*'
      }
      // Allow ACA workloads of Invictus to communicate to private endpoints
      {
        name: 'allow-aca-into-pe-subnet'
        access: 'Allow'
        protocol: 'Tcp'
        direction: 'Inbound'
        sourceAddressPrefix: subnets[0].addressPrefix
        sourcePortRange: '*'
        destinationAddressPrefix: subnets[1].addressPrefix
        destinationPortRange: '*'
      }
      {
        name: 'allow-self-hosted-agents-into-pe-subnet'
        access: 'Allow'
        protocol: 'Tcp'
        direction: 'Inbound'
        sourceAddressPrefix: subnets[2].addressPrefix
        sourcePortRange: '*'
        destinationAddressPrefix: subnets[1].addressPrefix
        destinationPortRange: '*'
      }
    ]
  }
}

/*
* Route table
*/
module rt 'br/public:avm/res/network/route-table:0.3.0' = {
  name: '${uniqueString(deployment().name, location)}-${routeTableName}'
  scope: resourceGroup(vnetRG.name)
  params: {
    name: routeTableName
    tags: resourceTags
    location: location
    routes: [

      {
        name: 'AzureActiveDirectory'
        properties: {
          addressPrefix: 'AzureActiveDirectory'
          nextHopType: 'Internet'
        }
      }
      {
        name: 'AzureBackup'
        properties: {
          addressPrefix: 'AzureBackup'
          nextHopType: 'Internet'
        }
      }
      {
        name: 'AzureMonitor'
        properties: {
          addressPrefix: 'AzureMonitor'
          nextHopType: 'Internet'
        }
      }
      {
        name: 'AzureUpdateDelivery'
        properties: {
          addressPrefix: 'AzureUpdateDelivery'
          nextHopType: 'Internet'
        }
      }
      {
        name: 'GuestAndHybridManagement'
        properties: {
          addressPrefix: 'GuestAndHybridManagement'
          nextHopType: 'Internet'
        }
      }
      {
        name: 'MicrosoftCloudAppSecurity'
        properties: {
          addressPrefix: 'MicrosoftCloudAppSecurity'
          nextHopType: 'Internet'
        }
      }
      {
        name: 'WindowsVirtualDesktop'
        properties: {
          addressPrefix: 'WindowsVirtualDesktop'
          nextHopType: 'Internet'
        }
      }
      {
        name: 'ApiManagement'
        properties: {
          addressPrefix: 'ApiManagement'
          nextHopType: 'Internet'
        }
      }
      {
        name: 'AzureKMS1'
        properties: {
          addressPrefix: '20.118.99.224/32'
          nextHopType: 'Internet'
        }
      }
      {
        name: 'AzureKMS2'
        properties: {
          addressPrefix: '40.83.235.53/32'
          nextHopType: 'Internet'
        }
      }
      {
        name: 'Sql'
        properties: {
          addressPrefix: 'Sql'
          nextHopType: 'Internet'
        }
      }
    ]
  }
}

// Deploy private DNS zones
module privateDnsZones 'br/public:avm/res/network/private-dns-zone:0.2.0' = [
  for zone in privateDnsZonesToDeploy: {
    name: zone
    scope: resourceGroup(vnetRG.name)
    params: {
      name: zone
      location: 'global'
      tags: resourceTags
    }
  }
]
