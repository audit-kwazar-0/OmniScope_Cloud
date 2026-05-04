# Terraform - Observability Test Platform

Creates the same minimal “base” resources as the Bicep and Pulumi implementations:

- Resource Group
- Log Analytics Workspace
- Application Insights (linked to Log Analytics)
- Azure Monitor Action Group (email receiver)

## Deploy

1. Set required variables (or create `terraform.tfvars`):

```hcl
prefix      = "omniscope-obs-test"
location    = "westeurope"
alert_email = "oncall@example.com"
```

2. Then:

```bash
terraform init
terraform apply
```

