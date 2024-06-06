param region string
param spokeIndex int 

var spokeVnetName = 'spoke-${spokeIndex}-vnet'
var spokeAdressPrefix = '10.${spokeIndex}.0.0/16'
var spokeDefaultSubnetPrefix = '10.${spokeIndex}.0.0/24'

resource hubVnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'hub-vnet'
  location: region
  properties: {
    addressSpace: {
      addressPrefixes: [ '192.168.1.0/24' ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '192.168.1.0/26'
        }
      }
    ]
  }
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

resource peering1 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  name: 'peering-hub-to-spoke-${spokeIndex}'
  parent: hubVnet
  properties: {
    allowForwardedTraffic: true
    allowVirtualNetworkAccess: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spokeVnet.id
    }
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

