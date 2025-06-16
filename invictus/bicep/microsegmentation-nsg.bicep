@description('NSG name')
param nsgName string
param resourceTags object

param location string = resourceGroup().location

//Network related parameters
@description('VNET address space the NSG is created for in CIDR notation. E.g.: 192.168.0.0/24')
param vNetAddressSpace string

@description('An array of subnet objects. Each object must have the following properties: name[string], addressPrefix[string].')
@minLength(1)
@maxLength(100)
param subnets array
@description('An array of nsg rule objects. Mandatory properties are: name, protocol, access, direction, sourcePortRange(s), destinationPortRange(s), sourceAddressPrefix(es), destionationAddressPrefix(es). Rule priority value is auto-generated.')
param nsgRules array = []

var denyFromVnetRulePriority = 4050
var priorityGap = 25

var denyLateralMovementRule = {
  name: 'deny-lateral-movement'
  properties: {
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRanges: [
      '22'
      '135'
      '445'
      '3389'
      '5985'
      '5986'
    ]
    sourceAddressPrefix: vNetAddressSpace
    destinationAddressPrefix: vNetAddressSpace
    access: 'Deny'
    priority: denyFromVnetRulePriority - (length(subnets) + 1) * priorityGap
    direction: 'Inbound'
  }
}
var denyFromVnetRule = {
  name: 'deny-from-vnet'
  properties: {
    protocol: '*'
    sourcePortRange: '*'
    destinationPortRange: '*'
    sourceAddressPrefix: vNetAddressSpace
    destinationAddressPrefix: vNetAddressSpace
    access: 'Deny'
    priority: denyFromVnetRulePriority
    direction: 'Inbound'
  }
}
var allowInSubnetRules = [
  for (subnet, i) in subnets: {
    name: 'allow-inside-${subnet.name}'
    properties: {
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: subnet.addressPrefix
      destinationAddressPrefix: subnet.addressPrefix
      access: 'Allow'
      priority: denyFromVnetRulePriority - ((i + 1) * priorityGap)
      direction: 'Inbound'
    }
  }
]
var nsgRulesPrioritized = [
  for (nsgRule, i) in nsgRules: {
    name: '${nsgRule.name}'
    properties: {
      protocol: nsgRule.protocol
      sourcePortRange: nsgRule.?sourcePortRange == null ? '' : nsgRule.sourcePortRange
      sourcePortRanges: nsgRule.?sourcePortRanges == null ? [] : nsgRule.sourcePortRanges
      destinationPortRange: nsgRule.?destinationPortRange == null ? '' : nsgRule.destinationPortRange
      destinationPortRanges: nsgRule.?destinationPortRanges == null ? [] : nsgRule.destinationPortRanges
      sourceAddressPrefix: nsgRule.?sourceAddressPrefix == null ? '' : nsgRule.sourceAddressPrefix
      sourceAddressPrefixes: nsgRule.?sourceAddressPrefixes == null ? [] : nsgRule.sourceAddressPrefixes
      destinationAddressPrefix: nsgRule.?destinationAddressPrefix == null ? '' : nsgRule.destinationAddressPrefix
      destinationAddressPrefixes: nsgRule.?destinationAddressPrefixes == null ? [] : nsgRule.destinationAddressPrefixes
      access: nsgRule.access
      priority: (denyFromVnetRulePriority - priorityGap - (length(subnets) * 25)) - ((length(nsgRules) - i) * priorityGap)
      direction: nsgRule.direction
    }
  }
]

var nsgRulesCombined = union(nsgRulesPrioritized, [denyLateralMovementRule], allowInSubnetRules, [denyFromVnetRule])

module nsg 'br:mcr.microsoft.com/bicep/avm/res/network/network-security-group:0.3.0' = {
  name: '${uniqueString(deployment().name, location)}-${nsgName}'
  params: {
    name: nsgName
    location: location
    tags: resourceTags
    securityRules: nsgRulesCombined
    enableTelemetry: false
  }
}

@description('The resource ID of the network security group.')
output resourceId string = nsg.outputs.resourceId

@description('The name of the network security group.')
output name string = nsg.name

@description('The location the resource was deployed into.')
output location string = nsg.outputs.location
