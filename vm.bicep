module config './config.bicep' = {
  name: 'configModule'
}

@description('Name of the virtual machine.')
param vmWorkstationName string

@description('Size of the virtual machine.')
param vmSize string = 'Standard_B2s'

@description('Location for all resources.')
param location string

@description('Unique DNS Name for the Public IP used to access the Virtual Machine.')
param dnsLabelPrefix string = toLower('${vmWorkstationName}-${uniqueString(resourceGroup().id, vmWorkstationName)}')

@description('Name for the Public IP used to access the Virtual Machine.')
param publicIpName string = 'myPublicIP'

@description('Allocation method for the Public IP used to access the Virtual Machine.')
param publicIPAllocationMethod string = 'Static'

@description('SKU for the Public IP used to access the Virtual Machine.')
param publicIpSku string = 'Standard'

var nicName = 'myVMNIC'
var addressPrefix = '10.0.0.0/16'
var subnetName = 'Subnet'
var subnetPrefix = '10.0.0.0/24'
var virtualNetworkName = 'MyVNET'
var networkSecurityGroupName = 'default-NSG'


resource publicIp 'Microsoft.Network/publicIPAddresses@2024-07-01' = {
  name: publicIpName
  location: location
  sku: {
    name: publicIpSku
  }
  properties: {
    publicIPAllocationMethod: publicIPAllocationMethod
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'default-allow-3389'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '3389'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-07-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
          }
        }
      }
    ]
  }
  dependsOn: [virtualNetwork]
}

resource winWorkstation 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: vmWorkstationName
  location: location

  identity: {type: 'SystemAssigned'}
  properties: {
    hardwareProfile: {vmSize: vmSize}
    osProfile: {
      computerName: vmWorkstationName
      adminUsername: config.outputs.adminUser
      adminPassword: config.outputs.adminPass
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'windows-11'
        sku: 'win11-24h2-pro'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'Standard_LRS' }
      }
    }
    networkProfile: {networkInterfaces: [{id: nic.id}]}
  }
}

output principalId string = winWorkstation.identity.principalId

resource amaWorkstation 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = {
  parent: winWorkstation
  name: 'AzureMonitorWindowsAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}

var setupWorkstationScript = loadTextContent('./setup_workstation.ps1')

resource setupWorkstation 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = {
  parent: winWorkstation
  name: 'setupWorkstation'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File "${setupWorkstationScript}"'
    }
  }
}

/*
resource winlogbeatWorkstation 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = {
  parent: winWorkstation
  name: 'winlogbeatWorkstation'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-9.0.3-windows-x86_64.zip'
      ]
      commandToExecute: 'powershell Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Command "Expand-Archive -Path winlogbeat-9.0.3-windows-x86_64.zip -DestinationPath C:\\Tools"; Set-Content -Path C:\\Tools\\winlogbeat-9.0.3-windows-x86_64\\winlogbeat.yml -Value $winlogbeatConfig -Encoding UTF8;'
    }
  }
}
*/

output winWorkstationID string = winWorkstation.id
output hostname string = publicIp.properties.dnsSettings.fqdn
