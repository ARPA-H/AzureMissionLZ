/*
Copyright (c) Microsoft Corporation.
Licensed under the MIT License.
*/

param containerName string
param location string
param tags object
param storageAccountName string
param storageEndpoint string
param timestamp string = utcNow('yyyyMMddhhmmss')
param userAssignedIdentityClientId string
param virtualMachineName string

var runCommands = [
  'generalizeVirtualMachine'
  'removeVirtualMachine'
  'restartVirtualMachine'
]

resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-07-01' existing = {
  name: virtualMachineName
}

resource customScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  parent: virtualMachine
  name: 'CustomScriptExtension'
  location: location
  tags: tags[?'Microsoft.Compute/virtualMachines'] ?? {}
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      timestamp: timestamp
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File Remove-AzureRunCommands.ps1 -ResourceManagerUri ${environment().resourceManager} -RunCommands ${runCommands} -UserAssignedIdentityClientId ${userAssignedIdentityClientId} -VmResourceId ${virtualMachine.id}'
      fileUris: [
        'https://${storageAccountName}.blob.${storageEndpoint}/${containerName}/Remove-AzureRunCommands.ps1'
      ]
      managedIdentity: {
        clientId: userAssignedIdentityClientId
      }
    }
  }
}
