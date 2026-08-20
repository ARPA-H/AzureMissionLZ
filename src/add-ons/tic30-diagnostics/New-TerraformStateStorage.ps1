#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#Requires -Version 7.0

<#
.SYNOPSIS
    Bootstraps the Azure Storage backend used for TIC 3.0 Terraform remote state.
.DESCRIPTION
    Creates (idempotently) the resource group, storage account, and blob container that
    back the `azurerm` Terraform backend used by the deploy-tic30-diagnostics.yml workflow.
    Secures the storage account with TLS 1.2, HTTPS-only, no public blob access, and blob
    versioning/soft delete so accidental state overwrites or deletes can be recovered.

    After running, copy the printed values into the repository secrets:
    TF_STATE_RESOURCE_GROUP, TF_STATE_STORAGE_ACCOUNT, TF_STATE_CONTAINER.
.PARAMETER ResourceGroupName
    Name of the resource group that will hold the Terraform state storage account.
.PARAMETER StorageAccountName
    Globally unique storage account name (lowercase letters and numbers, 3-24 characters).
.PARAMETER ContainerName
    Blob container name used as the Terraform state container.
.PARAMETER Location
    Azure region for the resource group and storage account.
.PARAMETER SubscriptionId
    Optional subscription ID to target. Uses the current az CLI context if omitted.
.EXAMPLE
    ./New-TerraformStateStorage.ps1 -ResourceGroupName 'rg-tic30-tfstate' -StorageAccountName 'sttic30tfstateusc'
.NOTES
    Requires the Azure CLI (az) to be installed and logged in with sufficient privileges
    to create resource groups, storage accounts, and blob containers.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9]{3,24}$')]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ContainerName = 'tfstate',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Location = 'centralus',

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId
)

$ErrorActionPreference = 'Stop'

#region Functions

function Assert-AzCliLogin {
    <#
    .SYNOPSIS
        Verifies the Azure CLI is installed and an active login session exists.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    if (-not (Get-Command -Name 'az' -ErrorAction SilentlyContinue)) {
        throw 'Azure CLI (az) was not found on PATH. Install it before running this script.'
    }

    az account show --output none 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw 'No active Azure CLI login found. Run "az login" before running this script.'
    }
}

function New-TerraformStateResourceGroup {
    <#
    .SYNOPSIS
        Creates the resource group for Terraform state storage if it does not already exist.
    .OUTPUTS
        [void]
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Location
    )

    $existing = az group show --name $Name --output json 2>$null
    if ($LASTEXITCODE -eq 0 -and $existing) {
        Write-Host "Resource group '$Name' already exists." -ForegroundColor Yellow
        return
    }

    Write-Host "Creating resource group '$Name' in '$Location'..." -ForegroundColor Cyan
    az group create --name $Name --location $Location --output none
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create resource group '$Name'."
    }
}

function New-TerraformStateStorageAccount {
    <#
    .SYNOPSIS
        Creates a hardened storage account for Terraform state if it does not already exist.
    .OUTPUTS
        [void]
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [string]$Location
    )

    $existing = az storage account show --name $Name --resource-group $ResourceGroupName --output json 2>$null
    if ($LASTEXITCODE -eq 0 -and $existing) {
        Write-Host "Storage account '$Name' already exists." -ForegroundColor Yellow
        return
    }

    Write-Host "Creating storage account '$Name'..." -ForegroundColor Cyan
    az storage account create `
        --name $Name `
        --resource-group $ResourceGroupName `
        --location $Location `
        --sku 'Standard_LRS' `
        --kind 'StorageV2' `
        --min-tls-version 'TLS1_2' `
        --https-only true `
        --allow-blob-public-access false `
        --output none
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create storage account '$Name'."
    }

    Write-Host "Enabling blob versioning and soft delete on '$Name'..." -ForegroundColor Cyan
    az storage account blob-service-properties update `
        --account-name $Name `
        --resource-group $ResourceGroupName `
        --enable-versioning true `
        --enable-delete-retention true `
        --delete-retention-days 30 `
        --output none
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to configure blob versioning/soft delete on '$Name'."
    }
}

function New-TerraformStateContainer {
    <#
    .SYNOPSIS
        Creates the Terraform state blob container if it does not already exist.
    .OUTPUTS
        [void]
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$StorageAccountName
    )

    $existing = az storage container show --name $Name --account-name $StorageAccountName --auth-mode login --output json 2>$null
    if ($LASTEXITCODE -eq 0 -and $existing) {
        Write-Host "Container '$Name' already exists." -ForegroundColor Yellow
        return
    }

    Write-Host "Creating container '$Name'..." -ForegroundColor Cyan
    az storage container create --name $Name --account-name $StorageAccountName --auth-mode login --output none
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create container '$Name'. Ensure you have the 'Storage Blob Data Contributor' role on '$StorageAccountName'."
    }
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Assert-AzCliLogin

        if ($SubscriptionId) {
            Write-Host "Setting active subscription to '$SubscriptionId'..." -ForegroundColor Cyan
            az account set --subscription $SubscriptionId
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to set subscription '$SubscriptionId'."
            }
        }

        New-TerraformStateResourceGroup -Name $ResourceGroupName -Location $Location
        New-TerraformStateStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName -Location $Location
        New-TerraformStateContainer -Name $ContainerName -StorageAccountName $StorageAccountName

        Write-Host "`n✅ Terraform state storage is ready." -ForegroundColor Green
        Write-Host 'Set these as GitHub repository secrets:' -ForegroundColor Green
        Write-Host "  TF_STATE_RESOURCE_GROUP   = $ResourceGroupName"
        Write-Host "  TF_STATE_STORAGE_ACCOUNT  = $StorageAccountName"
        Write-Host "  TF_STATE_CONTAINER        = $ContainerName"
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "New-TerraformStateStorage failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main Execution
