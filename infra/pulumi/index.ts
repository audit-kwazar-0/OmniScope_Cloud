import * as pulumi from "@pulumi/pulumi";
import * as authorization from "@pulumi/azure-native/authorization";
import * as containerregistry from "@pulumi/azure-native/containerregistry";
import * as containerservice from "@pulumi/azure-native/containerservice";
import * as dashboard from "@pulumi/azure-native/dashboard";
import * as eventhub from "@pulumi/azure-native/eventhub";
import * as insights from "@pulumi/azure-native/insights";
import * as insightsv20250101preview from "@pulumi/azure-native/insights/v20250101preview/scheduledQueryRule";
import * as managedidentity from "@pulumi/azure-native/managedidentity";
import * as monitor from "@pulumi/azure-native/monitor";
import * as network from "@pulumi/azure-native/network";
import * as operationalinsights from "@pulumi/azure-native/operationalinsights";
import * as resources from "@pulumi/azure-native/resources";
import * as random from "@pulumi/random";
import * as insightEnums from "@pulumi/azure-native/types/enums/insights";
import * as dashboardEnums from "@pulumi/azure-native/types/enums/dashboard";
import * as csEnums from "@pulumi/azure-native/types/enums/containerservice";
import * as insightRuleEnums from "@pulumi/azure-native/types/enums/insights/v20250101preview";

const config = new pulumi.Config("omniscope");

const prefix = config.require("prefix");
const location = config.get("location") ?? "westeurope";
const alertEmail = config.require("alertEmail");
const logAnalyticsRetentionDays = config.getNumber("logAnalyticsRetentionDays") ?? 30;
const appInsightsRetentionDays = config.getNumber("appInsightsRetentionDays") ?? 90;
const actionGroupShortName = config.get("actionGroupShortName") ?? "obs-pzu";
const deployManagedPrometheus = config.getBoolean("deployManagedPrometheus") ?? true;
const deployLogExport = config.getBoolean("deployLogExport") ?? true;
const teamsWebhookUri = (config.get("teamsWebhookUri") ?? "").trim();
const deployAks = config.getBoolean("deployAks") ?? true;
const deployAcr = config.getBoolean("deployAcr") ?? true;
const deployAksDiagnostics = config.getBoolean("deployAksDiagnostics") ?? true;
const acrNameOverride = (config.get("acrNameOverride") ?? "").trim();
const aksSystemVmSize = config.get("aksSystemVmSize") ?? "Standard_B2s_v2";
const aksSystemNodeCount = config.getNumber("aksSystemNodeCount") ?? 2;
const enableAzurePolicyAddon = config.getBoolean("enableAzurePolicyAddon") ?? true;
const enableKeyVaultSecretsProvider = config.getBoolean("enableKeyVaultSecretsProvider") ?? true;
const keyVaultSecretRotationEnabled = config.getBoolean("keyVaultSecretRotationEnabled") ?? true;
const keyVaultRotationPollInterval = config.get("keyVaultRotationPollInterval") ?? "2m";
const grafanaAdminObjectId = (config.get("grafanaAdminObjectId") ?? "").trim();
const grafanaAdminPrincipalType = (config.get("grafanaAdminPrincipalType") ?? "User").trim();

const tags = (config.getObject<Record<string, string>>("tags") ?? {}) as Record<string, string>;

const clientConfig = authorization.getClientConfigOutput();

const rgName = `${prefix}-rg`;
const lawName = `${prefix}-law`;
const appInsightsName = `${prefix}-appi`;
const actionGroupName = `${prefix}-ag`;
const azureMonitorWorkspaceName = `${prefix}-amw`;
const grafanaWorkspaceName = `${prefix}grafana`.slice(0, 23);
const eventHubNamespaceName = `${prefix}ehns`.replace(/-/g, "").slice(0, 50);
const eventHubInstanceName = "omniscope-logs";
const aksClusterName = `${prefix}-aks`;
const aksDnsPrefix = `${prefix}-aks`;
const vnetName = `${prefix}-vnet`;
const deployerIdentityName = `${prefix}-aks-deployer-uai`;

const aksContributorRoleId = "ed7f3fbd-7b88-4dd4-9017-9adb7ce333f8";
const acrPullRoleId = "7f951dda-4ed3-4680-a7ca-43fe172d538d";
const grafanaAdminRoleId = "22926164-76b3-42b3-bc55-97df8dab3e41";

function subscriptionRoleDefinition(roleId: string): pulumi.Output<string> {
  return pulumi.interpolate`/subscriptions/${clientConfig.subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${roleId}`;
}

const rg = new resources.ResourceGroup("rg", {
  resourceGroupName: rgName,
  location,
  tags,
});

