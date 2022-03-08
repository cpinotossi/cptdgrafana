targetScope='resourceGroup'

param prefix string
param location string

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: prefix
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/8'
      ]
    }
    subnets: [
      {
        name: prefix
        properties: {
          addressPrefix: '10.0.0.0/24'
          delegations: []
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          networkSecurityGroup:{
            id: nsg.id
          }
          serviceEndpoints:[
            {
              service: 'Microsoft.Storage'
              locations:[
                location
              ]
            }
            {
              //Overview of possible values for Service Endpoint: https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-service-endpoints-overview
              service: 'Microsoft.Sql' 
              locations:[
                location
              ]
            }
          ]
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          delegations: []
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      // {
      //   name: 'mysql'
      //   properties: {
      //     addressPrefix: '10.0.2.0/24'
      //     delegations: []
      //     privateEndpointNetworkPolicies: 'Enabled'
      //     privateLinkServiceNetworkPolicies: 'Enabled'
      //     serviceEndpoints:[
      //       {
      //         //Overview of possible values for Service Endpoint: https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-service-endpoints-overview
      //         service: 'Microsoft.Sql' 
      //         locations:[
      //           location
      //         ]
      //       }
      //     ]
      //   }
      // }      
      {
        name: 'aks'
        properties: {
          addressPrefix: '10.1.0.0/16'
          delegations: []
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
    virtualNetworkPeerings: []
    enableDdosProtection: false
  }
}

resource pubipbastion 'Microsoft.Network/publicIPAddresses@2021-03-01' = {
  name: '${prefix}bastion'
  location: location
  sku: {
    name:'Standard'
  }
  properties: {
    publicIPAllocationMethod:'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2021-03-01' = {
  name: '${prefix}bastion'
  location: location
  sku: {
    name:'Standard'
  }
  properties: {
    dnsName:'${prefix}.bastion.azure.com'
    enableTunneling: true
    ipConfigurations: [
      {
        name: '${prefix}bastion'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pubipbastion.id
          }
          subnet: {
            id: '${vnet.id}/subnets/AzureBastionSubnet'
          }
        }
      }
    ]
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2020-11-01' = {
  name: prefix
  location: location
  properties: {
    securityRules: [
      {
        name: 'rdp'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 900
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
    ]
  }
}
