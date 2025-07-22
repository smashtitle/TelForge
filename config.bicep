@description('Resource Group for all resources')
var rgName = 'artifact-rg'
output rgName string = rgName

@description('Location for all resources')
var location = resourceGroup().location
output location string = location

@description('Storage Account that will house artifacts following ingestion and selection')
var storageAccountName = 'storageacct${uniqueString(resourceGroup().id)}'
output storageAccountName string = storageAccountName

@description('Admin username for all VMs')
var adminUser = 'azureuser'
output adminUser string = adminUser

@description('Admin password for all VMs')
var adminPassword = 'ArtifactVaultPasswordQHGKLS9'
output adminPass string = adminPassword

@description('IP address allowed to connect to VMs')
var allowedIP = '98.45.24.0/24'
output allowedIP string = allowedIP

@description('SKU for the Windows VM')
var vmSize = 'Standard_B2als_v2'
output vmSize string = vmSize

@description('Event Hub connection string')
var ehConnString = ''
output ehConnString string = ehConnString
