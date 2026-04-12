# KosmOS

**Kernel Orchestration Substrate for Machines** — Phase 0 of AgentOS.

A bootable Ubuntu 24.04 server image pre-loaded with LLMs, agent frameworks, and curated tooling. Boot it. SSH in. Run an agent. No setup required.

---

## Prerequisites

- [Packer](https://developer.hashicorp.com/packer/install) ≥ 1.11
- [QEMU](https://www.qemu.org/download/) with KVM support (`qemu-system-x86_64`)
- Ansible (`pip install ansible`)
- ~50 GB free disk space (models + image)
- 8 GB RAM minimum for the build VM (models run fine with less on the final image)

```bash
packer plugins install github.com/hashicorp/qemu
packer plugins install github.com/hashicorp/ansible
```

---

## Build

```bash
packer build build/kosmos.pkr.hcl
```

Full rebuild from scratch in under 30 minutes on a modern machine with a warm model cache. Output lands in `dist/`:

```
dist/kosmos.qcow2   — QEMU disk image, ready to boot
```

---

## Run

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -m 8192 \
  -smp 4 \
  -drive file=dist/kosmos.qcow2,format=qcow2 \
  -net nic -net user,hostfwd=tcp::2222-:22,hostfwd=tcp::4000-:4000,hostfwd=tcp::3000-:3000 \
  -nographic
```

Then SSH in:

```bash
ssh -p 2222 kosmos@localhost   # password: kosmos
```

---

## First steps

Everything is running. The MOTD shows live service status.

**Talk to a local LLM:**
```bash
curl http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer kosmos-local" \
  -d '{"model": "qwen2.5:7b", "messages": [{"role": "user", "content": "hello"}]}'
```

**Run the 3-step agent test:**
```bash
python tests/agent_e2e.py
```

**Run smoke tests:**
```bash
bash tests/smoke.sh
```

**Open Grafana:** `http://localhost:3000` — username `admin`, password `kosmos`

**Set cloud API keys:**
```bash
sudo vim /etc/kosmos/env
sudo systemctl restart litellm
```

---

## Stack

| Category | Tool | Port |
|---|---|---|
| LLM serving | Ollama | 11434 |
| LLM gateway | LiteLLM | 4000 |
| Default model | Qwen2.5-7B | — |
| Agent framework | LangGraph | — |
| Agentic coding | Claude Code CLI | — |
| MCP tools | FastMCP | 8080 |
| Vector memory | ChromaDB | 8000 |
| Code sandbox | bubblewrap | — |
| Search | SearXNG | 8888 |
| Browser automation | Playwright + Chromium | — |
| Workflow engine | Temporal dev server | 7233 / 8233 |
| Metrics | Prometheus | 9090 |
| Logs | Loki + Promtail | 3100 |
| Dashboards | Grafana | 3000 |
| Python env | Python 3.12 + uv | `/opt/kosmos/venv` |

---

## Structure

```
kosmOS/
├── build/
│   ├── kosmos.pkr.hcl         # Packer template — single entry point
│   ├── http/                  # Ubuntu autoinstall cloud-init
│   └── ansible/
│       ├── site.yml           # master playbook
│       ├── roles/
│       │   ├── base/          # UFW, fail2ban, SSH hardening
│       │   ├── llm/           # Ollama + LiteLLM + model pull
│       │   ├── agent/         # Python 3.12 + uv, Node.js, Rust, Claude Code
│       │   ├── tools/         # FastMCP, SearXNG, Playwright
│       │   ├── memory/        # ChromaDB
│       │   ├── workflow/      # Temporal dev server
│       │   └── observe/       # Prometheus + Loki + Grafana
│       └── vars/
│           └── defaults.yml   # ports, model names, config
├── config/
│   └── kosmos.env.example     # API key template
├── motd/
│   └── kosmos-motd.sh         # boot message with live service status
├── tests/
│   ├── smoke.sh               # all services green?
│   └── agent_e2e.py           # 3-step agentic workflow test
└── dist/                      # gitignored — built images land here
```

---

## Success criteria

| Criteria | Target |
|---|---|
| Boot time | Shell in < 60s |
| Service health | All green on first boot (MOTD confirms) |
| Time to first agent | 3-step workflow within 10 min, zero setup |
| Rebuild time | < 30 min from scratch |
| Observability | Grafana shows live data within 2 min of first inference |

---

*KosmOS is Phase 0 of AgentOS. H1 layers on top of these Ansible roles — it does not start over.*
