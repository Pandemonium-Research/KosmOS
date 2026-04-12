#!/usr/bin/env bash
# Boot the KosmOS QCOW2 image with KVM acceleration.
# All service ports are forwarded 1:1 to localhost so tests can run from the host.
#
# Port map:
#   2222  → 22    SSH
#   11434 → 11434 Ollama
#   4000  → 4000  LiteLLM
#   8000  → 8000  ChromaDB
#   8080  → 8080  FastMCP
#   8888  → 8888  SearXNG
#   8233  → 8233  Temporal UI
#   7233  → 7233  Temporal gRPC
#   9090  → 9090  Prometheus
#   3000  → 3000  Grafana
#   3100  → 3100  Loki
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DISK="${REPO_ROOT}/dist/kosmos.qcow2"

if [[ ! -f "$DISK" ]]; then
  echo "ERROR: $DISK not found. Run 'make build' first." >&2
  exit 1
fi

exec qemu-system-x86_64 \
  -enable-kvm \
  -m 8192 \
  -smp 4 \
  -drive file="$DISK",format=qcow2 \
  -nographic \
  -serial mon:stdio \
  -net nic \
  -net user,\
hostfwd=tcp::2222-:22,\
hostfwd=tcp::11434-:11434,\
hostfwd=tcp::4000-:4000,\
hostfwd=tcp::8000-:8000,\
hostfwd=tcp::8080-:8080,\
hostfwd=tcp::8888-:8888,\
hostfwd=tcp::8233-:8233,\
hostfwd=tcp::7233-:7233,\
hostfwd=tcp::9090-:9090,\
hostfwd=tcp::3000-:3000,\
hostfwd=tcp::3100-:3100
