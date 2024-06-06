param region string
param spokeIndex int 
param hubVnetName string = 'hub-vnet'
param hubVnetRGName string = 'hub-spoke-rg'

var spokeVnetName = 'spoke-${spokeIndex}-vnet'
var spokeAdressPrefix = '10.${spokeIndex}.0.0/16'
var spokeDefaultSubnetPrefix = '10.${spokeIndex}.0.0/24'

resource hubVnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: hubVnetName
  scope: resourceGroup(hubVnetRGName)
}

resource spokeVnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: spokeVnetName
  location: region
  properties: {
    addressSpace: {
      addressPrefixes: [ spokeAdressPrefix ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: spokeDefaultSubnetPrefix
        }
      }
    ]
  }
}

resource peering2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  name: 'peering-spoke-${spokeIndex}-to-hub'
  parent: spokeVnet
  properties: {
    allowForwardedTraffic: true
    allowVirtualNetworkAccess: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hubVnet.id
    }
  }
}

module perring1 'hubpeering.bicep' = {
  name: 'hubpeering'
  scope: resourceGroup(hubVnetRGName)
  params: {
    hubVnetName: hubVnetName
    spokeVnetName: spokeVnetName
    spokeVnetId: spokeVnet.id
  }
}
