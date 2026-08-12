# learn-terraform

A sandbox for learning Terraform with AWS. Provisions the infrastructure to run
my rails app with an EC2 web server, an RDS Postgres database, an S3 bucket, and the networking/IAM
around them.

Everything runs in the **default VPC** — no custom networking yet, by design.

## What gets provisioned

| Resource | Purpose |
|---|---|
| `aws_instance.web_server` | t4g.small EC2 instance (Graviton/ARM) that runs the app in Docker |
| `aws_db_instance.postgres` | Postgres 18 on RDS (db.t4g.small, also Graviton, not publicly accessible) |
| `aws_s3_bucket.example` | S3 bucket (not wired into the app yet) |
| `aws_security_group.web_server` | Allows HTTP (port 80) in from anywhere; all traffic out |
| `aws_security_group.database` | Allows Postgres (5432) in **only from the web server's security group** |
| `aws_iam_role.web_server_role` + policy attachment + instance profile | Gives the instance the `AmazonSSMManagedInstanceCore` managed policy so SSM Session Manager works (shell access with no SSH keys and no port 22) |
| `random_pet.bucket_suffix` | Readable unique suffix shared by resource names |
| `random_password.db_password` | 32-char DB master password (URL-safe specials only — `-` and `_` — so it can be embedded in a `DATABASE_URL` without percent-encoding) |
| `random_password.secret_key_base` | 64-char Rails `SECRET_KEY_BASE`. Lives in Terraform state (not generated on the box) so session cookies survive instance replacement |

## Setup

Credentials come from a short-lived (4-hour) sandbox account, so they rotate often.
No credentials live in any file: the provider block declares no `access_key`/`secret_key`,
so Terraform falls back to its credential chain — environment variables first — and the
AWS CLI reads the same ones. One export arms both tools.

1. Export the sandbox credentials (once per sandbox, in each shell that needs them):

   ```sh
   export AWS_ACCESS_KEY_ID=...
   export AWS_SECRET_ACCESS_KEY=...
   export AWS_DEFAULT_REGION=us-east-1
   ```

   Sanity check: `aws sts get-caller-identity` shows which account you're pointed at.

2. Initialize and apply:

   ```sh
   terraform init
   terraform plan   # read it before saying yes
   terraform apply
   ```

   When the sandbox expires, nothing carries over: export the new credentials and
   re-apply from scratch. RDS creation takes 5–10 minutes.

`terraform.tfstate` is gitignored — it contains secrets (the generated DB password
in plaintext).

## Shell access (SSM, no SSH)

The instance has no key pair and port 22 is closed. Access is via SSM Session Manager
(requires the `session-manager-plugin`, e.g. `brew install --cask session-manager-plugin`):

```sh
aws ssm describe-instance-information   # instance should show PingStatus: Online
aws ssm start-session --target i-<instance-id>
```

If the instance doesn't register: check the IAM instance profile is attached, the
security group allows outbound 443, and give the agent a couple of minutes (or reboot
the instance).

## Deploying the app (automated via user_data)

`terraform apply` is the whole deploy. The instance's `user_data` runs
`app_container_startup.sh` at first boot: install docker + git, clone the app repo,
build the image (native arm64 on the Graviton box), `docker run`.

The script is rendered with `templatefile()` in `main.tf`, which is how the
Terraform-only values get in: `${secret_key_base}` and `${database_url}` placeholders
in the script are substituted before the script reaches the instance. Because
`database_url` references the RDS resource, Terraform orders the database before the
web server automatically. `user_data_replace_on_change = true` means editing the
script replaces the instance (new public IP) on the next apply.

- The container listens on 3000 (see the app's Dockerfile `EXPOSE`); `-p 80:3000` maps it.
- `DATABASE_URL` format: `postgres://<username>:<password>@<endpoint>/<db_name>` —
  the RDS `endpoint` attribute is already `host:port`, don't append the port again.
- Allow ~3–5 minutes after the instance is up: the docker build is the slow part.

Success check from a laptop: `curl http://<instance-public-ip>` returns an HTTP response
(a 302 to `/login` means the app is fully up).

Debugging, over an SSM session:

- `/var/log/cloud-init-output.log` — everything `user_data` printed; first stop if
  the app never comes up.
- `sudo docker ps -a` (is it running?), `sudo docker logs <id>` (why not?). The
  container's entrypoint runs `db:prepare` before Rails starts, so a missing/wrong
  `DATABASE_URL` kills it at boot.

Known tradeoff: the DB password and secret key base are baked into `user_data`, which
anyone with EC2 read access (or a shell on the box hitting the metadata endpoint) can
read. Fine for a 4-hour sandbox; the proper fix is fetching secrets at boot from SSM
Parameter Store using the instance's IAM role.

## Files

- `main.tf` — resource definitions
- `outputs.tf` — outputs (`db_password`, marked sensitive; read with `terraform output -raw db_password`)
- `versions.tf` — Terraform and provider version constraints
- `app_container_startup.sh` — `user_data` template that deploys the app at boot
  (rendered by `templatefile()`; `${...}` in it is Terraform substitution, so any
  shell variables added later must be escaped as `$${...}`)
- `variables.tf`, `terraform.tfvars`, `terraform.tfvars.example` — empty/stale leftovers
  from when credentials were passed as variables; safe to delete

## Known rough edges / next steps

- [x] Automate the manual deploy with `user_data` (+ `user_data_replace_on_change`);
      Terraform interpolates the DB endpoint/password and secret key base into the
      script via `templatefile()`
- [ ] Move secrets out of `user_data`: instance fetches them at boot from SSM
      Parameter Store / Secrets Manager using its IAM role
- [ ] Outputs for the instance public IP and DB endpoint
- [ ] Names and descriptions on security groups and IAM resources (currently
      auto-generated `terraform-...` names)
- [ ] Migrate inline `ingress`/`egress` blocks to standalone
      `aws_vpc_security_group_ingress_rule` resources (current provider best practice —
      but never mix both styles on one group)
- [x] Drop `access_key`/`secret_key` from the provider block in favour of environment
      credentials (done — the provider block is gone entirely; region also comes from env)
- [ ] Wire the S3 bucket into the app (will need a scoped IAM policy on the web server role)
- [ ] Replace the hardcoded arm64 AMI ID with a `data "aws_ami"` lookup (AMI IDs are
      per-region and per-architecture, and go stale as new AL2023 releases ship)
