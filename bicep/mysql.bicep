targetScope='resourceGroup'

param prefix string
param location string
param password string
param username string
param myip string
@description('Azure database for MySQL sku name ')
param skuname string = 'GP_Gen5_2'
@description('Azure database for MySQL Sku Size ')
param skusizemb int = 5120
@description('Azure database for MySQL compute capacity in vCores (2,4,8,16,32)')
param skuCapacity int = 2

resource vnet 'Microsoft.Network/virtualNetworks@2020-08-01' existing = {
  name: prefix
}

resource mysql 'Microsoft.DBforMySQL/servers@2017-12-01' = {
  name: prefix
  location: location
  sku: {
    name: skuname
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: skuCapacity
    size: '${skusizemb}' //string expected here
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    createMode: 'Default'
    administratorLogin: username
    administratorLoginPassword: password
    storageProfile: {
      storageMB: skusizemb
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
      storageAutogrow: 'Enabled'
    }
    version: '5.7'
    sslEnforcement: 'Enabled'
    minimalTlsVersion: 'TLSEnforcementDisabled'
    infrastructureEncryption: 'Disabled'
    publicNetworkAccess: 'Enabled'
  }
  resource virtualNetworkRule 'virtualNetworkRules@2017-12-01' = {
    name: prefix
    properties: {
      virtualNetworkSubnetId: '${vnet.id}/subnets/${prefix}'
      ignoreMissingVnetServiceEndpoint: false
    }
  }
}

// resource mysqlfwRule1 'Microsoft.DBforMySQL/servers/firewallRules@2017-12-01' = {
//   parent: mysql
//   name: 'AllowAllWindowsAzureIps'
//   properties: {
//     startIpAddress: '0.0.0.0'
//     endIpAddress: '0.0.0.0'
//   }
// }

resource mysqlfwRule2 'Microsoft.DBforMySQL/servers/firewallRules@2017-12-01' = {
  parent: mysql
  name: 'MyIp'
  properties: {
    startIpAddress: myip
    endIpAddress: myip
  }
}

resource database 'Microsoft.DBforMySQL/servers/databases@2017-12-01' = {
  name: 'grafana'
  parent: mysql
  properties: {
    charset: 'latin1'
    //collation: 'string'
  }
}
