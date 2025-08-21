#cloud-config
hostname: ${name}
ssh_pwauth: true
chpasswd:
  expire: false
users:
  - name: ${username}
    lock_passwd: false
    passwd: ${password_hash}   # SHA-512 hash (starts with $6$)
    shell: /bin/bash
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    ssh_authorized_keys:
      - ${ssh_key}

fs_setup:
  - label: ETCD
    filesystem: ext4
    device: /dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1  # scsi1
    overwrite: true
    extra_opts: ["-E", "lazy_itable_init=0,lazy_journal_init=0"]
  - label: CONTAINERD
    filesystem: ext4
    device: /dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi2  # scsi2
    overwrite: true
  - label: KUBELET
    filesystem: ext4
    device: /dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi3  # scsi3
    overwrite: true
  - label: PODLOGS
    filesystem: ext4
    device: /dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi4  # scsi4
    overwrite: true

mounts:
  - [ "LABEL=ETCD",       "/var/lib/rancher/rke2/server/db", "ext4", "noatime,discard,commit=100", "0", "2" ]
  - [ "LABEL=CONTAINERD", "/var/lib/rancher/rke2/agent/containerd", "ext4", "noatime,discard", "0", "2" ]
  - [ "LABEL=KUBELET",    "/var/lib/kubelet",               "ext4", "noatime,discard", "0", "2" ]
  - [ "LABEL=PODLOGS",    "/var/log/pods",                  "ext4", "noatime,discard", "0", "2" ]

write_files:
  - path: /etc/logrotate.d/k8s-pods
    owner: root:root
    permissions: "0644"
    content: |
      /var/log/pods/*/*.log {
        daily
        rotate 14
        compress
        missingok
        notifempty
        copytruncate
      }

runcmd:
  # Garantir dirs e permissões
  - [ bash, -lc, "mkdir -p /var/lib/rancher/rke2/server/db /var/lib/rancher/rke2/agent/containerd /var/lib/kubelet /var/log/pods" ]
  - [ bash, -lc, "chown -R root:root /var/lib/kubelet /var/log/pods" ]
  # Opcional: tunar sysctl para etcd e IO
  - [ bash, -lc, "sysctl -w vm.dirty_background_ratio=5 vm.dirty_ratio=20" ]