const law = new operationalinsights.Workspace("law", {
  resourceGroupName: rg.name,
  workspaceName: lawName,
  location,
  retentionInDays: logAnalyticsRetentionDays,
  sku: {
    name: operationalinsights.WorkspaceSkuNameEnum.PerGB2018,
  },
  tags,
});

const appInsights = new insights.Component("appinsights", {
  resourceGroupName: rg.name,
  resourceName: appInsightsName,
  location,
  kind: "web",
  applicationType: insightEnums.ApplicationType.Web,
  flowType: insightEnums.FlowType.Bluefield,
  requestSource: insightEnums.RequestSource.Rest,
  ingestionMode: insightEnums.IngestionMode.LogAnalytics,
  workspaceResourceId: law.id,
  retentionInDays: appInsightsRetentionDays,
  tags,
});

const actionGroup = new insights.ActionGroup("actionGroup", {
  resourceGroupName: rg.name,
  actionGroupName,
  groupShortName: actionGroupShortName,
  location: "global",
  enabled: true,
  emailReceivers: [
    {
      name: "oncall-email",
      emailAddress: alertEmail,
      useCommonAlertSchema: true,
    },
  ],
  webhookReceivers:
    teamsWebhookUri.length > 0
      ? [
          {
            name: "teams-webhook",
            serviceUri: teamsWebhookUri,
            useCommonAlertSchema: true,
          },
        ]
      : undefined,
});

let azureMonitorWorkspace: monitor.AzureMonitorWorkspace | undefined;
let managedGrafana: dashboard.Grafana | undefined;

if (deployManagedPrometheus) {
  azureMonitorWorkspace = new monitor.AzureMonitorWorkspace("amw", {
    resourceGroupName: rg.name,
    azureMonitorWorkspaceName,
    location,
    tags,
  });

  managedGrafana = new dashboard.Grafana("grafana", {
    resourceGroupName: rg.name,
    workspaceName: grafanaWorkspaceName,
    location,
    tags,
    sku: { name: "Standard" },
    properties: {
      apiKey: dashboardEnums.ApiKey.Enabled,
      deterministicOutboundIP: dashboardEnums.DeterministicOutboundIP.Disabled,
      publicNetworkAccess: dashboardEnums.PublicNetworkAccess.Enabled,
      zoneRedundancy: dashboardEnums.ZoneRedundancy.Disabled,
      grafanaIntegrations: {
        azureMonitorWorkspaceIntegrations: [
          { azureMonitorWorkspaceResourceId: azureMonitorWorkspace.id },
        ],
      },
    },
  });

  if (managedGrafana && grafanaAdminObjectId.length > 0) {
    const grafanaAdminRaName = new random.RandomUuid("grafana-admin-ra", {
      keepers: {
        workspace: grafanaWorkspaceName,
        principal: grafanaAdminObjectId,
        role: grafanaAdminRoleId,
      },
    });
    new authorization.RoleAssignment("managed-grafana-admin", {
      scope: managedGrafana.id,
      roleAssignmentName: grafanaAdminRaName.result,
      roleDefinitionId: subscriptionRoleDefinition(grafanaAdminRoleId),
      principalId: grafanaAdminObjectId,
      principalType: grafanaAdminPrincipalType,
    });
  }
}

let ehNamespace: eventhub.Namespace | undefined;
let ehLogs: eventhub.EventHub | undefined;
if (deployLogExport) {
  ehNamespace = new eventhub.Namespace("eh-namespace", {
    resourceGroupName: rg.name,
    namespaceName: eventHubNamespaceName,
    location,
    tags,
    sku: {
      name: "Standard",
      tier: "Standard",
      capacity: 1,
    },
    minimumTlsVersion: "1.2",
    publicNetworkAccess: "Enabled",
  });

  ehLogs = new eventhub.EventHub("eh-logs", {
    resourceGroupName: rg.name,
    namespaceName: ehNamespace.name,
    eventHubName: eventHubInstanceName,
    messageRetentionInDays: 1,
    partitionCount: 2,
  });

  new operationalinsights.DataExport(
    "law-export-alllogs",
    {
      resourceGroupName: rg.name,
      workspaceName: law.name,
      dataExportName: "to-eventhub-alllogs",
      enable: true,
      resourceId: ehNamespace.id,
      tableNames: ["ContainerLogV2", "AzureDiagnostics", "KubePodInventory", "KubeEvents"],
    },
    { dependsOn: [ehLogs] },
  );
}

