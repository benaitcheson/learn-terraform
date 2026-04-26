# learn-terraform

A sandbox for learning Terraform with AWS. Provisions an EC2 instance, two VPCs (prod/dev), and matching subnets.

## Setup

1. Copy the example vars file and fill in your AWS credentials:

   ```sh
   cp terraform.tfvars.example terraform.tfvars
   ```

   Edit `terraform.tfvars` and set:

   - `aws_access_key` — your AWS access key ID
   - `aws_secret_key` — your AWS secret access key
   - `aws_region` — the region to deploy into (defaults to `ap-southeast-2`)

   `terraform.tfvars` is gitignored, so your real credentials will not be committed.

2. Initialize and apply:

   ```sh
   terraform init
   terraform plan
   terraform apply
   ```

## Files

- `main.tf` — resource definitions (EC2, VPCs, subnets)
- `variables.tf` — input variable declarations
- `terraform.tfvars.example` — template for your local `terraform.tfvars`
