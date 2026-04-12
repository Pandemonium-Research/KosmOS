#!/usr/bin/env bash
# Install Packer from the official HashiCorp apt repository.
set -euo pipefail

if which packer >/dev/null 2>&1; then
  echo "packer already installed: $(packer version)"
  exit 0
fi

echo "Installing Packer from HashiCorp releases..."

PACKER_VERSION=$(curl -fsSL "https://checkpoint-api.hashicorp.com/v1/check/packer" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['current_version'])")
echo "Version: ${PACKER_VERSION}"

TMP=$(mktemp -d)
curl -fsSL "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip" \
  -o "${TMP}/packer.zip"
unzip -o "${TMP}/packer.zip" -d "${TMP}/bin"
sudo mv "${TMP}/bin/packer" /usr/local/bin/packer
rm -rf "${TMP}"

echo "Installed: $(packer version)"