const cpuHighQuery =
  'let avgCpu = toscalar(InsightsMetrics | where TimeGenerated > ago(5m) | where Namespace == "container.azm.ms/cpu" and Name == "cpuUsageNanoCores" | summarize avg(Val)); print cpuBreach = iif(isnull(avgCpu), 0.0, iif(avgCpu > 80.0, 1.0, 0.0))';

new insightsv20250101preview.ScheduledQueryRule("alert-aks-cpu-high", {
  resourceGroupName: rg.name,
  ruleName: `${actionGroupName}-aks-cpu-high`,
  location,
  tags,
  enabled: true,
  severity: 2,
  evaluationFrequency: "PT5M",
  windowSize: "PT5M",
  scopes: [law.id],
  kind: insightRuleEnums.Kind.LogAlert,
  autoMitigate: true,
  description: "AKS node CPU usage > 80% for 5 minutes",
  criteria: {
    allOf: [
      {
        query: cpuHighQuery,
        timeAggregation: insightRuleEnums.TimeAggregation.Maximum,
        metricMeasureColumn: "cpuBreach",
        operator: insightRuleEnums.ConditionOperator.GreaterThan,
        threshold: 0,
        failingPeriods: {
          numberOfEvaluationPeriods: 1,
          minFailingPeriodsToAlert: 1,
        },
      },
    ],
  },
  actions: {
    actionGroups: [actionGroup.id],
  },
});

const appErrorsQuery = `let total = toscalar(ContainerLogV2 | where TimeGenerated > ago(10m) | count); let errors = toscalar(ContainerLogV2 | where TimeGenerated > ago(10m) | where LogMessage has "ERROR" or LogMessage matches regex @"\\b5\\d\\d\\b" | count); print errorRate = iif(total == 0, 0.0, todouble(errors) / todouble(total) * 100.0)`;

new insightsv20250101preview.ScheduledQueryRule("alert-omniscope-errors", {
  resourceGroupName: rg.name,
  ruleName: `${actionGroupName}-omniscope-errors`,
  location,
  tags,
  enabled: true,
  severity: 2,
  evaluationFrequency: "PT5M",
  windowSize: "PT10M",
  scopes: [law.id],
  kind: insightRuleEnums.Kind.LogAlert,
  autoMitigate: true,
  description: "OmniScope error ratio > 5% for last 10 minutes",
  criteria: {
    allOf: [
      {
        query: appErrorsQuery,
        timeAggregation: insightRuleEnums.TimeAggregation.Maximum,
        metricMeasureColumn: "errorRate",
        operator: insightRuleEnums.ConditionOperator.GreaterThan,
        threshold: 5,
        failingPeriods: {
          numberOfEvaluationPeriods: 1,
          minFailingPeriodsToAlert: 1,
        },
      },
    ],
  },
  actions: {
    actionGroups: [actionGroup.id],
  },
});

const acrSuffix = new random.RandomString("acr-uniq", {
  length: 13,
  lower: true,
  upper: false,
  numeric: true,
  special: false,
  keepers: {
    subscriptionId: clientConfig.subscriptionId,
    prefix,
    rgName,
  },
});

const normalizedAcrOverride =
  acrNameOverride.length > 0
    ? acrNameOverride.replace(/-/g, "").toLowerCase().slice(0, 50)
    : "";

const resolvedAcrName: pulumi.Output<string> =
  acrNameOverride.length > 0
    ? pulumi.output(normalizedAcrOverride)
    : pulumi.interpolate`omni${acrSuffix.result}`;

let acr: containerregistry.Registry | undefined;
if (deployAks && deployAcr) {
  acr = new containerregistry.Registry("acr", {
    resourceGroupName: rg.name,
    registryName: resolvedAcrName,
    location,
    tags,
    sku: { name: "Basic" },
    adminUserEnabled: false,
    publicNetworkAccess: "Enabled",
  });
}

let vnet: network.VirtualNetwork | undefined;
let deployerIdentity: managedidentity.UserAssignedIdentity | undefined;
let aks: containerservice.ManagedCluster | undefined;

