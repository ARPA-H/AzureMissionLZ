# TIC 3.0 Firewall Rules Architecture

## Traffic Flow Diagram

```
                                    Internet
                                       │
                                       │
                    ┌──────────────────▼──────────────────┐
                    │   Azure Firewall (TIC 3.0 Boundary) │
                    │   ┌──────────────────────────────┐  │
                    │   │  Threat Intelligence: DENY   │  │
                    │   │  IDPS: Alert & Deny Mode     │  │
                    │   │  TLS Inspection: Enabled     │  │
                    │   └──────────────────────────────┘  │
                    └──────────────────┬──────────────────┘
                                       │
                    ┌──────────────────▼──────────────────┐
                    │      Firewall Policy Rules          │
                    │  (Hierarchical Processing Order)    │
                    └─────────────────────────────────────┘
                                       │
        ┌──────────────────────────────┼──────────────────────────────┐
        │                              │                              │
    Priority 100               Priority 200-500                    Deny All
    DENY Rules                  ALLOW Rules                    (Implicit Default)
        │                              │                              │
  ┌─────▼─────┐              ┌─────────▼─────────┐           ┌──────▼──────┐
  │ Malicious │              │  Azure Services   │           │  Everything │
  │ Categories│              │  M365, Updates    │           │  Else       │
  │ Insecure  │              │  Approved FQDNs   │           └─────────────┘
  │ Protocols │              │  PaaS Services    │
  └───────────┘              └─────────┬─────────┘
                                       │
                         ┌─────────────┼─────────────┐
                         │             │             │
                    ┌────▼────┐   ┌────▼────┐   ┌────▼────┐
                    │Operations│   │ Shared  │   │Identity │
                    │  Spoke   │   │Services │   │  Spoke  │
                    │ 10.0.110 │   │  Spoke  │   │ 10.0.130│
                    │  .0/24   │   │ 10.0.120│   │  .0/24  │
                    └──────────┘   │  .0/24  │   └─────────┘
                                   └─────────┘
```

## Rule Processing Flow

```
┌─────────────────────────────────────────────────────────────┐
│  Incoming Connection Request                                │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  Priority 100: TIC30-100-BaselineSecurity                   │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Block Malicious Categories?    YES → ❌ DENY           │ │
│  │ ├─ Hacking, Malware, Phishing         (Log & Block)   │ │
│  │ ├─ Spyware, Botnets                                    │ │
│  │ └─ Proxy Avoidance                                     │ │
│  │                                NO ↓                     │ │
│  │ Block Insecure Protocols?      YES → ❌ DENY           │ │
│  │ ├─ FTP (21), Telnet (23)              (Log & Block)   │ │
│  │ ├─ TFTP (69), SNMP (161)                              │ │
│  │ └─ SMB (445)                                           │ │
│  └────────────────────────────────────────────────────────┘ │
└───────────────────────┬─────────────────────────────────────┘
                        │ NO
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  Priority 200: TIC30-200-EssentialServices                  │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Match Azure Services?          YES → ✅ ALLOW          │ │
│  │ ├─ AzureMonitor (443)                 (Log & Allow)   │ │
│  │ ├─ Storage (443)                                       │ │
│  │ ├─ KeyVault (443)                                      │ │
│  │ ├─ Backup (443)                                        │ │
│  │ └─ ActiveDirectory (443, 80)                           │ │
│  │                                NO ↓                     │ │
│  │ Match Authentication?          YES → ✅ ALLOW          │ │
│  │ ├─ login.microsoftonline.com                           │ │
│  │ ├─ login.microsoft.com                                 │ │
│  │ └─ aadcdn.msauth.net                                   │ │
│  │                                NO ↓                     │ │
│  │ Match Time Services?           YES → ✅ ALLOW          │ │
│  │ └─ time.windows.com (NTP/123)                          │ │
│  └────────────────────────────────────────────────────────┘ │
└───────────────────────┬─────────────────────────────────────┘
                        │ NO
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  Priority 300: TIC30-300-MicrosoftServices                  │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ M365 Enabled & Match?          YES → ✅ ALLOW          │ │
│  │ ├─ *.office365.com                                     │ │
│  │ ├─ *.sharepoint.com                                    │ │
│  │ └─ *.onedrive.com                                      │ │
│  │                                NO ↓                     │ │
│  │ Windows Update Enabled?        YES → ✅ ALLOW          │ │
│  │ └─ WindowsUpdate FQDN Tag                              │ │
│  │                                NO ↓                     │ │
│  │ DevOps Enabled & Match?        YES → ✅ ALLOW          │ │
│  │ └─ *.dev.azure.com                                     │ │
│  │                                NO ↓                     │ │
│  │ GitHub Enabled & Match?        YES → ✅ ALLOW          │ │
│  │ └─ github.com, *.github.com                            │ │
│  └────────────────────────────────────────────────────────┘ │
└───────────────────────┬─────────────────────────────────────┘
                        │ NO
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  Priority 400: TIC30-400-WorkloadSpecific                   │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Match Approved External FQDNs? YES → ✅ ALLOW          │ │
│  │ └─ Custom list from parameters                         │ │
│  └────────────────────────────────────────────────────────┘ │
└───────────────────────┬─────────────────────────────────────┘
                        │ NO
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  Priority 500: TIC30-500-AzurePaaS                          │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Match Database Services?       YES → ✅ ALLOW          │ │
│  │ ├─ Azure SQL (1433)                                    │ │
│  │ └─ Cosmos DB (443, 10250-10255)                        │ │
│  │                                NO ↓                     │ │
│  │ Match AI Services?             YES → ✅ ALLOW          │ │
│  │ ├─ CognitiveServicesManagement                         │ │
│  │ └─ *.openai.azure.com                                  │ │
│  │                                NO ↓                     │ │
│  │ Match Container Services?      YES → ✅ ALLOW          │ │
│  │ ├─ AzureContainerRegistry                              │ │
│  │ └─ AzureKubernetesService                              │ │
│  └────────────────────────────────────────────────────────┘ │
└───────────────────────┬─────────────────────────────────────┘
                        │ NO
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  Default Action: DENY (Implicit)                            │
│  ❌ Connection Blocked - Log to Log Analytics               │
└─────────────────────────────────────────────────────────────┘
```

