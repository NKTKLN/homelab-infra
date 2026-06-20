# 🔌 GPU / PCI passthrough

Used only by `vm-gpu-worker-1`. To attach a PCI device (e.g. a GPU) you fill the
`pci_devices` variable in `terraform/envs/prod/terraform.tfvars`:

```hcl
pci_devices = [
  {
    name         = "tesla-v100"
    id           = "10de:1db1"    # vendor:device
    subsystem_id = "10de:1212"
    path         = "0000:05:00.0"
    iommu_group  = 17
  }
]
```

To skip passthrough entirely, set `pci_devices = []`.

## Host prerequisites

On the Proxmox host, IOMMU must be enabled and the device bound to `vfio-pci`:

* Kernel cmdline (GRUB): `amd_iommu=on iommu=pt` (Intel: `intel_iommu=on iommu=pt`)
* The target device should show `Kernel driver in use: vfio-pci`
* The device should sit in its **own** IOMMU group (otherwise all devices in the
  group must be passed through together)

## How to get these values

### 1. List PCI devices

```bash
lspci -nn
```

Example:

```text
05:00.0 3D controller [0302]: NVIDIA Corporation GV100GL [Tesla V100] [10de:1db1]
```

→ `id = 10de:1db1`, `path = 0000:05:00.0`

### 2. Get full device info

```bash
lspci -nnk -s 05:00.0
```

Look for:

```text
Subsystem: NVIDIA Corporation Device [10de:1212]
Kernel driver in use: vfio-pci
```

→ `subsystem_id = 10de:1212`

### 3. Get IOMMU group

```bash
find /sys/kernel/iommu_groups/ -type l | grep 05:00.0
```

Example:

```text
/sys/kernel/iommu_groups/17/devices/0000:05:00.0
```

→ `iommu_group = 17`

## NVIDIA driver / CUDA notes

The `cuda_tools` Ansible role installs the NVIDIA driver, CUDA toolkit and the
NVIDIA Container Toolkit (Docker runtime) on the GPU node. Keep the driver and
toolkit a compatible pair, e.g. for **Tesla V100** (Volta, `sm_70`):

* `nvidia-driver-580` — last branch with Volta support
* `cuda-toolkit-12-6` — CUDA 13 dropped Volta, so the 12.x branch is required
