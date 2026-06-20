# 🔑 Proxmox API token (for Terraform)

Terraform/OpenTofu authenticates to Proxmox with an API token instead of a
password. The token values go into `terraform/envs/prod/terraform.tfvars`.

## 1. Create role and user

On a Proxmox node:

```bash
pveum role add TerraformProv -privs "VM.Allocate VM.Config.* VM.PowerMgmt Datastore.AllocateSpace Datastore.AllocateTemplate Sys.Audit"

pveum user add terraform-prov@pve --password <password>

pveum aclmod / -user terraform-prov@pve -role TerraformProv
```

## 2. Create API token

In the **Proxmox Web UI**:

1. Datacenter → Permissions → API Tokens
2. Click **Add**
3. User: `terraform-prov@pve`
4. Token ID: `terraform`
5. Disable **Privilege separation** (recommended for simplicity)
6. Save and copy the **Secret**

## 3. Use in Terraform

```hcl
pve_api_url      = "https://<host>:8006/api2/json"
pve_token_id     = "terraform-prov@pve!terraform"
pve_token_secret = "<secret>"
pve_ssh_username = "root"
```

> `pve_ssh_username` is the SSH user the provider uses on the Proxmox host
> (needed for snippets / VirtioFS hardware mappings).

## Storage prerequisite

The datastore used for cloud-init (`snippets_storage`, default `local`) must have
the **Snippets** content type enabled, otherwise VM creation fails when uploading
user-data:

* UI: Datacenter → Storage → `local` → Edit → Content → enable **Snippets**
* or CLI: `pvesm set local --content <existing-types>,snippets`