## Zero Trust Segmentation

```
┌───────────────────────────────────────────────────────────────┐
│                    Azure Subscription                          │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐     │
│  │              Hub Virtual Network                      │     │
│  │  ┌────────────────────────────────────────────────┐  │     │
│  │  │         Azure Firewall + Policy                │  │     │
│  │  │  ┌──────────────────────────────────────────┐  │  │     │
│  │  │  │  IP Group: ipg-zerotrust-spokes          │  │  │     │
│  │  │  │  Members:                                │  │  │     │
│  │  │  │    - 10.0.110.0/24 (Operations)          │  │  │     │
│  │  │  │    - 10.0.120.0/24 (Shared Services)     │  │  │     │
│  │  │  │    - 10.0.130.0/24 (Identity)            │  │  │     │
│  │  │  └──────────────────────────────────────────┘  │  │     │
│  │  └────────────────────────────────────────────────┘  │     │
│  └────────────────────┬───────────────────────────────────     │
│                       │ VNet Peering                           │
│         ┌─────────────┼─────────────┐                          │
│         │             │             │                          │
│  ┌──────▼──────┐ ┌────▼────┐ ┌─────▼──────┐                   │
│  │ Operations  │ │ Shared  │ │  Identity  │                   │
│  │   Spoke     │ │Services │ │   Spoke    │                   │
│  │             │ │  Spoke  │ │            │                   │
│  │ ┌─────────┐ │ │┌──────┐ │ │ ┌────────┐ │                   │
│  │ │   VM    │ │ ││  VM  │ │ │ │  AD DC │ │                   │
│  │ │Workloads│ │ ││      │ │ │ │        │ │                   │
│  │ └─────────┘ │ │└──────┘ │ │ └────────┘ │                   │
│  │             │ │         │ │            │                   │
│  │  NSG: Deny  │ │NSG:Deny │ │ NSG: Deny  │                   │
│  │  + Explicit │ │+Explicit│ │ + Explicit │                   │
│  │    Allow    │ │  Allow  │ │    Allow   │                   │
│  └─────────────┘ └─────────┘ └────────────┘                   │
│         │             │             │                          │
│         │  Zero Trust │             │                          │
│         │  Principles:│             │                          │
│         │  1. Explicit verification (IP Group filtering)       │
│         │  2. Least privilege (Deny by default)                │
│         │  3. Assume breach (Multiple layers: FW + NSG)        │
│         └─────────────┴─────────────┘                          │
└───────────────────────────────────────────────────────────────┘
```

## TIC 3.0 Compliance Mapping

```
┌─────────────────────────────────────────────────────────────┐
│           TIC 3.0 Security Capabilities                     │
└───────────────────────┬─────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
┌───────────────┐ ┌─────────────┐ ┌──────────────┐
│Access Control │ │   Threat    │ │  Encryption  │
│               │ │  Detection  │ │              │
│ • IP Groups   │ │ • IDPS      │ │ • TLS Insp.  │
│ • Least Priv  │ │ • Threat    │ │ • HTTPS Only │
│ • Segmentation│ │   Intel     │ │ • Service    │
│ • Zero Trust  │ │ • Signatures│ │   Endpoints  │
└───────┬───────┘ └──────┬──────┘ └──────┬───────┘
        │                │               │
        └────────────────┼───────────────┘
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                 Azure Firewall Policy                        │
│  with TIC30-100 through TIC30-500 Rule Collections          │
└───────────────────────┬─────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
┌───────────────┐ ┌─────────────┐ ┌──────────────┐
│  Data Loss    │ │  Security   │ │   Incident   │
│  Prevention   │ │ Monitoring  │ │   Response   │
│               │ │             │ │              │
│ • FQDN Filter │ │ • Diagnostic│ │ • Sentinel   │
│ • Web         │ │   Logs      │ │   Integration│
│   Categories  │ │ • Log       │ │ • Automated  │
│ • App Rules   │ │   Analytics │ │   Playbooks  │
└───────────────┘ └─────────────┘ └──────────────┘
```

