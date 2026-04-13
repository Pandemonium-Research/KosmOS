# KosmOS

**Kernel Orchestration Substrate for Machines** — Phase 0 of AgentOS.

A bootable Ubuntu 24.04 server image pre-loaded with LLMs, agent frameworks, and curated tooling. Boot it. SSH in. Run an agent. No setup required.

---

## Prerequisites

- [QEMU](https://www.qemu.org/download/) with KVM support (`qemu-system-x86_64`)
- Ansible (`pip install ansible`)
- ~50 GB free disk space (models + image)
- 8 GB RAM minimum for the build VM

Packer is installed automatically by `make build` if missing.

---

## Build

### First time (fresh clone)

The build uses SSH key authentication — no passwords. Before the first build, generate the Packer SSH keypair:

```bash
make keygen
```

This creates `build/http/packer_key` (the private key, gitignored) and patches `build/http/user-data` to embed the matching public key in the image. You only need to run this once per clone.

> **Team workflow:** One person runs `make keygen` and commits the updated `packer_key.pub` + `user-data`. Everyone else gets the private key out-of-band (e.g. a shared secret store) and drops it at `build/http/packer_key`.

### Building the image

```bash
make build
```

Checks for the Packer key, installs Packer if needed, then runs `packer build`. Output lands in `dist/kosmos.qcow2`. Full build takes ~60–90 minutes (includes pulling ~7 GB of Ollama models).

To rebuild from scratch: `make build` always wipes `dist/` first.

---

## Run

```bash
make run    # boots in background, all 11 service ports forwarded to localhost
```

All service ports are forwarded 1:1 so you can reach any service directly from the host (see `scripts/run.sh`).

Then SSH in:

```bash
ssh -p 2222 -i build/http/packer_key kosmos@localhost
```

To shut down: `make stop`

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

**Run all tests (smoke + agent e2e):**
```bash
make test
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
├── Makefile                   # build / run / stop / test targets
├── scripts/
│   ├── install-packer.sh      # installs Packer from HashiCorp apt repo
│   └── run.sh                 # boots QCOW2 with all 11 ports forwarded
├── build/
│   ├── kosmos.pkr.hcl         # Packer template — single entry point
│   ├── http/
│   │   ├── user-data          # Ubuntu autoinstall cloud-init config
│   │   ├── packer_key.pub     # Packer SSH public key (committed)
│   │   └── packer_key         # Packer SSH private key (gitignored — run make keygen)
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
