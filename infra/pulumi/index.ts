import * as pulumi from "@pulumi/pulumi";
import * as resources from "@pulumi/azure-native/resources";
import * as operationalinsights from "@pulumi/azure-native/operationalinsights";
import * as applicationinsights from "@pulumi/azure-native/applicationinsights";
import * as monitor from "@pulumi/azure-native/monitor";

const config = new pulumi.Config();

const prefix = config.require("prefix"); // e.g. omniscope-obs-test
const location = config.get("location") ?? "westeurope";
const alertEmail = config.require("alertEmail");

const logAnalyticsRetentionDays = config.getNumber("logAnalyticsRetentionDays") ?? 30;
const appInsightsRetentionDays = config.getNumber("appInsightsRetentionDays") ?? 90;

// Optional tags
const tags = (config.getObject<Record<string, string>>("tags") ?? {}) as Record<string, string>;

const rgName = `${prefix}-rg`;
const lawName = `${prefix}-law`;
const appInsightsName = `${prefix}-appi`;
const actionGroupName = `${prefix}-ag`;
const groupShortName = config.get("actionGroupShortName") ?? "obs-pzu";

const rg = new resources.ResourceGroup("rg", {
  resourceGroupName: rgName,
  location: location,
  tags: tags,
});

const law = new operationalinsights.Workspace("law", {
  resourceGroupName: rgName,
  workspaceName: lawName,
  location: location,
  retentionInDays: logAnalyticsRetentionDays,
  sku: {
    name: operationalinsights.WorkspaceSkuNameEnum.PerGB2018,
  },
  tags: tags,
});

const appInsights = new applicationinsights.Component("appinsights", {
  resourceGroupName: rgName,
  resourceName: appInsightsName,
  location: location,
  kind: "web",
  applicationType: "web",
  flowType: "Bluefield",
  requestSource: "rest",
  ingestionMode: "LogAnalytics",
  workspaceResourceId: law.id,
  retentionInDays: appInsightsRetentionDays,
  tags: tags,
});

const actionGroup = new monitor.ActionGroup("actionGroup", {
  resourceGroupName: rgName,
  actionGroupName: actionGroupName,
  groupShortName: groupShortName,
  enabled: true,
  emailReceivers: [
    {
      name: "oncall-email",
      emailAddress: alertEmail,
      useCommonAlertSchema: true,
    },
  ],
});

export const resourceGroupName = rg.name;
export const logAnalyticsWorkspaceId = law.id;
export const applicationInsightsId = appInsights.id;
export const actionGroupId = actionGroup.id;

