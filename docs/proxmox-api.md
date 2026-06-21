# 🔑 Proxmox API token (for Terraform)

Terraform/OpenTofu authenticates to Proxmox with an API token instead of a
password. The token values go into `terraform/envs/prod/terraform.tfvars`.

## 1. Create role and user

On a Proxmox node:

```bash
# create role in PVE 8
pveum role add Terraform -privs "Datastore.Allocate \
  Datastore.AllocateSpace Datastore.AllocateTemplate \
  Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify \
  SDN.Use VM.Allocate VM.Audit VM.Clone VM.Config.CDROM \
  VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType \
  VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate \
  VM.PowerMgmt User.Modify Mapping.Modify"

# create group
pveum group add terraform-users

# add permissions
pveum acl modify / -group terraform-users -role Terraform

# create user 'terraform'
pveum useradd terraform@pve -groups terraform-users

# generate a token
pveum user token add terraform@pve token -privsep 0
```

## 2. Use in Terraform

```hcl
pve_api_url      = "https://<host>:8006/api2/json"
pve_token_id     = "terraform@pve!token"
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
