terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
    }
  }
}

provider "proxmox" {
  pm_api_url = var.pm_api_url
  pm_api_token_id = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure = true  # Set to false in production for better security
}

resource "proxmox_vm_qemu" "test-clone" {
  name        = "VM-test"
  desc        = "Virtual Machine 108 (gold-img-centos9) on node 'apollonis'"  # Description of the VM
  target_node = "apollonis"

  clone   = "gold-img-centos9"  # ID or name of the VM template or source VM to clone from
  cores   = 2
  sockets = 2
  memory  = 8192     
}

