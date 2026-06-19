# Homelab Infrastructure — контекст для ассистента

Это IaC-репозиторий для управления домашним сервером на **Proxmox VE**.
Стек: **Terraform/OpenTofu** (провижининг) + **Ansible** (конфигурация).
Оркестрация команд — **Task** (`Taskfile.yml`), Python-окружение — **uv**.

## 1. Общая топология

- Один физический узел **Proxmox VE**.
- На нём поднимаются **7 VM** (Ubuntu 24.04 cloud image) и **1 LXC-контейнер**
  (Ubuntu 24.04 template).
- Вся LAN — `192.168.1.0/24`. Каждый узел имеет статический IP (cloud-init).
- На GPU-ноду пробрасывается видеокарта через **PCI passthrough**.
- Большой диск Proxmox-хоста отдаётся в storage-VM через **virtiofs**, оттуда
  раздаётся по **NFS**.
- Внешний доступ — через **WireGuard** на VPN-контейнере.
- Kubernetes — **k3s** (1 master + воркеры, включая GPU-воркер).

## 2. Узлы

| Хост | IP | Роль | CPU/RAM/Disk | Особенности |
|------|----|------|--------------|-------------|
| `ct-vpn` (LXC) | .11 | WireGuard VPN-шлюз | 1 / 1G / 10G | PVE-firewall: 22, 51820/udp, остальное DROP |
| `vm-sandbox` | .12 | Песочница | 2 / 2G / 20G | UFW выключен, docker, zsh |
| `vm-ops-node` | .13 | Управляющая нода | 2 / 3G / 20G | kubectl+CLI, ansible, docker context, NFS-клиент, fail2ban |
| `vm-storage-node` | .14 | Хранилище | 2 / 4G / 32G | virtiofs `/mnt/hard-drive`, NFS-сервер |
| `vm-k8s-master-1` | .15 | k3s master | 4 / 4G / 40G | отдаёт kubeconfig на ops |
| `vm-k8s-worker-1` | .16 | k3s worker | 4 / 6G / 40G | |
| `vm-k8s-gpu-worker-1` | .17 | k3s GPU worker | 4 / 6G / 60G | PCI passthrough GPU + CUDA |
| `vm-docker-worker` | .18 | Удалённый Docker-хост | 4 / 4G / 40G | управляется через docker context с ops |

Пользователь на VM — `nktkln`, на LXC — `root`. SSH-ключ `~/.ssh/id_ed25519`.

## 3. Terraform-слой (`terraform/envs/prod`)

- Провайдер **`bpg/proxmox`** (`>= 0.87`), Terraform `>= 1.6`. По умолчанию в
  Taskfile используется **`tofu`** (OpenTofu); переключается через `TF_PROVIDER`.
- `main.tf` содержит `locals.vm_definitions` и `locals.container_definitions` —
  это источник правды по «железу» (cores/memory/disk/ip/pci/virtiofs/firewall).
- Переиспользуемые модули: `modules/vm`, `modules/container`, `modules/image`.
- Аутентификация в Proxmox — **API-токен** (`terraform-prov@pve!terraform`),
  + SSH-агент для операций на хосте.
- Секреты/параметры — в `terraform.tfvars` (gitignored), пример в
  `terraform.tfvars.example`.
- **PVE-firewall выключен** для всех VM (`firewall_enable = false`); включён
  только на `ct-vpn`. Хостовой фаервол на VM делается на уровне Ansible (UFW).

## 4. Ansible-слой (`ansible/`)

- Инвентори: `inventory/home/hosts.ini`, переменные — в `group_vars/`.
- Единый плейбук: `playbooks/site.yml`. Конфиг — `ansible.cfg`.
- Маппинг групп → роли (из `site.yml`):

| Группа (хосты) | Применяемые роли |
|----------------|------------------|
| `vms` (все VM) | `common_baseline`, `base_server` |
| `containers` (ct-vpn) | `common_baseline`, `base_container` |
| `storage` | `virtiofs`, `nfs-server` |
| `vpn` | `wireguard` |
| `docker-workers` | `docker` |
| `gpu-workers` | `cuda_tools` |
| `k8s` | `k3s` |
| `sandbox` | `zsh`, `docker` |
| `all` | `ssh_trust` |
| `operations` | `zsh`, `nfs-client`, `fail2ban`, `ansible`, `kubernetes_tools`, `docker`, `docker_context` |

### Ключевые роли

- **base_server** — APT-апдейты, хардненг SSH (ключи только, ограничение
  алгоритмов), UFW (default deny incoming, allow SSH + порты из
  `ufw_allowed_ports_tcp/udp` по группам), MOTD, cleanup.
- **common_baseline** — базовые пакеты + sysctl-хардненг.
- **wireguard** — см. ниже.
- **nfs-server / nfs-client** — см. ниже.
- **kubernetes_tools** — ставит `kubectl`, копирует kubeconfig с мастера на ops
  (с заменой `127.0.0.1` на IP мастера), плюс CLI-тулзы: `helm` (apt),
  `k9s`, `stern`, `kustomize`, `helmfile`, `argocd`, `kubectx`, `kubens`
  (бинарники из GitHub-релизов, версии пинятся в `defaults`, идемпотентность
  через version-маркеры в `/usr/local/lib/kube-cli`).
