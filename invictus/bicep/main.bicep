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

// RGs
@description('The RG for Invictus resources')
param invictusRgName string
@description('The RG for Invictus Networking resources')
param invictusNetworkingRgName string
@description('The RG for Invictus Self-Hosted Agents resources')
param invictusSelfHostedAgentsRgName string

// Keyvault used to hold secrets needed for the Invictus Installation
param InstallationKeyvaultName string

param logWorkspaceResourceId string

// Network related parameters
param vnetName string
@description('VNET address space the NSG is created for in CIDR notation. E.g.: 192.168.0.0/24')
param vnetAddressSpace string
param snetContainersName string
param snetDevOpsACAName string
param snetPvtEndpointName string

param routeTableName string
param nsgName string

param pipelineSPId string = az.deployer().objectId


param resourceTags object



targetScope = 'subscription'
module invRg 'br/public:avm/res/resources/resource-group:0.4.1' = {
  name: invictusRgName
  params: {
    name: invictusRgName
    location: location
    tags: resourceTags
  }
}

module invNetworkRg 'br/public:avm/res/resources/resource-group:0.4.1' = {
  name: invictusNetworkingRgName
  params: {
    name: invictusNetworkingRgName
    location: location
    tags: resourceTags
  }
}

module invSelfHostedAgentsRg 'br/public:avm/res/resources/resource-group:0.4.1' = {
  name: invictusSelfHostedAgentsRgName
  params: {
    name: invictusSelfHostedAgentsRgName
    location: location
    tags: resourceTags
  }
}

// Keyvault used to hold secrets needed for the Invictus Installation
module invictusInstallationKeyvault 'br/public:avm/res/key-vault/vault:0.12.1' = {
  name: InstallationKeyvaultName
  scope: resourceGroup(invictusRgName)
  dependsOn: [
    invRg
  ]
  params: {
    name: InstallationKeyvaultName
    location: location
    tags: resourceTags
    sku: 'standard'
    enableRbacAuthorization: true
    diagnosticSettings: [
      {
        name: 'KeyVaultDiagnostics'
        workspaceResourceId: logWorkspaceResourceId

      }
    ]
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: [
      ]
      virtualNetworkRules: []
    }
    enableVaultForTemplateDeployment:true
    roleAssignments: [
          {
            name: guid(pipelineSPId, 'Key Vault Secrets User')
            principalId: pipelineSPId
            principalType: 'ServicePrincipal'
            roleDefinitionIdOrName: 'Key Vault Secrets User'
            description: 'Key Vault Secrets User role assignment for the pipeline service principal'
          }
    ]
  }
}



module invictusNetworking 'invictus-networking.bicep' = {
  name: 'invictus-networking'
  params: {
    location: location
    ResourceGroupName: invictusNetworkingRgName 
    nsgName: nsgName
    resourceTags: resourceTags
    routeTableName: routeTableName
    snetContainersName: snetContainersName
    snetDevOpsACAName: snetDevOpsACAName
    snetPvtEndpointName: snetPvtEndpointName
    vnetAddressSpace: vnetAddressSpace
    vnetName: vnetName
  }
}

