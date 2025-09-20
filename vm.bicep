@description('Location for all resources.')
param location string

@description('Name for the Windows workstation VM.')
param vmWorkstationName string

@description('Name for the Windows Domain Controller VM.')
param vmDcName string

@description('The size of the virtual machine.')
param vmSize string

@description('The admin username for the virtual machine.')
param adminUser string

@description('The admin password for the virtual machine. This is a secure parameter.')
@secure()
param adminPassword string

@description('The resource ID of the network interface to attach to the Workstation VM.')
param nicIdWorkstation string

@description('The resource ID of the network interface to attach to the Domain Controller VM.')
param nicIdDc string

@description('The resource ID of the Event Hub for the DCR destination.')
param eventHubResourceId string

// Role Definition ID for 'Azure Event Hubs Data Sender'
var eventHubsDataSenderRoleId = '2b629674-e913-4c01-ae53-ef4638d8f975'

// Create a symbolic reference to the existing Event Hub to use as a scope for the role assignment
var eventHubInfo = split(eventHubResourceId, '/')
var eventHubNamespaceName = eventHubInfo[8]
var eventHubName = eventHubInfo[10]

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' existing = {
  name: '${eventHubNamespaceName}/${eventHubName}'
}

var workstationSetupUri = 'https://raw.githubusercontent.com/smashtitle/TelForge/refs/heads/main/setup_workstation.ps1'
var dcrName = 'dcr-win-events-${uniqueString(resourceGroup().id)}'

resource winWorkstation 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmWorkstationName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmWorkstationName
      adminUsername: adminUser
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'windows-11'
        sku: 'win11-23h2-pro'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicIdWorkstation
        }
      ]
    }
  }
}

resource winDc 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmDcName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmDcName
      adminUsername: adminUser
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicIdDc
        }
      ]
    }
  }
}

resource setupWorkstation 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  parent: winWorkstation
  name: 'setupWorkstation'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        workstationSetupUri
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Bypass -File setup_workstation.ps1'
    }
  }
  dependsOn: [
    installAmaWorkstation
  ]
}

resource installAmaWorkstation 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  parent: winWorkstation
  name: 'AzureMonitorWindowsAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}

resource installAmaDc 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  parent: winDc
  name: 'AzureMonitorWindowsAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}

resource dcr 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: dcrName
  location: location
  kind: 'AgentDirectToStore'
  properties: {
    dataSources: {
      windowsEventLogs: [
        {
          name: 'windowsEventLogs'
          streams: [
            'Microsoft-Event'
          ]
          xPathQueries: [
            'Security!*'
            'System!*[System[(EventID=12 or EventID=1102 or EventID=4698)]]'
            'Application/RPCFW!*'
            'Microsoft-Windows-Sysmon/Operational!*'
            'Microsoft-Windows-RPC-Events/Operational!*'
            'Microsoft-Windows-WMI-Activity/Operational!*[System[(EventID=5860 or EventID=5861)]]'
            'Microsoft-Windows-TaskScheduler/Operational!*[System[(EventID=106 or EventID=140 or EventID=141 or EventID=200)]]'
            'Microsoft-Windows-SMBServer/Operational!*[System[(EventID=1003 or EventID=1005)]]'
            'Microsoft-Windows-SMBClient/Security!*[System[(EventID=31013 or EventID=31014 or EventID=31017)]]'
            'Microsoft-Windows-PowerShell/Operational!*[System[(EventID=4103 or EventID=4104)]]'
            'Microsoft-Windows-LSA/Operational!*[System[(EventID=5004)]]'
            'Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational!*[System[(EventID=1149)]]'
            'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational!*[System[(EventID=21 or EventID=22 or EventID=24 or EventID=25)]]'
            'Microsoft-Windows-CodeIntegrity/Operational!*[System[(EventID=3065 or EventID=3066)]]'
            'Microsoft-Windows-WinRM/Operational!*[System[(EventID=6 or EventID=81 or EventID=91 or EventID=169 or EventID=224)]]'
          ]
        }
      ]
    }
    destinations: {
      eventHubsDirect: [
        {
          name: 'myEH'
          eventHubResourceId: eventHubResourceId
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-Event'
        ]
        destinations: [
          'myEH'
        ]
      }
    ]
  }
}

resource workstationSenderPermission 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(winWorkstation.id, eventHub.id, eventHubsDataSenderRoleId)
  scope: eventHub
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', eventHubsDataSenderRoleId)
    principalId: winWorkstation.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource dcSenderPermission 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(winDc.id, eventHub.id, eventHubsDataSenderRoleId)
  scope: eventHub
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', eventHubsDataSenderRoleId)
    principalId: winDc.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource dcrAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = {
  scope: winWorkstation
  name: 'dcr-association-workstation'
  properties: {
    dataCollectionRuleId: dcr.id
  }
  dependsOn: [
    installAmaWorkstation
    workstationSenderPermission
  ]
}

resource dcrAssociationDc 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = {
  scope: winDc
  name: 'dcr-association-dc'
  properties: {
    dataCollectionRuleId: dcr.id
  }
  dependsOn: [
    installAmaDc
    dcSenderPermission
  ]
}

output vmId string = winWorkstation.id
output vmDcId string = winDc.id

output workstationPrincipalId string = winWorkstation.identity.principalId
output dcPrincipalId string = winDc.identity.principalId