- **k3s** — отключает swap, ставит k3s на мастер, читает node-token и kubeconfig,
  джойнит воркеров (`K3S_URL` на `https://<master>:6443`).
- **cuda_tools** — драйверы NVIDIA + container toolkit на GPU-ноде.
- **docker_context** — на ops создаёт docker context `homelab-docker-worker`
  (`ssh://nktkln@192.168.1.18:22`) для управления удалённым Docker.

## 5. Сеть / VPN (WireGuard, на `ct-vpn`)

- Endpoint `192.168.1.11:51820/udp`. WG-сеть `10.10.10.0/24`
  (сервер `.1`, пир `.10`). LAN `192.168.1.0/24`.
- На сервере включён `ip_forward`, NAT MASQUERADE на default-интерфейс **и**
  явные `iptables FORWARD ACCEPT` правила (нужны для роутинга в LAN).
- Два клиентских конфига генерируются и забираются на управляющую машину в
  `sensitive/wg_config/`:
  - **full-tunnel** (`wg0.conf`, `AllowedIPs = 0.0.0.0/0`, DNS 1.1.1.1);
  - **split-tunnel** (`wg0_split_tunnel.conf`, `AllowedIPs = 192.168.1.0/24,
    10.10.10.0/24`) — только доступ к homelab.

## 6. Хранилище / NFS

- На Proxmox-хосте большой диск пробрасывается в `vm-storage-node` через
  **virtiofs** в `/mnt/hard-drive`.
- Роль **nfs-server** экспортирует (для `192.168.1.0/24`):
  - `/mnt/hard-drive/nfs/docker` (fsid=1)
  - `/mnt/hard-drive/nfs/k8s` (fsid=2)
- Роль **nfs-client** монтирует шары. Сейчас `vm-ops-node` монтирует
  `docker`-экспорт в `/mnt/nfs/docker` (декларация в `group_vars/operations.yml`,
  переменная `nfs_client_mounts`).

## 7. Фаервол (хостовой UFW, через base_server)

Default: deny incoming / allow outgoing, всегда открыт SSH. Доп. порты по группам:

| Группа | TCP | UDP |
|--------|-----|-----|
| `storage` | 2049, 111 | 111 |
| `k8s` | 10250, 30000:32767 | 8472 |
| `k8s-master` | 6443, 10250, 30000:32767 | 8472 |
| `sandbox` | — (UFW **выключен**) | — |
| `ct-vpn` | фаервол на уровне PVE (22, 51820), не UFW | |

## 8. Рабочий процесс (Task)

```bash
# Terraform/OpenTofu
task tf-all        # fmt → init → validate → plan
task tf-apply      # применить
task tf-deploy     # init → apply

# Ansible
task ansible-checks   # yamllint + ansible-lint + syntax-check
task ansible-check    # dry-run (--check)
task ansible-deploy   # lint → check → apply
task ansible-run      # просто apply

# Прочее
task ansible-ping
task scripts-refresh-known-hosts
```

Точечный запуск роли:
`uv run ansible-playbook -i inventory/home/hosts.ini playbooks/site.yml --tags <tag> --limit <group>`

## 9. Конвенции и важные нюансы

- **Коммиты** — Conventional Commits со скоупом и описанием с заглавной буквы,
  напр. `feat(ansible): Add k3s setup role`, `fix(wireguard): Fix ...`.
  В репозитории настроен **commitizen** (`task cz-commit`).
- **Линтеры**: `yamllint` + `yamlfmt` + `ansible-lint` (профиль `basic`).
  По репо есть известные допускаемые отклонения: безымянные `import_tasks`,
  префикс переменных `<область>_*` вместо имени роли, использование
  `ansible.builtin.mount`. **Новый код пишем в стиле существующего**, а не
  «по букве» линтера.
- **Pre-commit** включён (`task precommit`).
- **Секреты не коммитим**: `terraform.tfvars`, каталог `sensitive/` —
  в `.gitignore`.
- Узлы **приватные** (за NAT/LAN), поэтому CD-паттерн — pull-based (GitOps
  изнутри кластера), а не push из GitHub-раннеров.
- Кластерные приложения (ArgoCD, чарты и т.п.) планируется вынести в **отдельный
  репозиторий**; здесь — только инфраструктура и host-level тулзы.

## 10. Текущее состояние

- Базовая инфраструктура (VM/LXC, baseline, SSH-доверие, k3s, GPU/CUDA,
  docker-worker + context, NFS, WireGuard) реализована в IaC.
- Последние изменения: фикс форвардинга в WireGuard (split-tunnel), роль
  `nfs-client` (монтаж storage→ops), CLI-toolbelt для k8s на ops-ноде.
- Ничего из этого не «прокатано» против живых нод в рамках текущей сессии —
  применять через `task ansible-deploy` / `--tags`.
