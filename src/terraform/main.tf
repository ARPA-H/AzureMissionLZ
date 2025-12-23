/*
Copyright (c) Microsoft Corporation.
Licensed under the MIT License.

TIC 3.0 and Zero Trust Compliant Firewall Policy Rules - Terraform
This configuration creates comprehensive firewall rules aligned with:
- TIC 3.0 security capabilities
- Zero Trust architecture principles
- Azure Well-Architected Framework best practices
*/

terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.hub_subscription_id
}

# Data source for existing firewall policy
data "azurerm_firewall_policy" "existing" {
  name                = var.firewall_policy_name
  resource_group_name = var.hub_resource_group_name
}

# Get resource group for location
data "azurerm_resource_group" "hub" {
  name = var.hub_resource_group_name
}

# Create IP Group for spoke networks - Zero Trust boundary
resource "azurerm_ip_group" "spokes" {
  name                = "ipg-zerotrust-spokes"
  location            = data.azurerm_resource_group.hub.location
  resource_group_name = var.hub_resource_group_name
  cidrs               = var.spoke_vnet_addresses

  tags = merge(var.tags, {
    "ManagedBy"       = "Terraform"
    "Compliance"      = "TIC 3.0"
    "Architecture"    = "Zero Trust"
    "DeploymentType"  = "FirewallRules"
  })
}

