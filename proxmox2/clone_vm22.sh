#!/bin/bash

# Configuration
API_URL="https://10.10.30.98:8006/api2/json"
TOKEN_ID="prashanths@pvetoken-id3"
TOKEN_SECRET="c304e7c4-3b13-490a-9b62-fa0edc85856e"
TARGET_NODE="apollonis"
TEMPLATE_NAME="gold-img-centos9"  # Name of the template VM
NEW_VM_NAME="sandbox-terraform"

# Function to log messages
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

log "Starting VM clone process."

# Get the VM ID based on the VM name
log "Fetching VM ID for template name: $TEMPLATE_NAME"
template_vm_id=$(curl -k -s -X GET "${API_URL}/nodes/${TARGET_NODE}/qemu" \
    --header "Authorization: PVEAPIToken=${TOKEN_ID}=${TOKEN_SECRET}" | \
    jq -r '.data[] | select(.name == "'"${TEMPLATE_NAME}"'") | .vmid')

if [ -z "$template_vm_id" ]; then
  log "Failed to find template VM with name: $TEMPLATE_NAME"
  exit 1
fi

log "Template VM ID: $template_vm_id"

# Find an available VM ID
log "Finding an available VM ID"
used_vm_ids=$(curl -k -s -X GET "${API_URL}/cluster/resources?type=vm" \
    --header "Authorization: PVEAPIToken=${TOKEN_ID}=${TOKEN_SECRET}" | \
    jq -r '.data[].vmid')
available_vm_id=$(seq 100 999 | grep -v -F -x -f <(echo "$used_vm_ids") | head -n 1)

if [ -z "$available_vm_id" ]; then
  log "Failed to find an available VM ID"
  exit 1
fi

log "Available VM ID: $available_vm_id"

# Clone the VM
clone_response=$(curl -k -s -X POST "${API_URL}/nodes/${TARGET_NODE}/qemu/${template_vm_id}/clone" \
    --header "Authorization: PVEAPIToken=${TOKEN_ID}=${TOKEN_SECRET}" \
    -d "newid=${available_vm_id}" \
    -d "name=${NEW_VM_NAME}" \
    -d "target=${TARGET_NODE}" \
    -d "full=1")

log "Clone response: $clone_response"

# Extract the VMID of the new VM
NEW_VM_ID=$(echo $clone_response | jq -r '.data | .vmid')

# Check if cloning was successful
if [ "$NEW_VM_ID" == "null" ] || [ -z "$NEW_VM_ID" ]; then
  log "Failed to clone the VM. Response: $clone_response"
  exit 1
fi

log "Successfully cloned VM. New VM ID: $NEW_VM_ID"

# Start the new VM (optional)
start_response=$(curl -k -s -X POST "${API_URL}/nodes/${TARGET_NODE}/qemu/${NEW_VM_ID}/status/start" \
    --header "Authorization: PVEAPIToken=${TOKEN_ID}=${TOKEN_SECRET}")

log "Start VM response: $start_response"

