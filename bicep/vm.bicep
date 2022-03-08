targetScope='resourceGroup'

param prefix string
param location string
@secure()
param password string
param username string
param myObjectId string
param postfix string
param privateip string
@description('Optional. Custom data associated to the VM, this value will be automatically converted into base64 to account for the expected VM format.')
@secure()
param customData string = ''
@allowed([
  'windows'
  'linux'
  'nodejs'
])
param imageRef string

var imageReferences = {
  linux: {
    publisher: 'Canonical'
    offer: 'UbuntuServer'
    sku: '18.04-LTS'
    version: 'latest'
  }
  windows: {
    publisher: 'MicrosoftWindowsDesktop'
    offer: 'Windows-10'
    sku: '20h2-pro'
    version: 'latest'
  }
  nodejs: {
    publisher: 'bitnami'
    offer: 'nodejs'
    sku: '4-3'
    version: 'latest'
  }
}

var linconfig= {
  linux: {
    disablePasswordAuthentication: false
    ssh: {
      publicKeys: [
        {
          path:'/home/chpinoto/.ssh/authorized_keys'
          keyData: sshkey.properties.publicKey
        }
      ]
    }
  }
  windows: null
  nodejs: null
}

var plan={
  nodejs:{
    name:'4-3'
    publisher:'bitnami'
    product:'nodejs'
  }
  windows: null
  linux: null
}

resource vnet 'Microsoft.Network/virtualNetworks@2020-08-01' existing = {
  name: prefix
}

resource nic 'Microsoft.Network/networkInterfaces@2020-08-01' = {
  name: '${prefix}${postfix}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: '${prefix}${postfix}'
        properties: {
          privateIPAddress:privateip
          // privateIPAddress: '10.0.0.4'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: '${vnet.id}/subnets/${prefix}'
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    dnsSettings: {
      dnsServers: []
    }
    enableAcceleratedNetworking: false
    enableIPForwarding: false
  }
}

resource sshkey 'Microsoft.Compute/sshPublicKeys@2021-07-01' = {
  name: prefix
  location: location
  properties: {
    publicKey: loadTextContent('../ssh/chpinoto.pub')
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: '${prefix}${postfix}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  plan: plan[imageRef]
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    storageProfile: {
      osDisk: {
        name: '${prefix}${postfix}'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        deleteOption:'Delete'
      }
      imageReference: imageReferences[imageRef]
    }
    osProfile: {
      computerName: '${prefix}${postfix}'
      adminUsername: username
      adminPassword: password
      //customData: loadFileAsBase64('vm.yaml')
      customData: !empty(customData) ? base64(customData) : null
      linuxConfiguration: linconfig[imageRef]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties:{
            deleteOption: 'Delete'
          }
        }
      ]
    }
  }
}

resource vmaadextension 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = if (imageRef!='windows') {
  parent: vm
  name: 'AADSSHLoginForLinux'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADSSHLoginForLinux'
    typeHandlerVersion: '1.0'
  }
}

resource nwagentextension 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = if (imageRef!='windows') {
  parent: vm
  name: 'NetworkWatcherAgentLinux'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.NetworkWatcher'
    type: 'NetworkWatcherAgentLinux'
    typeHandlerVersion: '1.4'
  }
}

var roleVirtualMachineAdministratorName = '1c0163c0-47e6-4577-8991-ea5c82e286e4' //Virtual Machine Administrator Login

resource raMe2VM 'Microsoft.Authorization/roleAssignments@2018-01-01-preview' = {
  name: guid(resourceGroup().id,'raMe2VMHub')
  properties: {
    principalId: myObjectId
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions',roleVirtualMachineAdministratorName)
  }
}

// resource schedule1 'microsoft.devtestlab/schedules@2018-09-15' = {
//   name: 'shutdown-computevm-cptdgrafanagrafana'
//   location: location
//   properties: {
//     status: 'Enabled'
//     taskType: 'ComputeVmShutdownTask'
//     dailyRecurrence: {
//       time: '1900'
//     }
//     timeZoneId: 'UTC'
//     notificationSettings: {
//       status: 'Enabled'
//       timeInMinutes: 30
//       emailRecipient: 'ga@myedge.org'
//       notificationLocale: 'en'
//     }
//     targetResourceId: vm.id
//   }
// }

