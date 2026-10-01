
# Windows DevOps Toolkit — Automated Installer Packaging & Deployment

## Overview

This project is about automating the packaging, distribution, and deployment of a Windows developer toolkit using Azure Devops pipeline. It downloads component installers from official sources, bundles(.exe) them into a distributable `.zip` package, provisions a Windows EC2 instance, and installs all tools via Ansible over WinRM and verify by checking from program files and versions.

The installer package is stored as a pipeline artifact and passed between stages.

## Architecture

```

│                    Azure DevOps Pipeline                     │
│                                                              │
│  Stage 1: Build Package                                      │
│  ├── Install PowerShell Core (pwsh) on Linux agent           │
│  ├── Download components from official sources               │
│  ├── Bundle into DevOpsToolkit-Setup.zip                     │
│  ├── Generate SHA256 checksum                                │
│  └── Publish as Pipeline Artifact                            │
│                                                              │
│  Stage 2: Provision Windows VM                               │
│  ├── Terraform init & apply                                  │
│  ├── Create Windows Server 2022 EC2 instance                 │
│  ├── Configure WinRM via user_data                           │
│  └── Capture public IP                                       │
│                                                              │
│  Stage 3: Deploy & Verify                                    │
│  ├── Download pipeline artifact                              │
│  ├── Create Windows inventory (WinRM)                        │
│  ├── Warm up WinRM connection                                │
│  ├── Run Ansible playbook (deploy-installer.yml)             │
│  │   ├── Copy zip to Windows VM                              │
│  │   ├── Extract package                                     │
│  │   ├── Install Notepad++, Git, Python, AWS CLI             │
│  │   └── Generate installation report                        │
│  └── Verify all installations                                │
│                                                              │
│  Stage 4: Cleanup                                            │
│  └── Terraform destroy (runs always)                         │



## Tools & Technologies


Azure DevOps ->  CI/CD pipeline orchestration 
PowerShell Core -> Cross-platform scripting (runs on Linux agent) 
Terraform -> Infrastructure provisioning (Windows EC2 + Security Group) 
Ansible -> Configuration management via WinRM 
AWS EC2 -> Windows Server 2022 target VM 
Self-hosted Agent -> Amazon Linux 2023 EC2 running Azure DevOps agent 

## Packaged Softwares

| Notepad++ 
| Git 
| Python 
| AWS CLI v2 

## Project Structure


windows-package-installer-proj/
├── azure-pipelines.yml              # Pipeline definition (4 stages)
├── scripts/
│   ├── download-components.ps1      # Downloads installers from official sources
│   ├── install-all.ps1              # Silent install script (standalone use)
│   └── verify-install.ps1           # Verification script (standalone use)
├── build/
│   ├── package.ps1                  # Bundles components into .zip
│   └── output/                      # Generated package (git-ignored)
├── terraform/
│   ├── main.tf                      # Root module — calls windows_vm module
│   ├── variables.tf                 # Root variables (subnet_id, vpc_id, etc.)
│   ├── outputs.tf                   # Root outputs (public_ip, ami_used)
│   └── modules/
│       └── windows_vm/
│           ├── main.tf              # EC2 instance, security group, WinRM user_data
│           ├── variables.tf         # Module variables
│           └── outputs.tf           # Module outputs
├── ansible/
│   ├── ansible.cfg                  # Ansible configuration
│   ├── playbooks/
│   │   └── deploy-installer.yml     # Main deployment playbook
│   └── roles/
│       └── deploy-toolkit/
│           ├── tasks/main.yml       # Install tasks (win_package, win_copy, etc.)
│           └── defaults/main.yml    # Default variables (install_dir, paths)
└── .gitignore



## How to Run

```bash
# Clone the repo
git clone https://github.com/<your-username>/windows-package-installer-proj.git

# Push to trigger pipeline
git push origin master

# Or manually run from Azure DevOps:
# Pipelines → Select pipeline → Run pipeline → Run
```


## Troubleshooting

Issues that I have faced :
WinRM timeout => Increase `winrm_timeout` in Terraform user_data; add WinRM warm-up step 
WinRM InvalidSelectors => Add retries with delay on first task; warm up WinRM before Ansible 
Installer path not found => Check zip nesting — use `zip -r ... .` to avoid wrapper folders 
Gathering facts fails => Add `gather_facts: false` to playbook for Windows targets 
Password rejected => Ensure password meets Windows complexity requirements (uppercase + lowercase + number + special) 
