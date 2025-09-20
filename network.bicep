@description('Location for all resources.')
param location string

@description('DNS label prefix for the public IP for the Windows Workstation.')
param dnsLabelPrefixWorkstation string

@description('DNS label prefix for the public IP for the Windows Domain Controller.')
param dnsLabelPrefixDc string

@description('Your public IP address or CIDR range to allow RDP and SSH access.')
param allowedIP string

// Shared network resources
var virtualNetworkName = 'vnet-${uniqueString(resourceGroup().id)}'
var subnetName = 'default-subnet'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
    ]
  }
}

// Windows Workstation network resources
var publicIpNameWorkstation = '${dnsLabelPrefixWorkstation}-pip'
var nsgNameWorkstation = 'nsg-workstation'
var nicNameWorkstation = 'nic-workstation-${uniqueString(resourceGroup().id)}'

resource publicIpWorkstation 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: publicIpNameWorkstation
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefixWorkstation
    }
  }
}

resource nsgWorkstation 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgNameWorkstation
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-rdp'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '3389'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: allowedIP
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource nicWorkstation 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: nicNameWorkstation
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.0.20'
          publicIPAddress: {
            id: publicIpWorkstation.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsgWorkstation.id
    }
  }
  dependsOn: [
    virtualNetwork
  ]
}

// Windows Domain Controller network resources
var publicIpNameDc = '${dnsLabelPrefixDc}-pip'
var nicNameDc = 'nic-dc-${uniqueString(resourceGroup().id)}'

resource publicIpDc 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: publicIpNameDc
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefixDc
    }
  }
}

resource nicDc 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: nicNameDc
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.0.10'
          publicIPAddress: {
            id: publicIpDc.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
          }
        }
      }
    ]
    // Reusing the same NSG for the DC
    networkSecurityGroup: {
      id: nsgWorkstation.id
    }
  }
  dependsOn: [
    virtualNetwork
  ]
}

output nicWorkstationId string = nicWorkstation.id
output publicIpFqdnWorkstation string = publicIpWorkstation.properties.dnsSettings.fqdn
output nicDcId string = nicDc.id
output publicIpFqdnDc string = publicIpDc.properties.dnsSettings.fqdn
