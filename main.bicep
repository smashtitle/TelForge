@description('Location for all resources')
param location string = resourceGroup().location

module config './config.bicep' = {
}

module vm './vm.bicep' = {
  name: 'vm'
  params: {
    vmWorkstationName: vmWorkstationName
    location: location
  }
}

@description('Name of Event Hub namespace')
param eventHubNamespaceName string = 'eventHub${uniqueString(resourceGroup().id)}'

@description('Name of Event Hub')
param eventHubName string = 'kustoHub'

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' = {
  name: eventHubNamespaceName
  location: location
  sku: {
    capacity: 1
    name: 'Standard'
    tier: 'Standard'
  }

  resource eventHub 'eventhubs' = {
    name: eventHubName
    properties: {
      messageRetentionInDays: 1
      partitionCount: 2
    }

    resource kustoConsumerGroup 'consumergroups' = {
      name: 'winlogbeatCG'
      properties: {}
    }
  }
}

@description('Name of the database')
param databaseName string = 'artifactdb'

@description('Name of the cluster')
param clusterName string = 'kusto${uniqueString(resourceGroup().id)}'

@description('Name of the Kusto cluster SKU')
param skuNameCluster string = 'Standard_D11_v2'

@description('# of nodes')
@minValue(2)
@maxValue(1000)
param skuCapacityCluster int = 2

resource cluster 'Microsoft.Kusto/clusters@2022-02-01' = {
  name: clusterName
  location: location
  sku: {
    name: skuNameCluster
    tier: 'Standard'
    capacity: skuCapacityCluster
  }
  identity: {
    type: 'SystemAssigned'
  }

  resource kustoDb 'databases' = {
    name: databaseName
    location: location
    kind: 'ReadWrite'

    resource kustoScript 'scripts' = {
      name: 'db-script'
      properties: {
        scriptContent: loadTextContent('script.kql')
        continueOnErrors: false
      }
    }

    resource eventConnection 'dataConnections' = {
      name: 'eventConnection'
      location: location
      dependsOn: [
        kustoScript
        clusterEventHubAuthorization
      ]
      kind: 'EventHub'
      properties: {
        compression: 'None'
        consumerGroup:  eventHubNamespace::eventHub::kustoConsumerGroup.name
        dataFormat: 'JSON'
        eventHubResourceId: eventHubNamespace::eventHub.id
        eventSystemProperties: ['x-opt-enqueued-time']
        managedIdentityResourceId: cluster.id
        mappingRuleName: 'WinlogbeatJson'
      }
    }
  }
}

var dataReceiverId = 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde'
var fullDataReceiverId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', dataReceiverId)
var eventHubRoleAssignmentName = '${resourceGroup().id}${cluster.name}${dataReceiverId}${eventHubNamespace::eventHub.name}'
var roleAssignmentName = guid(eventHubRoleAssignmentName, eventHubName, dataReceiverId, clusterName)

resource clusterEventHubAuthorization 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleAssignmentName
  scope: eventHubNamespace::eventHub
  properties: {
    description: 'Assign role Azure Event Hubs Data Receiver to the cluster'
    principalId: cluster.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: fullDataReceiverId
  }
}

resource eventHubAuthRule 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2024-01-01' = {
  parent: eventHubNamespace::eventHub
  name: 'ListenSend'
  properties: {
    rights: [
      'Listen'
      'Send'
    ]
  }
}

output connectionString string = eventHubAuthRule.listKeys().primaryConnectionString

@description('Name of the virtual machine.')
param vmWorkstationName string = 'win-work'

var winlogbeatConfig = '''
winlogbeat.event_logs:
  - name: Application
  - name: System
  - name: Security
  - name: Microsoft-Windows-Sysmon/Operational
  - name: Microsoft-Windows-RPC-Events/Operational
  - name: Microsoft-Windows-WMI-Activity/Operational
  - name: Microsoft-Windows-TaskScheduler/Operational
  - name: Microsoft-Windows-SMBServer/Operational
  - name: Microsoft-Windows-SMBClient/Security
  - name: Microsoft-Windows-LSA/Operational
  - name: Microsoft-Windows-GroupPolicy/Operational
  - name: Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational
  - name: Microsoft-Windows-TerminalServices-LocalSessionManager/Operational
  - name: Microsoft-Windows-WinRM/Operational
    event_id: 6, 81, 224
  - name: Windows PowerShell
    event_id: 400, 403, 600, 800
  - name: Microsoft-Windows-PowerShell/Operational
    event_id: 4103, 4104, 4105, 4106

processors:
  - add_host_metadata: {}
  - add_cloud_metadata: ~

output.eventhub:
  connection_string: '${connectionString}'
  eventhub: '${eventHubName}'
  namespace: '${eventHubNamespaceName}'

rocessors:
  - add_host_metadata: {}
  - add_cloud_metadata: ~

output.kafka:
  hosts: ["<NAMESPACE>.servicebus.windows.net:9093"]   # FQDN of your EH namespace
  topic: "${eventHubName}"                                   # Event Hub name
  username: "$ConnectionString"
  password: "Endpoint=sb://${eventHubNamespaceName}.servicebus.windows.net/;SharedAccessKeyName=<KeyName>;SharedAccessKey=<Key>"
  ssl.enabled: true
  sasl.mechanism: plain
  client_id: winlogbeat
  required_acks: 1
  compression: none
  version: "2.0.0"
'''

output winlogbeatConfig string = winlogbeatConfig

/*
@@@@ add parameter file for secrets mgmt
*/
