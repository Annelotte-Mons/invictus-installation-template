using './main.bicep'

param environment = readEnvironmentVariable('INVICTUS_ENVIRONMENTPREFIX')
param invictusNetworkingRgName = readEnvironmentVariable('INVICTUS_VNET_RESOURCEGROUP_NAME')
param invictusRgName = readEnvironmentVariable('INVICTUS_RESOURCEGROUP_NAME')
param invictusSelfHostedAgentsRgName = readEnvironmentVariable('INVICTUS_SELFHOSTEDAGENTS_RESOURCEGROUP_NAME')
param location = readEnvironmentVariable('INVICTUS_LOCATION')

param InstallationKeyvaultName = readEnvironmentVariable('INVICTUS_INSTALLATION_KEYVAULT_NAME')

param logWorkspaceResourceId = readEnvironmentVariable('INVICTUS_LOGWORKSPACE_RESOURCEID')

param vnetName = readEnvironmentVariable('INVICTUS_VNET_NAME')
param routeTableName = readEnvironmentVariable('INVICTUS_VNET_ROUTETABLE_NAME')
param snetContainersName = readEnvironmentVariable('INVICTUS_VNET_SUBNET_CONTAINERAPPENVIRONMENT_NAME')
param snetDevOpsACAName = readEnvironmentVariable('INVICTUS_VNET_SUBNET_DEVOPSAGENTS_NAME')
param snetPvtEndpointName = readEnvironmentVariable('INVICTUS_VNET_SUBNET_PRIVATEENDPOINTS_NAME')
param vnetAddressSpace = readEnvironmentVariable('INVICTUS_VNET_ADDRESSSPACE')
param nsgName = readEnvironmentVariable('INVICTUS_VNET_NSG_NAME')
param nvaIp = readEnvironmentVariable('INVICTUS_VNET_NVA_IP')

param resourceTags = {
  applicationname: readEnvironmentVariable('PROJECTNAME')
  description: 'invictus networking resources'
}
