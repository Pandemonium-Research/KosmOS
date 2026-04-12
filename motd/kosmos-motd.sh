#!/usr/bin/env bash
# KosmOS MOTD — displayed on login.
# Installed to /etc/update-motd.d/99-kosmos

# Colors
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

dot_status() {
  local name="$1"
  local check_cmd="$2"

  if eval "$check_cmd" &>/dev/null; then
    printf "  ${GREEN}●${NC} %-22s" "$name"
  else
    printf "  ${RED}●${NC} %-22s" "$name"
  fi
}

http_ok() {
  curl -fsS --max-time 2 "$1" -o /dev/null 2>/dev/null
}

tcp_ok() {
  nc -z -w2 "$1" "$2" 2>/dev/null
}

svc_ok() {
  systemctl is-active --quiet "$1" 2>/dev/null
}

# ── Banner ─────────────────────────────────────────────────────────────────────
cat << 'EOF'

  ██╗  ██╗ ██████╗ ███████╗███╗   ███╗ ██████╗ ███████╗
  ██║ ██╔╝██╔═══██╗██╔════╝████╗ ████║██╔═══██╗██╔════╝
  █████╔╝ ██║   ██║███████╗██╔████╔██║██║   ██║███████╗
  ██╔═██╗ ██║   ██║╚════██║██║╚██╔╝██║██║   ██║╚════██║
  ██║  ██╗╚██████╔╝███████║██║ ╚═╝ ██║╚██████╔╝███████║
  ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝     ╚═╝ ╚═════╝ ╚══════╝
  Kernel Orchestration Substrate for Machines — Phase 0
EOF

echo ""

# ── System info ────────────────────────────────────────────────────────────────
HOSTNAME=$(hostname)
UPTIME=$(uptime -p 2>/dev/null || uptime | awk '{print $3,$4}')
CPU_LOAD=$(cut -d' ' -f1 /proc/loadavg)
MEM_TOTAL=$(awk '/MemTotal/ {printf "%.0f", $2/1024}' /proc/meminfo)
MEM_FREE=$(awk '/MemAvailable/ {printf "%.0f", $2/1024}' /proc/meminfo)
MEM_USED=$((MEM_TOTAL - MEM_FREE))
DISK=$(df -h / | awk 'NR==2 {print $3"/"$2" ("$5" used)"}')

printf "${BOLD}  System${NC}\n"
printf "  %-14s %s\n" "Host:" "$HOSTNAME"
printf "  %-14s %s\n" "Uptime:" "$UPTIME"
printf "  %-14s %s  (load: %s)\n" "CPU:" "$(nproc) cores" "$CPU_LOAD"
printf "  %-14s %s MB / %s MB used\n" "Memory:" "$MEM_USED" "$MEM_TOTAL"
printf "  %-14s %s\n" "Disk (/):" "$DISK"
echo ""

# ── Service status ─────────────────────────────────────────────────────────────
printf "${BOLD}  Services${NC}\n"

dot_status "Ollama :11434"    "http_ok http://127.0.0.1:11434/api/tags"
dot_status "LiteLLM :4000"   "http_ok http://127.0.0.1:4000/health"
echo ""

dot_status "FastMCP :8080"   "tcp_ok 127.0.0.1 8080"
dot_status "SearXNG :8888"   "http_ok http://127.0.0.1:8888"
echo ""

dot_status "ChromaDB :8000"  "http_ok http://127.0.0.1:8000/api/v1/heartbeat"
dot_status "Temporal :8233"  "tcp_ok 127.0.0.1 8233"
echo ""

dot_status "Grafana :3000"   "http_ok http://127.0.0.1:3000"
dot_status "Prometheus :9090" "http_ok http://127.0.0.1:9090/-/healthy"
echo ""

# ── Models ─────────────────────────────────────────────────────────────────────
MODELS=$(curl -s --max-time 3 http://127.0.0.1:11434/api/tags 2>/dev/null \
  | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    names = [m['name'] for m in d.get('models', [])]
    print(', '.join(names) if names else 'none')
except:
    print('unavailable')
" 2>/dev/null || echo "unavailable")

echo ""
printf "${BOLD}  Models${NC}   %s\n" "$MODELS"

# ── Quick start ────────────────────────────────────────────────────────────────
echo ""
printf "${BOLD}  Quick start${NC}\n"
printf "  ${CYAN}%-38s${NC}  LLM via LiteLLM\n" "curl http://localhost:4000/v1/chat/completions"
printf "  ${CYAN}%-38s${NC}  E2E agent test\n"   "python ~/tests/agent_e2e.py"
printf "  ${CYAN}%-38s${NC}  Grafana dashboard\n" "open http://localhost:3000  (admin/kosmos)"
printf "  ${CYAN}%-38s${NC}  Temporal UI\n"       "open http://localhost:8233"
printf "  ${CYAN}%-38s${NC}  Service health\n"    "bash ~/tests/smoke.sh"
echo ""
printf "  ${DIM}API keys: /etc/kosmos/env${NC}\n"
echo ""
