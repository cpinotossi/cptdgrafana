targetScope='resourceGroup'

param prefix string
param location string
param password string
param username string
param myObjectId string
param postfix string
param privateip string
@description('Optional. Custom data associated to the VM, this value will be automatically converted into base64 to account for the expected VM format.')
@secure()
param customData string = ''
param isLinux bool = true

param osDiskType string
param virtualNetworkId string
param virtualNetworkName string
param networkSecurityGroups array
param networkInterfaceConfigurations array
param publicIpAddressName string
param backendPoolName string
param backendPoolId string
param loadBalancerName string
param inboundNatPoolId string
param vmName string
param virtualMachineScaleSetName string
param singlePlacementGroup string
param instanceCount string
param instanceSize string
param scaleInPolicy object
param instanceTermincationNotificationNotBeforeTimeout string
param overprovision bool
param upgradePolicy string
param adminUsername string

@secure()
param adminPassword string

param autoScaleDefault string
param autoScaleMin string
param autoScaleMax string
param scaleOutCPUPercentageThreshold string
param durationTimeWindow string
param scaleOutInterval string
param scaleInCPUPercentageThreshold string
param scaleInInterval string
param autoscaleDiagnosticLogsWorkspaceId string
param healthExtensionProtocol string
param healthExtensionPort int
param healthExtensionRequestPath string
param autoRepairsPolicyEnabled bool
param gracePeriod string
param platformFaultDomainCount string

var storageApiVersion = '2019-06-01'
var loadBalancerId = loadBalancerName_resource.id
var backendPoolId_var = '${loadBalancerId}/backendAddressPools/${backendPoolName}'
var virtualMachineScaleSetApiVersion = '2021-04-01'
var aadLoginExtensionName = 'AADSSHLoginForLinux'
var namingInfix = toLower(substring(concat(virtualMachineScaleSetName, uniqueString(resourceGroup().id)), 0, 9))
var vmssId = vmss.id
var autoScaleResourceName_var = '${virtualMachineScaleSetName}autoscale'

resource networkSecurityGroups_name 'Microsoft.Network/networkSecurityGroups@2019-02-01' = [for item in networkSecurityGroups: {
  name: item.name
  location: location
  properties: {
    securityRules: item.rules
  }
}]

resource publicIpAddressName_resource 'Microsoft.Network/publicIPAddresses@2019-02-01' = {
  name: publicIpAddressName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource loadBalancerName_resource 'Microsoft.Network/loadBalancers@2019-02-01' = {
  name: loadBalancerName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'LoadBalancerFrontEnd'
        id: '${loadBalancerId}/frontendIPConfigurations/loadBalancerFrontEnd'
        properties: {
          publicIPAddress: {
            id: publicIpAddressName_resource.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        id: backendPoolId_var
        name: backendPoolName
      }
    ]
    inboundNatPools: [
      {
        name: 'natpool'
        id: inboundNatPoolId
        properties: {
          frontendIPConfiguration: {
            id: '${loadBalancerId}/frontendIPConfigurations/loadBalancerFrontEnd'
          }
          protocol: 'Tcp'
          frontendPortRangeStart: '50000'
          frontendPortRangeEnd: '50119'
          backendPort: '22'
        }
      }
    ]
    probes: [
      {
        name: 'tcpProbe'
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 5
          numberOfProbes: 2
          loadBalancingRules: []
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'LBRule'
        properties: {
          frontendIPConfiguration: {
            id: '${loadBalancerId}/frontendIPConfigurations/loadBalancerFrontEnd'
          }
          backendAddressPool: {
            id: backendPoolId_var
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 5
          loadDistribution: 'Default'
          probe: {
            id: '${loadBalancerId}/probes/tcpProbe'
          }
        }
      }
    ]
  }
}

resource autoScaleResourceName 'Microsoft.Insights/autoscaleSettings@2015-04-01' = {
  name: autoScaleResourceName_var
  location: location
  properties: {
    name: autoScaleResourceName_var
    targetResourceUri: vmssId
    enabled: true
    profiles: [
      {
        name: 'Profile1'
        capacity: {
          minimum: autoScaleMin
          maximum: autoScaleMax
          default: autoScaleDefault
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricNamespace: ''
              metricResourceUri: vmssId
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT${durationTimeWindow}M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: scaleOutCPUPercentageThreshold
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: scaleOutInterval
              cooldown: 'PT1M'
            }
          }
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricNamespace: ''
              metricResourceUri: vmssId
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: scaleInCPUPercentageThreshold
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: scaleInInterval
              cooldown: 'PT1M'
            }
          }
        ]
      }
    ]
  }
}

