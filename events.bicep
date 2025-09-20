@description('Location for all resources.')
param location string

// Globally unique name for Event Hub namespace
var eventHubNamespaceName = 'ns-winlog-${uniqueString(resourceGroup().id)}'
var eventHubName = 'winlog-events'
var authorizationRuleName = 'WinlogbeatSendRule'
var adxConsumerGroupName = 'adx-consumer'

// Create Event Hub namespace
resource eventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' = {
  name: eventHubNamespaceName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}

// Create Event Hub within namespace
resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = {
  parent: eventHubNamespace
  name: eventHubName
  properties: {
    partitionCount: 2
    messageRetentionInDays: 1
  }
}


// Create a dedicated consumer group for ADX
resource adxConsumerGroup 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2024-01-01' = {
  parent: eventHub
  name: adxConsumerGroupName
}

// Create an authz rule with 'Send' perms
resource authorizationRule 'Microsoft.EventHub/namespaces/authorizationRules@2024-01-01' = {
  parent: eventHubNamespace
  name: authorizationRuleName
  properties: {
    rights: [
      'Send'
    ]
  }
}

// Define the outputs for main.bicep
output namespaceName string = eventHubNamespace.name
output eventHubName string = eventHub.name

// --- NEW OUTPUTS ---
output eventHubResourceId string = eventHub.id
output adxConsumerGroupName string = adxConsumerGroup.name
