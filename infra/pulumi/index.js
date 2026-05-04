"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.actionGroupId = exports.applicationInsightsId = exports.logAnalyticsWorkspaceId = exports.resourceGroupName = void 0;
const pulumi = __importStar(require("@pulumi/pulumi"));
const resources = __importStar(require("@pulumi/azure-native/resources"));
const operationalinsights = __importStar(require("@pulumi/azure-native/operationalinsights"));
const applicationinsights = __importStar(require("@pulumi/azure-native/applicationinsights"));
const monitor = __importStar(require("@pulumi/azure-native/monitor"));
const config = new pulumi.Config();
const prefix = config.require("prefix"); // e.g. omniscope-obs-test
const location = config.get("location") ?? "westeurope";
const alertEmail = config.require("alertEmail");
const logAnalyticsRetentionDays = config.getNumber("logAnalyticsRetentionDays") ?? 30;
const appInsightsRetentionDays = config.getNumber("appInsightsRetentionDays") ?? 90;
// Optional tags
const tags = (config.getObject("tags") ?? {});
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
exports.resourceGroupName = rg.name;
exports.logAnalyticsWorkspaceId = law.id;
exports.applicationInsightsId = appInsights.id;
exports.actionGroupId = actionGroup.id;