resource autoScaleResourceName_Microsoft_Insights_diagSetting_namingInfix 'Microsoft.Insights/autoscalesettings/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${autoScaleResourceName_var}/Microsoft.Insights/diagSetting${namingInfix}'
  properties: {
    workspaceId: autoscaleDiagnosticLogsWorkspaceId
    logs: [
      {
        category: 'AutoscaleEvaluations'
        enabled: true
      }
      {
        category: 'AutoscaleScaleActions'
        enabled: true
      }
    ]
  }
  dependsOn: [
    autoScaleResourceName
  ]
}

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2021-11-01' = {
  name: virtualMachineScaleSetName
  location: location
  properties: {
    singlePlacementGroup: true
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          name: '${prefix}${postfix}'
          createOption: 'FromImage'
          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
          deleteOption:'Delete'
        }
        imageReference: {
          publisher: 'Canonical'
          offer: 'UbuntuServer'
          sku: '18.04-LTS'
          version: 'latest'
        }
      }
      networkProfile: {
        networkInterfaceConfigurations: [for item in networkInterfaceConfigurations: {
          name: item.name
          properties: {
            primary: item.primary
            enableAcceleratedNetworking: item.enableAcceleratedNetworking
            ipConfigurations: [
              {
                name: '${take(item.name, (80 - length('-defaultIpConfiguration')))}-defaultIpConfiguration'
                properties: {
                  subnet: {
                    id: item.subnetId
                  }
                  primary: item.primary
                  applicationGatewayBackendAddressPools: item.applicationGatewayBackendAddressPools
                  loadBalancerBackendAddressPools: item.loadBalancerBackendAddressPools
                  publicIPAddressConfiguration: ((item.pipName == '') ? json('null') : union(json('{"name": "${item.pipName}"}'), json('{"properties": { "idleTimeoutInMinutes": 15}}')))
                  loadBalancerInboundNatPools: item.loadBalancerInboundNatPools
                }
              }
            ]
            networkSecurityGroup: ((item.nsgId == '') ? json('null') : json('{"id": "${item.nsgId}"}'))
          }
        }]
      }
      extensionProfile: {
        extensions: [
          {
            name: 'HealthExtension'
            properties: {
              publisher: 'Microsoft.ManagedServices'
              type: 'ApplicationHealthLinux'
              typeHandlerVersion: '1.0'
              autoUpgradeMinorVersion: false
              settings: {
                protocol: healthExtensionProtocol
                port: healthExtensionPort
                requestPath: healthExtensionRequestPath
              }
            }
          }
        ]
      }
      scheduledEventsProfile: {
        terminateNotificationProfile: {
          enable: true
          notBeforeTimeout: instanceTermincationNotificationNotBeforeTimeout
        }
      }
      osProfile: {
        computerNamePrefix: namingInfix
        adminUsername: adminUsername
        adminPassword: adminPassword
        customData: customData
      }
    }
    orchestrationMode: 'Uniform'
    scaleInPolicy: scaleInPolicy
    overprovision: overprovision
    upgradePolicy: {
      mode: upgradePolicy
    }
    automaticRepairsPolicy: {
      enabled: autoRepairsPolicyEnabled
      gracePeriod: gracePeriod
    }
    platformFaultDomainCount: platformFaultDomainCount
  }
  sku: {
    name: instanceSize
    capacity: int(instanceCount)
  }
  identity: {
    type: 'systemAssigned'
  }
  dependsOn: [
    networkSecurityGroups_name
    loadBalancerId
  ]
}

resource vmName_aadLoginExtensionName 'Microsoft.Compute/virtualMachineScaleSets/extensions@2021-03-01' = {
  name: '${vmName}/${aadLoginExtensionName}'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: aadLoginExtensionName
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
  dependsOn: [
    vmss
  ]
}

output adminUsername string = adminUsername
