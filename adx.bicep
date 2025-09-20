@description('Location for all resources.')
param location string

@description('The resource ID of the Event Hub to connect to.')
param eventHubResourceId string

@description('The name of the Event Hub consumer group for ADX.')
param adxConsumerGroup string

var adxClusterName = 'winlog-${uniqueString(resourceGroup().id)}'
var adxDatabaseName = 'db-winlog'
var dataConnectionName = 'dc-winlog-events'

var defaultTableName = 'Events'
var defaultMappingName = 'Events_Mapping'
var kqlScriptName = 'create-tables-and-mappings'

@description('Role definition ID for the "Azure Event Hubs Data Receiver" role.')
var eventHubsDataReceiverRoleId = 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde'

var eventHubNamespaceName = split(eventHubResourceId, '/')[8]

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' existing = {
  name: eventHubNamespaceName
}

resource adxCluster 'Microsoft.Kusto/clusters@2024-04-13' = {
  name: adxClusterName
  location: location
  sku: {
    name: 'Dev(No SLA)_Standard_D11_v2'
    tier: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enableStreamingIngest: true
  }
}
resource adxDatabase 'Microsoft.Kusto/clusters/databases@2024-04-13' = {
  parent: adxCluster
  name: adxDatabaseName
  location: location
  kind: 'ReadWrite'
}
resource kqlScript 'Microsoft.Kusto/clusters/databases/scripts@2024-04-13' = {
  parent: adxDatabase
  name: kqlScriptName
  properties: {
    #disable-next-line use-secure-value-for-secure-inputs
    scriptContent: loadTextContent('script.kql')
    continueOnErrors: false
  }
}
resource adxRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: eventHubNamespace
  name: guid(adxCluster.id, eventHubResourceId, eventHubsDataReceiverRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', eventHubsDataReceiverRoleId)
    principalId: adxCluster.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource dataConnection 'Microsoft.Kusto/clusters/databases/dataConnections@2024-04-13' = {
  parent: adxDatabase
  name: dataConnectionName
  location: location
  kind: 'EventHub'
  properties: {
    eventHubResourceId: eventHubResourceId
    consumerGroup: adxConsumerGroup
    tableName: defaultTableName
    dataFormat: 'MULTIJSON'
    mappingRuleName: defaultMappingName
    managedIdentityResourceId: adxCluster.id
  }
  dependsOn: [
    adxRoleAssignment
    kqlScript
  ]
}

output adxClusterUri string = adxCluster.properties.uri
output adxDatabaseName string = adxDatabase.name
