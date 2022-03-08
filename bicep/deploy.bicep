targetScope='resourceGroup'

var parameters = json(loadTextContent('../parameters.json'))
param location string = resourceGroup().location
param myobjectid string
param myip string
param prefix string

module vnetModule 'vnet.bicep' = {
  name: 'vnetDeploy'
  params: {
    prefix: prefix
    location: location
  }
}

module mysqlModule 'mysql.bicep' = {
  name: 'mysqlDeploy'
  params: {
    prefix: prefix
    location: location
    username: parameters.username
    password: parameters.password
    myip: myip
  }
  dependsOn:[
    vnetModule
  ]
}

module vmNodeJsModule 'vm.bicep' = {
  name: 'vmNodeJsDeploy'
  params: {
    prefix: prefix
    location: location
    username: parameters.username
    password: parameters.password
    myObjectId: myobjectid
    postfix: 'nodejs'
    privateip: '10.0.0.4'
    customData: loadTextContent('vmnodejs.yaml')
    imageRef: 'linux'
  }
  dependsOn:[
    vnetModule
  ]
}

module vmGrafanaModule 'vm.bicep' = {
  name: 'vmGrafanaDeploy'
  params: {
    prefix: prefix
    location: location
    username: parameters.username
    password: parameters.password
    myObjectId: myobjectid
    postfix: 'grafana'
    privateip: '10.0.0.5'
    customData: loadTextContent('vmgrafana.yaml')
    imageRef: 'linux'
  }
  dependsOn:[
    mysqlModule
  ]
}

module vmWinModule 'vm.bicep' = {
  name: 'vmWinDeploy'
  params: {
    prefix: prefix
    location: location
    username: parameters.username
    password: parameters.password
    myObjectId: myobjectid
    postfix: 'win'
    privateip: '10.0.0.6'
    imageRef: 'windows'
  }
  dependsOn:[
    vnetModule
  ]
}

module vmMqttModule 'vm.bicep' = {
  name: 'vmMqttDeploy'
  params: {
    prefix: prefix
    location: location
    username: parameters.username
    password: parameters.password
    myObjectId: myobjectid
    postfix: 'mqtt'
    privateip: '10.0.0.7'
    customData: loadTextContent('vmmqtt.yaml')
    imageRef: 'linux'
  }
  dependsOn:[
    vnetModule
  ]
}

module sabModule 'sab.bicep' = {
  name: 'sabDeploy'
  params: {
    prefix: prefix
    location: location
    myip: myip
    myObjectId: myobjectid
  }
  dependsOn:[
    vnetModule
  ]
}

module lawModule 'law.bicep' = {
  name: 'lawDeploy'
  params:{
    prefix: prefix
    location: location
  }
  dependsOn:[
    sabModule
  ]
}