## Monitoring & Logging Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure Firewall                            │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Every connection generates diagnostic logs:            │ │
│  │  • Rule matched (ALLOW or DENY)                        │ │
│  │  • Source IP, Destination IP/FQDN                      │ │
│  │  • Protocol, Port, Action taken                        │ │
│  │  • IDPS signature hits                                 │ │
│  │  • Threat intelligence matches                         │ │
│  └────────────────────────────────────────────────────────┘ │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              Log Analytics Workspace                         │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Tables:                                               │ │
│  │  • AzureDiagnostics (Firewall logs)                   │ │
│  │  • AzureMetrics (Performance metrics)                 │ │
│  │  • Retention: 30-730 days (configurable)              │ │
│  └────────────────────────────────────────────────────────┘ │
└───────────────────────┬─────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│   Workbooks  │ │    Alerts    │ │   Sentinel   │
│              │ │              │ │              │
│ • Dashboards │ │ • High Deny  │ │ • SIEM/SOAR  │
│ • Trends     │ │   Rate       │ │ • Threat     │
│ • Top Flows  │ │ • SNAT       │ │   Hunting    │
│              │ │   Exhaustion │ │ • Incidents  │
│              │ │ • Health     │ │ • Playbooks  │
└──────────────┘ └──────────────┘ └──────────────┘
        │               │               │
        └───────────────┼───────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              Compliance & Audit Reporting                    │
│  • TIC 3.0 capability evidence                              │
│  • Zero Trust posture assessment                            │
│  • Quarterly security reviews                               │
└─────────────────────────────────────────────────────────────┘
```

## Deployment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      GitHub Repository                       │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Source Files:                                         │ │
│  │  • deploy-firewall-rules-tic30.bicep                   │ │
│  │  • modules/firewall-policy-tic30-zerotrust.bicep       │ │
│  │  • parameters/firewall-rules-tic30.parameters.json     │ │
│  └────────────────────────────────────────────────────────┘ │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ Triggered by:
                        │ • Manual workflow dispatch
                        │ • Schedule (optional)
                        │ • Push to main (optional)
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              GitHub Actions Workflow                         │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  1. Checkout code                                      │ │
│  │  2. Azure Login (OIDC)                                 │ │
│  │  3. Validate Bicep                                     │ │
│  │  4. What-If Analysis (optional)                        │ │
│  │  5. Deploy to Azure                                    │ │
│  │  6. Output results                                     │ │
│  └────────────────────────────────────────────────────────┘ │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ Azure OIDC Authentication
                        │ (Service Principal)
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                    Azure Subscription                        │
│  ┌────────────────────────────────────────────────────────┐ │
│  │           Hub Resource Group                           │ │
│  │  ┌──────────────────────────────────────────────────┐  │ │
│  │  │  Existing Firewall Policy                        │  │ │
│  │  │  + New Rule Collection Groups:                   │  │ │
│  │  │    • TIC30-100-BaselineSecurity                  │  │ │
│  │  │    • TIC30-200-EssentialServices                 │  │ │
│  │  │    • TIC30-300-MicrosoftServices                 │  │ │
│  │  │    • TIC30-400-WorkloadSpecific                  │  │ │
│  │  │    • TIC30-500-AzurePaaS                         │  │ │
│  │  │  + New IP Group:                                 │  │ │
│  │  │    • ipg-zerotrust-spokes                        │  │ │
│  │  └──────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Key Design Principles

### Defense in Depth
```
Internet → Firewall (TIC 3.0) → VNet (Segmentation) → NSG → VM
   ↓            ↓                    ↓               ↓      ↓
Block      Inspect              Isolate          Filter  Monitor
Threats    Traffic               Workloads        Ports   Logs
```

### Least Privilege
```
Default: DENY ALL
    ↓
Explicit: ALLOW ONLY what's needed
    ↓
Source: FROM specific networks (IP Groups)
    ↓
Destination: TO specific services (Service Tags, FQDNs)
    ↓
Audit: LOG everything
```

### Assume Breach
```
Layer 1: Firewall (Perimeter security)
Layer 2: VNet (Network isolation)
Layer 3: NSG (Subnet protection)
Layer 4: VM Firewall (Host-based)
Layer 5: Application (App-level auth)
    ↓
Each layer can independently block threats
```
