# Import and Deployment Guide for Main and Sandbox Environments

## Directory Structure
```
scp-mari/
├── main.tf                 # Resources (shared)
├── variables.tf            # Variable definitions (shared)
├── output.tf              # Outputs (shared)
├── provider.tf            # AWS provider config (shared)
├── backend.tf             # Backend config template (shared)
├── policies/              # Policy JSON files (shared)
├── main/
│   ├── backend.conf       # Main backend config (Terraform Cloud workspace)
│   ├── main.tfvars        # Main environment variables
│   └── imports_main.sh    # Main import script
└── sandbox/
    ├── backend.conf       # Sandbox backend config (Terraform Cloud workspace)
    ├── sandbox.tfvars     # Sandbox environment variables
    └── imports_sandbox.sh # Sandbox import script
```

-----
**####for main environment**
terraform init -backend-config=main/backend.conf -reconfigure
bash main/imports_main.sh
terraform plan -var-file="main/main.tfvars"
terraform apply -var-file="main/main.tfvars"
**####for SANDBOX environment**
terraform init -backend-config=sandbox/backend.conf -reconfigure
bash sandbox/imports_sandbox.sh
terraform plan -var-file="sandbox/sandbox.tfvars"
terraform apply -var-file="sandbox/sandbox.tfvars"