# TIC 3.0 Priority 100: Baseline Security - Deny High-Risk Traffic
resource "azurerm_firewall_policy_rule_collection_group" "baseline_security" {
  name               = "TIC30-100-BaselineSecurity"
  firewall_policy_id = data.azurerm_firewall_policy.existing.id
  priority           = 100

  # Block High-Risk Web Categories
  application_rule_collection {
    name     = "BlockHighRiskCategories"
    priority = 100
    action   = "Deny"

    rule {
      name = "Block-Malicious-Categories"
      description = "TIC 3.0: Block known malicious web categories"
      
      protocols {
        type = "Http"
        port = 80
      }
      
      protocols {
        type = "Https"
        port = 443
      }

      source_addresses = ["*"]

      web_categories = [
        "Hacking",
        "Malware",
        "Phishing",
        "ProxyAvoidanceAndAnonymizers",
        "Spyware",
        "BotnetsAndZombies",
        "IllegalSoftware"
      ]
    }
  }

  # Block Insecure Protocols
  network_rule_collection {
    name     = "BlockUnencryptedProtocols"
    priority = 110
    action   = "Deny"

    rule {
      name                  = "Block-Unencrypted-Protocols"
      description           = "TIC 3.0: Block insecure legacy protocols"
      protocols             = ["TCP"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["21", "23", "69", "161", "445"] # FTP, Telnet, TFTP, SNMP, SMB
    }
  }
}

# TIC 3.0 Priority 200: Essential Azure Services
resource "azurerm_firewall_policy_rule_collection_group" "essential_services" {
  name               = "TIC30-200-EssentialServices"
  firewall_policy_id = data.azurerm_firewall_policy.existing.id
  priority           = 200

  depends_on = [azurerm_firewall_policy_rule_collection_group.baseline_security]

  # Azure Management Services
  network_rule_collection {
    name     = "AzureManagementServices"
    priority = 200
    action   = "Allow"

    rule {
      name                  = "Allow-Azure-Monitor"
      description           = "Zero Trust: Azure Monitor for observability"
      protocols             = ["TCP"]
      source_ip_groups      = [azurerm_ip_group.spokes.id]
      destination_addresses = ["AzureMonitor"]
      destination_ports     = ["443"]
    }

    rule {
      name                  = "Allow-Azure-Storage"
      description           = "Zero Trust: Azure Storage service tag"
      protocols             = ["TCP"]
      source_ip_groups      = [azurerm_ip_group.spokes.id]
      destination_addresses = ["Storage"]
      destination_ports     = ["443"]
    }

    rule {
      name                  = "Allow-Azure-KeyVault"
      description           = "Zero Trust: Azure Key Vault for secrets management"
      protocols             = ["TCP"]
      source_ip_groups      = [azurerm_ip_group.spokes.id]
      destination_addresses = ["AzureKeyVault"]
      destination_ports     = ["443"]
    }

    rule {
      name                  = "Allow-Azure-Backup"
      description           = "Zero Trust: Azure Backup service"
      protocols             = ["TCP"]
      source_ip_groups      = [azurerm_ip_group.spokes.id]
      destination_addresses = ["AzureBackup"]
      destination_ports     = ["443"]
    }

    rule {
      name                  = "Allow-Azure-ActiveDirectory"
      description           = "Zero Trust: Azure AD authentication"
      protocols             = ["TCP"]
      source_ip_groups      = [azurerm_ip_group.spokes.id]
      destination_addresses = ["AzureActiveDirectory"]
      destination_ports     = ["443", "80"]
    }
  }

  # Azure Authentication Services
  application_rule_collection {
    name     = "AzureAuthenticationServices"
    priority = 210
    action   = "Allow"

    rule {
      name        = "Allow-Azure-AD-Authentication"
      description = "TIC 3.0: Azure AD authentication endpoints"

      protocols {
        type = "Https"
        port = 443
      }

      source_ip_groups = [azurerm_ip_group.spokes.id]

      destination_fqdns = [
        "login.microsoftonline.com",
        "login.microsoft.com",
        "login.windows.net",
        "aadcdn.msauth.net",
        "aadcdn.msftauth.net",
        "pas.windows.net"
      ]
    }
  }

  # Time Services
  network_rule_collection {
    name     = "TimeServices"
    priority = 220
    action   = "Allow"

    rule {
      name                = "Allow-NTP"
      description         = "TIC 3.0: Network Time Protocol for time synchronization"
      protocols           = ["UDP"]
      source_ip_groups    = [azurerm_ip_group.spokes.id]
      destination_fqdns   = ["time.windows.com", "time.nist.gov"]
      destination_ports   = ["123"]
    }
  }
}

# TIC 3.0 Priority 300: Microsoft Services (Conditional)
resource "azurerm_firewall_policy_rule_collection_group" "microsoft_services" {
  name               = "TIC30-300-MicrosoftServices"
  firewall_policy_id = data.azurerm_firewall_policy.existing.id
  priority           = 300

  depends_on = [azurerm_firewall_policy_rule_collection_group.essential_services]

  # Microsoft 365 Services
  dynamic "application_rule_collection" {
    for_each = var.enable_microsoft_365 ? [1] : []
    
    content {
      name     = "Microsoft365Services"
      priority = 300
      action   = "Allow"

      rule {
        name        = "Allow-Microsoft365-Core"
        description = "Zero Trust: M365 core services"

        protocols {
          type = "Https"
          port = 443
        }

        source_ip_groups = [azurerm_ip_group.spokes.id]

        destination_fqdns = [
          "*.office365.com",
          "*.microsoft.com",
          "*.office.com",
          "*.office.net",
          "*.microsoftonline.com",
          "outlook.office365.com",
          "*.protection.outlook.com",
          "*.sharepoint.com",
          "*.onedrive.com"
        ]
      }
    }
  }

  # Windows Update Services
  dynamic "application_rule_collection" {
    for_each = var.enable_windows_update ? [1] : []
    
    content {
      name     = "WindowsUpdateServices"
      priority = 310
      action   = "Allow"

      rule {
        name        = "Allow-Windows-Update"
        description = "TIC 3.0: Windows Update for security patches"

        protocols {
          type = "Https"
          port = 443
        }

        protocols {
          type = "Http"
          port = 80
        }

        source_ip_groups = [azurerm_ip_group.spokes.id]

        destination_fqdns = [
          "*.windowsupdate.microsoft.com",
          "*.update.microsoft.com",
          "*.windowsupdate.com",
          "*.download.windowsupdate.com",
          "*.download.microsoft.com",
          "*.dl.delivery.mp.microsoft.com",
          "*.prod.do.dsp.mp.microsoft.com"
        ]
      }
    }
  }

  # Azure DevOps Services
  dynamic "application_rule_collection" {
    for_each = var.enable_azure_devops ? [1] : []
    
    content {
      name     = "AzureDevOpsServices"
      priority = 320
      action   = "Allow"

      rule {
        name        = "Allow-Azure-DevOps"
        description = "Zero Trust: Azure DevOps for CI/CD"

        protocols {
          type = "Https"
          port = 443
        }

        source_ip_groups = [azurerm_ip_group.spokes.id]

        destination_fqdns = [
          "*.visualstudio.com",
          "*.dev.azure.com",
          "dev.azure.com",
          "azure.microsoft.com",
          "*.vsassets.io",
          "*.vssps.visualstudio.com",
          "*.vstmrblob.vsassets.io"
        ]
      }
    }
  }

  # GitHub Services
  dynamic "application_rule_collection" {
    for_each = var.enable_github ? [1] : []
    
    content {
      name     = "GitHubServices"
      priority = 330
      action   = "Allow"

      rule {
        name        = "Allow-GitHub"
        description = "Zero Trust: GitHub for source control"

        protocols {
          type = "Https"
          port = 443
        }

        source_ip_groups = [azurerm_ip_group.spokes.id]

        destination_fqdns = [
          "github.com",
          "*.github.com",
          "api.github.com",
          "raw.githubusercontent.com",
          "github.githubassets.com",
          "codeload.github.com"
        ]
      }
    }
  }
}

# TIC 3.0 Priority 400: Workload-Specific Rules
resource "azurerm_firewall_policy_rule_collection_group" "workload_specific" {
  count = (!var.enable_high_security_mode || length(var.approved_external_fqdns) > 0) ? 1 : 0

  name               = "TIC30-400-WorkloadSpecific"
  firewall_policy_id = data.azurerm_firewall_policy.existing.id
  priority           = 400

  depends_on = [azurerm_firewall_policy_rule_collection_group.microsoft_services]

  # Approved External Services
  dynamic "application_rule_collection" {
    for_each = length(var.approved_external_fqdns) > 0 ? [1] : []
    
    content {
      name     = "ApprovedExternalServices"
      priority = 400
      action   = "Allow"

      rule {
        name        = "Allow-Approved-External-FQDNs"
        description = "Zero Trust: Pre-approved external services"

        protocols {
          type = "Https"
          port = 443
        }

        source_ip_groups  = [azurerm_ip_group.spokes.id]
        destination_fqdns = var.approved_external_fqdns
      }
    }
  }
}

# TIC 3.0 Priority 500: Azure PaaS Services (Database, AI, etc.)
resource "azurerm_firewall_policy_rule_collection_group" "azure_paas" {
  name               = "TIC30-500-AzurePaaS"
  firewall_policy_id = data.azurerm_firewall_policy.existing.id
  priority           = 500

  depends_on = [azurerm_firewall_policy_rule_collection_group.workload_specific]

  # Azure Database Services
  network_rule_collection {
    name     = "AzureDatabaseServices"
    priority = 500
    action   = "Allow"

    rule {
      name                  = "Allow-Azure-SQL"
      description           = "Zero Trust: Azure SQL Database"
      protocols             = ["TCP"]
      source_ip_groups      = [azurerm_ip_group.spokes.id]
      destination_addresses = ["Sql"]
      destination_ports     = ["1433"]
    }

    rule {
      name                  = "Allow-Azure-CosmosDB"
      description           = "Zero Trust: Azure Cosmos DB"
      protocols             = ["TCP"]
      source_ip_groups      = [azurerm_ip_group.spokes.id]
      destination_addresses = ["AzureCosmosDB"]
      destination_ports     = ["443", "10250", "10251", "10252", "10253", "10254", "10255"]
    }
  }

  # Azure AI Services
  network_rule_collection {
    name     = "AzureAIServices"
    priority = 510
    action   = "Allow"

    rule {
      name                  = "Allow-Cognitive-Services"
      description           = "Zero Trust: Azure Cognitive Services"
      protocols             = ["TCP"]
      source_ip_groups      = [azurerm_ip_group.spokes.id]
      destination_addresses = ["CognitiveServicesManagement"]
      destination_ports     = ["443"]
    }
  }

  application_rule_collection {
    name     = "AzureAIApplicationServices"
    priority = 511
    action   = "Allow"

    rule {
      name        = "Allow-OpenAI-Service"
      description = "Zero Trust: Azure OpenAI Service"

      protocols {
        type = "Https"
        port = 443
      }

      source_ip_groups = [azurerm_ip_group.spokes.id]

      destination_fqdns = [
        "*.openai.azure.com",
        "openai.azure.com"
      ]
    }
  }

  # Azure Container Services
  network_rule_collection {
    name     = "AzureContainerServices"
    priority = 520
    action   = "Allow"

    rule {
      name                  = "Allow-Container-Registry"
      description           = "Zero Trust: Azure Container Registry"
      protocols             = ["TCP"]
      source_ip_groups      = [azurerm_ip_group.spokes.id]
      destination_addresses = ["AzureContainerRegistry"]
      destination_ports     = ["443"]
    }

    rule {
      name                  = "Allow-Kubernetes-API"
      description           = "Zero Trust: Azure Kubernetes Service API"
      protocols             = ["TCP"]
      source_ip_groups      = [azurerm_ip_group.spokes.id]
      destination_addresses = ["AzureKubernetesService"]
      destination_ports     = ["443"]
    }
  }
}
