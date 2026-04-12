#!/usr/bin/env bash
# KosmOS smoke test — checks all services are running and healthy.
# Exit code: 0 = all green, 1 = one or more services failed.

set -euo pipefail

PASS=0
FAIL=1
overall=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; overall=1; }
info() { echo -e "  ${YELLOW}→${NC} $1"; }

check_systemd() {
  local name="$1"
  if systemctl is-active --quiet "$name"; then
    pass "systemd: $name is active"
  else
    fail "systemd: $name is not active ($(systemctl is-active "$name"))"
  fi
}

check_http() {
  local name="$1"
  local url="$2"
  local expected="${3:-200}"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
  if [[ "$code" == "$expected" ]]; then
    pass "http: $name responded $code"
  else
    fail "http: $name — expected $expected, got $code (url: $url)"
  fi
}

check_tcp() {
  local name="$1"
  local host="$2"
  local port="$3"
  if nc -z -w3 "$host" "$port" 2>/dev/null; then
    pass "tcp: $name is listening on $host:$port"
  else
    fail "tcp: $name is not listening on $host:$port"
  fi
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  KosmOS Smoke Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "[ systemd services ]"
check_systemd ollama
check_systemd litellm
check_systemd fastmcp
check_systemd chromadb
check_systemd temporal
check_systemd searxng
check_systemd prometheus
check_systemd node_exporter
check_systemd loki
check_systemd promtail
check_systemd grafana-server
echo ""

echo "[ HTTP endpoints ]"
check_http "Ollama" "http://127.0.0.1:11434/api/tags"
check_http "LiteLLM" "http://127.0.0.1:4000/health"
check_http "ChromaDB" "http://127.0.0.1:8000/api/v1/heartbeat"
check_http "SearXNG" "http://127.0.0.1:8888" "200"
check_http "Temporal UI" "http://127.0.0.1:8233" "200"
check_http "Grafana" "http://127.0.0.1:3000" "200"
check_http "Prometheus" "http://127.0.0.1:9090/-/healthy"
check_http "Loki" "http://127.0.0.1:3100/ready"
echo ""

echo "[ TCP ports ]"
check_tcp "FastMCP" "127.0.0.1" "8080"
check_tcp "Temporal gRPC" "127.0.0.1" "7233"
echo ""

echo "[ LLM inference — end-to-end ]"
info "Running a prompt through LiteLLM → Ollama..."
RESPONSE=$(curl -s --max-time 60 http://127.0.0.1:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer kosmos-local" \
  -d '{"model":"qwen2.5:7b","messages":[{"role":"user","content":"Reply with the single word: OK"}],"max_tokens":10}' \
  2>/dev/null || echo "")

if echo "$RESPONSE" | grep -qi "ok\|content"; then
  pass "LLM inference responded"
else
  fail "LLM inference failed or timed out"
  info "Response: ${RESPONSE:0:200}"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $overall -eq 0 ]]; then
  echo -e "  ${GREEN}ALL CHECKS PASSED${NC}"
else
  echo -e "  ${RED}SOME CHECKS FAILED${NC} — review output above"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit $overall
