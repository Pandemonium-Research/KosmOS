# KosmOS — Phase 0
**KOSM: Kernel Orchestration Substrate for Machines**

> A 3-day weekend build. Bootable Ubuntu server image pre-loaded with LLMs, agent frameworks, and curated tooling. The Kali Linux of agentic AI. No novel code — just the right tools, the right defaults, and a reproducible build pipeline.

KosmOS is Phase 0 of [AgentOS](../AgentOS_Implementation_Plan_v2.md). It answers one question before months of H1 engineering begin: *what should the base platform feel like when you boot it?*

---

## Repo

```
github.com/your-org/kosmOS
```

### Structure

```
kosmOS/
├── README.md
├── build/
│   ├── kosmos.pkr.hcl         # Packer template — single entry point
│   └── ansible/
│       ├── site.yml           # master playbook
│       ├── roles/
│       │   ├── base/          # Ubuntu hardening, UFW, fail2ban, SSH
│       │   ├── llm/           # Ollama + LiteLLM + model pull
│       │   ├── agent/         # LangGraph, Claude Code CLI, Python env
│       │   ├── tools/         # FastMCP server, SearXNG, Playwright
│       │   ├── memory/        # ChromaDB
│       │   ├── workflow/      # Temporal dev server
│       │   └── observe/       # Grafana + Prometheus + Loki
│       └── vars/
│           └── defaults.yml   # model choice, ports, env config
├── config/
│   └── kosmos.env.example     # API keys template — committed
│                              # kosmos.env — gitignored
├── motd/
│   └── kosmos-motd.sh         # boot message with live service status
├── tests/
│   ├── smoke.sh               # all services green?
│   └── agent_e2e.py           # 3-step agentic workflow test
└── dist/                      # gitignored — built images land here
    ├── kosmos.qcow2
    └── kosmos.iso
```

### Build

```bash
packer build build/kosmos.pkr.hcl
```

Produces `dist/kosmos.qcow2` and `dist/kosmos.iso`. Full rebuild from scratch in under 30 minutes.

---

## What KosmOS Is Not

KosmOS is not agentd, not a lifecycle daemon, not a kernel module, not a protocol, not a custom shell. Every component is an existing, proven tool. The value is in the selection, integration, and defaults — not in new code.

If it takes more than a weekend to integrate, it does not belong in KosmOS.

---

## Stack

| Category | Tool | Notes |
|---|---|---|
| LLM serving | Ollama | systemd service, starts on boot |
| LLM gateway | LiteLLM | OpenAI-compatible proxy on `localhost:4000` |
| Default model | Qwen2.5-7B or Llama 3.2-3B | pre-pulled into image, works offline |
| Agent framework | LangGraph | stateful multi-step agents |
| Agentic coding | Claude Code CLI | pre-installed, picks up API key from env |
| Tool protocol | FastMCP | systemd service with starter toolkit |
| MCP tools (default) | filesystem, shell exec, web fetch, calculator | wired up on boot |
| Vector memory | ChromaDB | zero-config, default collection pre-created |
| Code sandbox | bubblewrap | isolated Python subprocess runner |
| Search | SearXNG | self-hosted, no API key needed |
| Browser automation | Playwright | headless, pre-installed with Chromium |
| Workflow engine | Temporal dev server | single binary, no cluster |
| Metrics | Prometheus | scrapes Ollama, node, and service metrics |
| Logs | Loki + Promtail | aggregates all service logs |
| Dashboards | Grafana | KosmOS dashboard pre-configured on boot |
| Python env | Python 3.12 + uv | `/opt/kosmos/venv` with key packages installed |
| Runtimes | Node.js LTS, Rust toolchain | pre-installed |
| Security | UFW, fail2ban, unattended-upgrades | no root SSH, all inbound blocked except SSH + service ports |

### Cloud API Keys

Set in `/etc/kosmos/env` — picked up automatically by LiteLLM:

```bash
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
```

Copy from `config/kosmos.env.example`.

---

## Build Schedule

### Day 1 — Foundation

**Goal:** Packer + Ansible pipeline. Booting Ubuntu image with LLM inference working end-to-end.

Tasks:
- Set up Packer template targeting Ubuntu 24.04 LTS minimal
- Write `base` role: UFW, fail2ban, SSH hardening, unattended-upgrades, no root SSH
- Write `llm` role: Ollama install, systemd service, default model pull, LiteLLM proxy
- Write `agent` role: Python 3.12 + uv, Node.js, Rust, `/opt/kosmos/venv`
- Verify QCOW2 boots in QEMU and all services start clean

**End-of-day checkpoint:** SSH into the image and run a prompt against a local model.

```bash
curl http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "ollama/qwen2.5:7b", "messages": [{"role": "user", "content": "hello"}]}'
```

---

### Day 2 — Tooling

**Goal:** Full agent tool stack wired up and tested with a live agentic workflow.

Tasks:
- Write `tools` role: FastMCP systemd service with filesystem, shell, web fetch, calculator tools
- Write `memory` role: ChromaDB install, default collection, health check
- Install LangGraph, Claude Code CLI into venv
- Write `workflow` role: Temporal dev server (single binary, systemd service)
- Install SearXNG (Docker or native) and Playwright with Chromium
- Write `tests/agent_e2e.py`: agent that uses SearXNG to search, stores results in ChromaDB, returns a grounded summary

**End-of-day checkpoint:** `python tests/agent_e2e.py` passes — 3-step agentic workflow with tool use completes successfully.

---

### Day 3 — Polish and Ship

**Goal:** Observability stack, boot experience, and distributable image.

Tasks:
- Write `observe` role: Prometheus + Loki + Promtail + Grafana
- Build KosmOS Grafana dashboard: LLM token throughput, tool call counts, agent process CPU/memory, service health
- Write `motd/kosmos-motd.sh`: boot message showing live status of all services (green/red)
- Wire motd into `/etc/update-motd.d/`
- Write `tests/smoke.sh`: checks all services are running and healthy
- Generate final QCOW2 and ISO
- Write README

**End-of-day checkpoint:** Hand the image to someone who has not seen it. They should be running an agent within 10 minutes with zero additional setup.

---

## Success Criteria

| Criteria | Pass condition |
|---|---|
| Boot time | Shell available in under 60 seconds on a standard VM |
| Service health | All services running and healthy on first boot, confirmed by MOTD |
| Time to first agent | New user runs a 3-step agentic workflow within 10 minutes of first boot, zero setup |
| Rebuild time | Full image rebuild from Packer template in under 30 minutes |
| Observability | Grafana dashboard shows live data within 2 minutes of a model inference call |

---

## What KosmOS Deliberately Excludes

These are H1+ concerns. If they appear in a PR against this repo, reject them.

- `agentd` or any custom lifecycle daemon
- Custom kernel configuration or kernel modules
- A2A messaging bus
- Agent Contract schema
- vLLM or production serving infrastructure
- Custom shell or REPL
- Any code that didn't exist before this weekend

---

## Handoff to H1

The Ansible roles in KosmOS are the starting point for AgentOS Alpha (H1). They are not thrown away — H1 layers on top of them. Specifically:

- `roles/llm/` → extended in H1 with vLLM for production serving
- `roles/tools/` → extended in H1 with the full MCP tool registry and sandboxed execution
- `roles/observe/` → extended in H1 with OpenTelemetry and Jaeger
- `roles/agent/` → replaced in H1 by `agentd` once the daemon is built
- `roles/memory/` → extended in H1 with Qdrant for production workloads

KosmOS is the blank canvas. H1 is where the painting begins.

---

*KosmOS is Phase 0 of AgentOS — [full implementation plan here](../AgentOS_Implementation_Plan_v2.md)*