if (deployAks) {
  vnet = new network.VirtualNetwork("vnet", {
    resourceGroupName: rg.name,
    virtualNetworkName: vnetName,
    location,
    tags,
    addressSpace: {
      addressPrefixes: ["10.224.0.0/16"],
    },
    subnets: [
      {
        name: "aks",
        addressPrefix: "10.224.0.0/22",
      },
      {
        name: "private-endpoints",
        addressPrefix: "10.224.8.0/24",
        privateEndpointNetworkPolicies: "Disabled",
      },
    ],
  });

  deployerIdentity = new managedidentity.UserAssignedIdentity("aks-deployer", {
    resourceGroupName: rg.name,
    resourceName: deployerIdentityName,
    location,
    tags,
  });

  const aksAddonProfiles = {
    omsagent: {
      enabled: true,
      config: {
        logAnalyticsWorkspaceResourceID: law.id,
      },
    },
    ...(enableAzurePolicyAddon ? { azurepolicy: { enabled: true as const } } : {}),
    ...(enableKeyVaultSecretsProvider
      ? {
          azureKeyvaultSecretsProvider: {
            enabled: true as const,
            config: {
              enableSecretRotation: keyVaultSecretRotationEnabled ? "true" : "false",
              rotationPollInterval: keyVaultRotationPollInterval,
            },
          },
        }
      : {}),
  };

  aks = new containerservice.ManagedCluster("aks", {
    resourceGroupName: rg.name,
    resourceName: aksClusterName,
    location,
    tags,
    dnsPrefix: aksDnsPrefix,
    enableRBAC: true,
    identity: {
      type: csEnums.ResourceIdentityType.SystemAssigned,
    },
    agentPoolProfiles: [
      {
        name: "system",
        mode: csEnums.AgentPoolMode.System,
        count: aksSystemNodeCount,
        vmSize: aksSystemVmSize,
        osType: csEnums.OSType.Linux,
        type: csEnums.AgentPoolType.VirtualMachineScaleSets,
        osDiskSizeGB: 100,
        vnetSubnetID: pulumi.interpolate`${vnet.id}/subnets/aks`,
      },
    ],
    networkProfile: {
      networkPlugin: csEnums.NetworkPlugin.Azure,
      networkPluginMode: csEnums.NetworkPluginMode.Overlay,
      loadBalancerSku: csEnums.LoadBalancerSku.Standard,
      outboundType: csEnums.OutboundType.LoadBalancer,
    },
    addonProfiles: aksAddonProfiles,
  });

  const aksContribAssignmentName = new random.RandomUuid("aks-contrib-ra", {
    keepers: {
      cluster: aksClusterName,
      deployer: deployerIdentityName,
      role: aksContributorRoleId,
    },
  });

  new authorization.RoleAssignment("aks-deployer-contributor", {
    scope: aks.id,
    roleAssignmentName: aksContribAssignmentName.result,
    roleDefinitionId: subscriptionRoleDefinition(aksContributorRoleId),
    principalId: deployerIdentity.principalId,
    principalType: "ServicePrincipal",
  });
}

if (deployAks && deployAcr && acr && aks) {
  const kubeletObjectId = aks.identityProfile.apply(
    (p) => p?.kubeletidentity?.objectId ?? "",
  );

  const acrPullAssignmentName = new random.RandomUuid("acr-pull-ra", {
    keepers: {
      acr: resolvedAcrName,
      cluster: aksClusterName,
      role: acrPullRoleId,
    },
  });

  new authorization.RoleAssignment("acr-pull-kubelet", {
    scope: acr.id,
    roleAssignmentName: acrPullAssignmentName.result,
    roleDefinitionId: subscriptionRoleDefinition(acrPullRoleId),
    principalId: kubeletObjectId,
    principalType: "ServicePrincipal",
  });
}

if (deployAks && deployAksDiagnostics && aks) {
  new insights.DiagnosticSetting("aks-diagnostics", {
    name: "send-to-law",
    resourceUri: aks.id,
    workspaceId: law.id,
    logs: [
      { category: "kube-apiserver", enabled: true },
      { category: "kube-audit", enabled: true },
      { category: "kube-audit-admin", enabled: true },
      { category: "kube-controller-manager", enabled: true },
      { category: "kube-scheduler", enabled: true },
      { category: "cluster-autoscaler", enabled: true },
      { category: "guard", enabled: true },
    ],
    metrics: [{ category: "AllMetrics", enabled: true }],
  });
}

export const resourceGroupName = rg.name;
export const logAnalyticsWorkspaceId = law.id;
export const applicationInsightsId = appInsights.id;
export const actionGroupId = actionGroup.id;
export const azureMonitorWorkspaceId = azureMonitorWorkspace?.id ?? pulumi.output("");
export const grafanaUrl =
  managedGrafana?.properties.apply((p) => p.endpoint ?? "") ?? pulumi.output("");
export const eventHubId = ehLogs?.id ?? pulumi.output("");
export const aksName = aks?.name ?? pulumi.output("");
export const aksFqdn = aks?.fqdn ?? pulumi.output("");
export const vnetId = vnet?.id ?? pulumi.output("");
export const privateEndpointsSubnetId =
  vnet !== undefined
    ? pulumi.interpolate`${vnet.id}/subnets/private-endpoints`
    : pulumi.output("");
export const acrName = acr?.name ?? pulumi.output("");
export const acrLoginServer = acr?.loginServer ?? pulumi.output("");
