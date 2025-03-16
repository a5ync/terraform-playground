# Terraform GCP Nginx VM Deployment

This Terraform configuration provisions a secure Nginx server on Google Cloud Platform (GCP) along with minimal IAM and monitoring setup.

## Usage

```sh
terraform init     # Initialize backend and modules
terraform plan     # Review resources before applying
terraform apply    # Deploys the resources
terraform output ssh_command # Connect via SSH using the provided output:
```

## Features

- **Remote State Backend**: Stores Terraform state in a Google Cloud Storage (GCS) bucket.
- **Provider Configuration**: Deploys resources in a user-defined GCP project and region.
- **Service Account**: Creates a dedicated service account (`ops-agent-sa`) with permissions to:
  - Write logs to Cloud Logging (`roles/logging.logWriter`)
  - Write metrics to Cloud Monitoring (`roles/monitoring.metricWriter`)
- **Compute Engine VM**:
  - Deploys a `e2-micro` instance running Debian 11.
  - Attaches the service account with limited scopes.
  - Executes a startup script (`startup.sh`) to bootstrap Nginx.
  - Assigns a public IP and SSH access.
- **Firewall Rules**:
  - Allows **HTTPS (443)** and **SSH (22)** only from your specified IP (`var.my_ip`).
- **Outputs**:
  - Public IP of the Nginx server.
  - Pre-generated SSH command.
  - HTTPS URL for accessing the server.

## Prerequisites

- A GCS bucket to store Terraform state (`terraform-state-smart-howl`).
- A GCP project with Compute Engine and IAM permissions.
- SSH keypair (the script expects `~/.ssh/id_ap8.pub`).
- A `terraform.tfvars` file to set:

  ```hcl
  project_id = "your-project-id"
  region     = "us-west1"
  zone       = "us-west1-b"
  ssh_user   = "your-username"
  my_ip      = "x.x.x.x/32"

## Design Notes

This setup separates configuration (terraform.tfvars) from the main Terraform script (main.tf) to promote reusability and modularity.

Sensitive values like project IDs, regions, IP addresses, and SSH usernames are externalized to variables, avoiding hardcoding secrets directly in the infrastructure code.

- SSH keys are injected into the instance via metadata.
- Ops Agent is installed via the provided startup script to collect logs and metrics.

## Post-creation GCP checks

Couple useful checks after creating the instance

```sh
# load variables fromterraform.tfvars into env to automate examples with gcloud validations
eval $(python3 -c "import re; [print(f'{k}=\"{v}\"') for line in open('terraform.tfvars') if (m := re.match(r'^\s*(\w+)\s*=\s*\"?(.*?)\"?\s*$', line)) for k,v in [m.groups()]]")
echo $project_id $region $zone $my_ip

gcloud compute instances describe nginx-server --zone=$zone

# confirm scopes of ops-agent-sa service account
gcloud compute instances describe nginx-server \
    --zone=$zone --format="value(serviceAccounts)"

# {'email': 'ops-agent-sa@something.iam.gserviceaccount.com', 'scopes': ['https://www.googleapis.com/auth/logging.write', 'https://www.googleapis.com/auth/monitoring.write']}

# confirm firewall rules
gcloud compute firewall-rules list \
  --filter="sourceRanges=('$my_ip')" \
  --format="table(name,network,direction,sourceRanges,allowed,targetTags)"

# NAME         NETWORK  DIRECTION  SOURCE_RANGES       ALLOWED                                    TARGET_TAGS
# allow-https  default  INGRESS    ['my_ip/32']  [{'IPProtocol': 'tcp', 'ports': ['443']}]  ['https-server']
# allow-ssh    default  INGRESS    ['my_ip/32']  [{'IPProtocol': 'tcp', 'ports': ['22']}]   ['https-server']
```

## Cleanup

To destroy all resources:

```sh
terraform destroy -auto-approve
```
