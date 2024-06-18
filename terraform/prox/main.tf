terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = ">= 2.9.6"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true  # Set to true if you're using a self-signed certificate
}

resource "proxmox_vm_qemu" "new_vm" {
  name        = "new-centos9-vm"     # Name of the new VM
  target_node = "apollonis"          # Node name
  os_type     = "l26"                # Operating system type (Linux 2.6)
  iso         = "local:iso/CentOS-Stream-9-20230918.0-x86_64-dvd1.iso"  # Path to the ISO image

  cores       = 2
  sockets     = 1
  memory      = 4096                 # Memory size in MB

  disk {
    type      = "virtio"             # Disk type (try scsi, sata, ide, or virtio)
    storage   = "local-lvm"          # Storage where the VM disk will reside
    size      = "20G"                # Disk size
  }

  network {
    model     = "virtio"             # Network adapter model
    bridge    = "vmbr0"              # Bridge interface to connect to
  }

  bootdisk = "virtio0"               # Specify the boot disk (match the disk type)
  boot     = "cdn"                   # Boot order: d (disk), c (CD-ROM), n (network)

  # Additional VM options
  balloon = 0
  kvm     = true
}

