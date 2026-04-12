#!/usr/bin/env bash
# Install Packer from the official HashiCorp apt repository.
set -euo pipefail

if which packer >/dev/null 2>&1; then
  echo "packer already installed: $(packer version)"
  exit 0
fi

echo "Installing Packer from HashiCorp apt repo..."

wget -O- https://apt.releases.hashicorp.com/gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt-get update -qq
sudo apt-get install -y packer

echo "Installed: $(packer version)"
