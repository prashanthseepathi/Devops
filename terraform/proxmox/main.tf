terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.14"
    }
  }
}

provider "proxmox" {
  pm_api_url = "https://10.10.30.98:8006/api2/json"
  pm_api_token_id = "prashanths@pve!token-id3" // Replace with your actual API token ID
  pm_api_token_secret = "c304e7c4-3b13-490a-9b62-fa0edc85856e" // Replace with your actual API token secret
  pm_tls_insecure = true
}

resource "proxmox_vm_qemu" "new_server_from_template" {
  name        = "sandbox-terraform"
  target_node = "apollonis"
  clone       = "gold-img-centos9"

  // Explicitly defining to match the template's specs to ensure no unwanted changes
  memory      = 8192
  cores       = 2
}


output "new_vm_id" {
  value = proxmox_vm_qemu.new_server_from_template.id
  description = "The ID of the newly created VM."
}
