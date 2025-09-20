@description('Location for resources')
param location string = resourceGroup().location

@description('The admin password for the VM. This is a secure parameter.')
@secure()
param adminPassword string

@description('The permitted public IP address for RDP access')
param allowedIP string

@description('DNS label prefix for the public IP for the Workstation')
param dnsLabelPrefixWorkstation string = 'win-work-${uniqueString(resourceGroup().id)}'

@description('DNS label prefix for the public IP for the Domain Controller')
param dnsLabelPrefixDc string = 'win-dc-${uniqueString(resourceGroup().id)}'

@description('Name of the Windows workstaiton VM')
param vmWorkstationName string

@description('Name of the Windows Domain Controller VM')
param vmDcName string

@description('The size of the virtual machine')
param vmSize string

@description('The admin username for the VM')
param adminUser string

module network 'network.bicep' = {
  name: 'networkDeployment'
  params: {
    location: location
    dnsLabelPrefixWorkstation: dnsLabelPrefixWorkstation
    dnsLabelPrefixDc: dnsLabelPrefixDc
    allowedIP: allowedIP
  }
}

module events 'events.bicep' = {
  name: 'eventHubDeployment'
  params: {
    location: location
  }
}

module adx 'adx.bicep' = {
  name: 'adxDeployment'
  params: {
    location: location
    eventHubResourceId: events.outputs.eventHubResourceId
    adxConsumerGroup: events.outputs.adxConsumerGroupName
  }
}

module vm 'vm.bicep' = {
  name: 'vmDeployment'
  params: {
    location: location
    vmWorkstationName: vmWorkstationName
    vmDcName: vmDcName
    vmSize: vmSize
    adminUser: adminUser
    adminPassword: adminPassword
    nicIdWorkstation: network.outputs.nicWorkstationId
    nicIdDc: network.outputs.nicDcId
    eventHubResourceId: events.outputs.eventHubResourceId
  }
}

output vmId string = vm.outputs.vmId
output vmDcId string = vm.outputs.vmDcId
output publicIpFqdnWorkstation string = network.outputs.publicIpFqdnWorkstation
output publicIpFqdnDc string = network.outputs.publicIpFqdnDc

output adxClusterUri string = adx.outputs.adxClusterUri
output adxDatabaseName string = adx.outputs.adxDatabaseName
