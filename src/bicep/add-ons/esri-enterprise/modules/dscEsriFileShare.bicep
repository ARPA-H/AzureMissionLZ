param arcgisServiceAccountIsDomainAccount bool
@secure()
param arcgisServiceAccountPassword string
param arcgisServiceAccountUsername string
param convertedEpoch int = dateTimeToEpoch(dateTimeAdd(utcNow(), 'P1D'))
param debugMode bool
param dscConfiguration string
param dscScript string
param enableVirtualMachineDataDisk bool
param externalDNSHostName string
param fileShareName string = 'fileshare'
param fileShareVirtualMachineName string
param location string = resourceGroup().location
param portalContext string
param storageAccountName string
param storageUriPrefix string
param tags object
@secure()
param virtualMachineAdminPassword string
param virtualMachineAdminUsername string
param virtualMachineOSDiskSize int

var dscModuleUrl = '${storageUriPrefix}DSC.zip'

var convertedDatetime = dateTimeFromEpoch(convertedEpoch)
var sasProperties = {
  signedProtocol: 'https'
  signedResourceTypes: 'sco'
  signedPermission: 'rl'
  signedServices: 'b'
  signedExpiry: convertedDatetime
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  scope: resourceGroup(subscription().subscriptionId, resourceGroup().name)
  name: storageAccountName
}

resource fileShareVirtualMachine 'Microsoft.Compute/virtualMachines@2023-03-01' existing = {
  name: fileShareVirtualMachineName
}

resource dscEsriFileShare 'Microsoft.Compute/virtualMachines/extensions@2018-06-01' = {
  parent: fileShareVirtualMachine
  name: 'DSCConfiguration'
  location: location
  tags: tags[?'Microsoft.Compute/virtualMachines'] ?? {}
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.77'
    settings: {
      wmfVersion: 'latest'
      configuration:{
        url: dscModuleUrl
        script: dscScript
        function: dscConfiguration
      }
      configurationArguments: {
         DebugMode: debugMode
         EnableDataDisk: enableVirtualMachineDataDisk
         ExternalDNSHostName: externalDNSHostName
         IsBaseDeployment: 'True'
         FileShareName: fileShareName
         OSDiskSize: virtualMachineOSDiskSize
         PortalContext: portalContext
         ServiceCredentialIsDomainAccount: arcgisServiceAccountIsDomainAccount
        }
    }
    protectedSettings: {
      configurationUrlSasToken: '?${storageAccount.listAccountSAS('2021-04-01', sasProperties).accountSasToken}'
      managedIdentity: {
        principalId: fileShareVirtualMachine.identity.principalId
        tenantId: fileShareVirtualMachine.identity.tenantId
      }
      configurationArguments: {
        ServiceCredential: {
          userName: arcgisServiceAccountUsername
          password: arcgisServiceAccountPassword
        }
        MachineAdministratorCredential: {
          userName: virtualMachineAdminUsername
          password: virtualMachineAdminPassword
        }
      }
    }
  }
}

output dscStatus string = dscEsriFileShare.properties.provisioningState
output fileShareName string = fileShareName

