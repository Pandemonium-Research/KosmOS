**AgentOS**

An Operating System for Agentic Workflows

Comprehensive Implementation Plan

*From Customised Linux Distribution to Bare-Metal Agent OS*

Version 1.0 --- March 2026

**CONFIDENTIAL --- INTERNAL USE ONLY**

Table of Contents

1\. Executive Summary

2\. Vision, Motivation, and Differentiation

3\. Landscape Analysis: What Exists Today

**3a. Phase 0: RunOS --- Weekend Spike**

4\. Strategic Approach: The Three-Horizon Plan

5\. Horizon 1: Customised Linux Distribution (AgentOS Alpha)

6\. Horizon 2: Purpose-Built OS with Custom Kernel Modules (AgentOS
Beta)

7\. Horizon 3: Bare-Metal Agent OS from Scratch (AgentOS 1.0)

8\. Architecture Deep Dive

9\. The Agent Contract Specification

10\. Security Architecture

11\. Real-Time and Latency Framework

12\. VM Testing and Validation Strategy

13\. Technology Stack and Tool Choices

14\. Development Phases and Timeline

15\. Risk Analysis and Mitigations

16\. Success Metrics and KPIs

17\. Team Structure and Skills Required

18\. References and Further Reading

1\. Executive Summary

This document is a comprehensive implementation plan for AgentOS, an
operating system purpose-built for managing, orchestrating, and running
AI agentic workflows. Just as Kali Linux became the canonical OS for
penetration testing by assembling the right tools, kernel
configurations, and security primitives into a cohesive distribution,
AgentOS aims to be the canonical OS for agentic AI --- the system you
boot when you need to build, deploy, monitor, and govern autonomous AI
agents.

The plan follows a three-horizon strategy, preceded by a Phase 0 weekend
spike called RunOS. Phase 0 is a 3-day build that produces a bootable
Ubuntu server image pre-loaded with LLMs, agent frameworks, and curated
tooling --- the Kali Linux of agentic AI --- to validate the base
platform feel before H1 engineering begins. Horizon 1 customises an
existing Linux distribution (Ubuntu Server 24.04 LTS) with agentic
tooling, pre-configured runtimes, and OS-level primitives for agent
lifecycle management. Horizon 2 introduces custom kernel modules, a
microkernel-style agent scheduler, and native MCP/A2A protocol support
at the OS level. Horizon 3 is the long-term moonshot: a bare-metal
operating system built from scratch around agent-first abstractions,
where agents are first-class citizens alongside processes and threads.

Each horizon is designed to be tested first as a virtual machine before
any bare-metal deployment. This document covers architecture,
requirements, technology choices, phased timelines, risk analysis, and
success metrics.

2\. Vision, Motivation, and Differentiation

2.1 The Problem

Current agentic AI systems are built as application-layer pipelines on
top of general-purpose operating systems. They lack OS-level guarantees
for scheduling, memory isolation, security, and real-time
responsiveness. Every team reinvents the wheel for state management,
tool access, concurrency control, and audit logging. This is the
equivalent of the pre-OS era in computing --- what the Agent-OS paper by
Koubaa (2025) describes as computational chaos.

The core problems that motivate AgentOS are:

-   **No unified lifecycle management:** Agents are started, stopped,
    and recovered using ad-hoc scripts. There is no standardised
    spawn/pause/resume/checkpoint/kill API at the OS level.

-   **No resource isolation:** Multiple agents competing for GPU memory,
    context windows, and API rate limits have no kernel-level
    arbitration. This leads to unpredictable behaviour and resource
    starvation.

-   **No security-by-design:** Tool access, data permissions, and audit
    trails are bolted on as application concerns rather than enforced by
    the OS kernel. Prompt injection and data exfiltration defences are
    ad-hoc.

-   **No real-time guarantees:** Interactive agents (speech, video) need
    sub-250ms first-token onset. Safety-critical agents (robotics) need
    10ms hard deadlines. No existing system formalises these as OS-level
    scheduling classes.

-   **No portability:** Agents are tightly coupled to specific
    frameworks, cloud providers, and model endpoints. Moving an agent
    between environments requires significant re-engineering.

2.2 The Vision

AgentOS will be the substrate on which agentic applications run,
providing the same level of abstraction that Unix/Linux provided for
traditional computing. The core analogy is: if LLMs are the CPUs of the
agentic era, AgentOS is the operating system that virtualises and
manages them.

Concretely, AgentOS will provide:

1.  Agent-as-process abstraction: Agents become first-class schedulable
    entities with defined lifecycles, resource quotas, and isolation
    guarantees.

2.  Kernel-enforced security: Zero-trust RBAC, capability-scoped tool
    access, encrypted memory regions, and tamper-evident audit logs ---
    all at the kernel level.

3.  Latency-class scheduling: Hard Real-Time (HRT), Soft Real-Time
    (SRT), and Delay-Tolerant (DT) scheduling classes with enforceable
    SLOs.

4.  Native protocol support: MCP for tool invocation, A2A for
    inter-agent communication, and OpenTelemetry for observability ---
    built into the OS stack.

5.  Agent Contracts: A portable, machine-readable specification
    (analogous to an ABI) that defines an agent's capabilities,
    constraints, SLOs, and policies. This enables cross-runtime
    portability.

2.3 Why Not Just Use AIOS?

AIOS (from Rutgers University) is the closest existing implementation.
It provides a three-layer architecture (Application / Kernel / Hardware)
with managers for scheduling, context, memory, storage, tools, and
access control, achieving approximately 2.1x faster agent execution.
However, AIOS has key limitations that AgentOS addresses:

-   AIOS runs as an application-layer runtime, not as an actual
    operating system. It sits on top of a general-purpose OS and cannot
    enforce true kernel-level isolation.

-   AIOS lacks formal real-time support. It provides latency
    optimisations but does not formalise HRT/SRT/DT classes with
    enforceable SLOs.

-   AIOS has basic HITL support (user confirmation for risky actions)
    but does not integrate humans deeply into workflow orchestration.

-   AIOS does not align with open standards like MCP and A2A for
    external interoperability; its protocol surface is runtime-internal.

-   AIOS does not provide Agent Contracts for portable, declarative
    agent definitions.

AgentOS will incorporate AIOS's proven concepts (LLM-as-core
abstraction, system-call-based architecture, context management) while
going further: delivering actual OS-level enforcement, real-time
scheduling classes, and standards-based interoperability.

2.4 Why Not Just a Framework?

Frameworks like LangChain, AutoGen, CrewAI, and others operate entirely
in userspace. They can be preempted, starved of resources, and cannot
enforce security policies at the hardware level. An OS-level approach
enables:

-   Hardware-level memory isolation between agents (using cgroups,
    namespaces, and eventually custom memory management).

-   Kernel-level scheduling that can preempt an agent consuming too many
    tokens.

-   Mandatory access control (MAC) policies that cannot be bypassed by
    application code.

-   Direct device access for robotics/IoT agents without userspace
    overhead.

-   Immutable audit logs enforced by the kernel, not by application code
    that an attacker could modify.

3\. Landscape Analysis: What Exists Today

Before building, it is critical to understand the existing ecosystem.
The following table maps the landscape:

  -------------------- ------------------- ------------------------ --------------------
  **System/Project**   **Type**            **Key Capabilities**     **Key Limitations**

  AIOS (Rutgers)       Application-layer   LLM-as-core, system      Not a real OS; no
                       runtime             calls,                   real-time classes;
                                           context/memory/tool      runtime-internal
                                           managers, SDK, 2.1x      protocols; basic
                                           speedup                  HITL

  Agent-OS (Koubaa     Conceptual          5-layer architecture,    Purely theoretical;
  paper)               blueprint           Agent Contracts,         no implementation
                                           HRT/SRT/DT classes,      exists
                                           zero-trust security      

  AgenticCore          Minimal Linux       LLM chat interface, code Very early; no agent
  (TinyCore-based)     distro              execution, Tiny Core     scheduling,
                                           base                     orchestration, or
                                                                    security primitives

  PwC Agent OS         Enterprise product  Cross-platform           Proprietary;
                                           orchestration, GPT-5     enterprise-only; no
                                           integration, cloud       OS-level enforcement
                                           connectors               

  KAOS (Kylin OS)      Research prototype  Management-role agents,  Built on specific
                                           resource scheduling,     Chinese OS; limited
                                           vertical collaboration   generalisability

  Manus / TARS         Cloud agent         Containerised Linux      Cloud-only; no
                       platforms           desktops for agents,     bare-metal; not a
                                           browser automation,      standalone OS
                                           multi-step tasks         

  Kali Linux (analogy) Security-focused    Pre-installed tools,     No agentic
                       distro              custom kernel,           capabilities; but
                                           security-focused         the model AgentOS
                                           defaults                 follows
  -------------------- ------------------- ------------------------ --------------------

The key insight from this landscape is that no one has built an actual
operating system for agentic workflows. AIOS comes closest as a runtime,
the Koubaa paper provides the best theoretical framework, and
AgenticCore shows that someone has attempted a minimal Linux distro ---
but none combine all three into a production-grade system. That is the
gap AgentOS fills.

3a. Phase 0: RunOS --- Weekend Spike

Before committing months of engineering to Horizon 1, RunOS is a 3-day
weekend build that produces a bootable, ready-to-use Ubuntu server image
--- the Kali Linux of agentic AI. The purpose is not to build anything
novel; it is to answer the question: what should the base platform feel
like when you boot it? Every tool you reach for during H1 development
should already be there, preconfigured and integrated. RunOS is the
blank canvas that gets painted on.

**What RunOS is not:** it is not agentd, not a daemon, not a kernel
module, not a protocol. It is purely a curated, opinionated
distribution. Everything in it is an existing, proven tool. The value is
in the selection, integration, and defaults --- not in new code.

P0.1 Base and Build Approach

Start from Ubuntu Server 24.04 LTS minimal. Use a single Packer
template + Ansible playbook to produce a QCOW2/OVA image and an
installable ISO. The entire build must be reproducible from a single
command. Target image size: under 8GB compressed. The build pipeline
itself is the primary deliverable of the weekend --- if the image can be
rebuilt from scratch in under 30 minutes, RunOS is done.

P0.2 LLM Layer

Ollama is installed and configured as a systemd service that starts on
boot. A default model (Qwen2.5-7B or Llama 3.2-3B for low-VRAM setups)
is pre-pulled into the image so the system is immediately usable without
network access. The Ollama API is exposed on localhost:11434. A
lightweight OpenAI-compatible proxy (LiteLLM) is configured so any tool
expecting the OpenAI API format works out of the box against the local
model. Cloud API keys (Anthropic, OpenAI) can be set via /etc/runos/env
and are automatically picked up by the proxy.

P0.3 Agent Runtime and Tools

The following agent frameworks and tools ship pre-installed and
importable, with no additional setup required. The selection is
deliberately minimal --- one tool per category, chosen for quality and
stability rather than breadth:

> **• LLM gateway:** Ollama (local serving) + LiteLLM (unified API
> proxy)
>
> **• Agent framework:** LangGraph (stateful multi-step agents) + Claude
> Code CLI (agentic coding)
>
> **• Tool protocol:** MCP server (FastMCP) running as a systemd service
> with a starter toolkit of tools: filesystem, shell exec, web fetch,
> and a calculator
>
> **• Vector memory:** ChromaDB (dev-friendly, zero-config) pre-seeded
> with a default collection
>
> **• Code execution sandbox:** bubblewrap-isolated Python subprocess
> runner (agents can execute code without escaping to the host)
>
> **• Search and scraping:** SearXNG (self-hosted search, no API key
> needed) + Playwright (headless browser automation)
>
> **• Workflow orchestration:** Temporal dev server (single-binary, no
> cluster required at this stage)
>
> **• Observability:** Grafana + Prometheus + Loki stack, pre-configured
> with a RunOS dashboard showing LLM token throughput, tool call counts,
> and agent process CPU/memory
>
> **• Dev environment:** Python 3.12 with uv package manager, Node.js
> LTS, Rust toolchain, and a pre-created virtualenv at /opt/runos/venv
> with key packages installed
>
> **• Security baseline:** UFW firewall with sensible defaults (all
> inbound blocked except SSH and local service ports), fail2ban,
> unattended-upgrades enabled, no root SSH

P0.4 Weekend Build Schedule

> **Day 1 --- Foundation:** Set up Packer + Ansible pipeline. Get a
> booting Ubuntu image with Ollama, LiteLLM, and Python environment.
> Verify model inference works end-to-end. Get SSH + UFW configured.
> End-of-day checkpoint: "can I SSH in and run a prompt against a local
> model?"
>
> **Day 2 --- Tooling:** Install and wire up MCP server, ChromaDB,
> LangGraph, SearXNG, Playwright, and Temporal dev server. Write a
> simple end-to-end test: an agent that uses search, stores results in
> Chroma, and returns a summary. End-of-day checkpoint: "can I run a
> 3-step agentic workflow with tool use?"
>
> **Day 3 --- Polish and Ship:** Install and configure Grafana +
> Prometheus + Loki. Write the RunOS MOTD (boot message showing all
> service statuses). Build the final QCOW2 image and ISO. Write a
> one-page README. End-of-day checkpoint: "can someone else boot this
> image and run an agent within 10 minutes, with zero setup?"

P0.5 What RunOS Deliberately Excludes

Scope discipline is as important as what gets included. RunOS explicitly
excludes: agentd or any custom lifecycle daemon (that is H1 work),
custom kernel configuration (H2 work), A2A messaging bus (H1 work),
Agent Contract schema (H1 work), vLLM or production serving
infrastructure (H1 work), and any custom shell or REPL. If it takes more
than a weekend to integrate, it does not belong in RunOS. The test:
would a senior engineer be surprised this took 3 days? If yes, cut it.

P0.6 Success Criteria

> • Boot to a working shell in under 60 seconds on a standard VM.
>
> • All services (Ollama, LiteLLM, MCP server, ChromaDB, Grafana) are
> running and healthy on first boot, confirmed by MOTD status output.
>
> • A new user can run a 3-step agentic workflow using the pre-installed
> tools within 10 minutes of first boot, with no additional
> installation.
>
> • The image rebuilds from scratch in under 30 minutes from the Packer
> template.
>
> • The Grafana dashboard shows live data within 2 minutes of a model
> inference call.

4\. Strategic Approach: The Three-Horizon Plan

Building an OS from scratch is a multi-year endeavour. The three-horizon
strategy ensures that each stage delivers usable value while building
toward the ultimate goal.

  ------------- ------------------ -------------- --------------------- ----------------
  **Horizon**   **Name**           **Duration**   **Deliverable**       **Deployment**

  **P0**        **RunOS (Weekend   **3 days**     **Bootable Ubuntu     **Bare-metal +
                Spike)**                          server with LLM,      VM**
                                                  agent runtime, and    
                                                  curated toolset       
                                                  pre-installed**       

  H1            AgentOS Alpha      6--12 months   Customised Ubuntu     VM first, then
                (Custom Distro)                   with agentic tooling  bare-metal

  H2            AgentOS Beta       12--24 months  Custom kernel         VM and select
                (Custom Kernel)                   modules + agent       hardware
                                                  scheduler             

  H3            AgentOS 1.0 (From  24--60 months  Purpose-built OS with Full bare-metal
                Scratch)                          agent-native          support
                                                  abstractions          
  ------------- ------------------ -------------- --------------------- ----------------

**Why this order matters:** Phase 0 (RunOS) comes first: a 3-day weekend
build that produces a bootable, usable image. It answers the question of
what the base platform should feel like before investing months in H1.
Each horizon then validates assumptions from the previous one. H1 lets
us test what agent primitives are actually needed at the OS level. H2
lets us validate kernel-level enforcement without building an entire OS.
H3 is only attempted after we have battle-tested abstractions from H1
and H2.

5\. Horizon 1: Customised Linux Distribution (AgentOS Alpha)

5.1 Base Distribution Choice: Ubuntu Server 24.04 LTS

Ubuntu Server 24.04 LTS is chosen as the base for the following reasons:

-   **Ecosystem depth:** Largest repository of AI/ML packages. NVIDIA
    CUDA, ROCm, PyTorch, TensorFlow, and Ollama all have first-class
    Ubuntu support.

-   **LTS stability:** 5-year support window ensures a stable foundation
    while we build on top.

-   **Kernel configurability:** Ubuntu allows custom kernel builds with
    minimal friction, critical for Horizon 2.

-   **Snap/APT ecosystem:** Simplifies packaging our agent-specific
    tooling for distribution.

-   **Cloud/VM compatibility:** Works seamlessly in QEMU/KVM,
    VirtualBox, VMware, and all major cloud providers for our VM-first
    testing strategy.

5.2 What Gets Customised

The customisation transforms a generic Ubuntu Server into an
agent-focused environment. The following subsections detail each
customisation layer.

5.2.1 Pre-installed Agent Runtimes and Frameworks

The distribution ships with a curated set of agent development and
execution tools:

-   Ollama (local LLM serving) --- pre-configured with popular models
    (Llama 3.x, Mistral, Qwen).

-   vLLM --- high-throughput LLM serving for production workloads.

-   LangChain, LangGraph, CrewAI, AutoGen --- major agent frameworks
    pre-installed.

-   Claude Code, OpenAI SDK, Google GenAI SDK --- cloud API clients
    configured.

-   ChromaDB, Qdrant, Milvus --- vector databases for RAG workflows.

-   Temporal --- workflow orchestration engine for durable agent
    workflows.

5.2.2 Agent Lifecycle Daemon (agentd)

This is the core custom component of H1. agentd is a system daemon
(analogous to systemd for processes) that manages agent lifecycles:

-   Agent registration: Agents are declared via Agent Contract YAML
    files (see Section 9).

-   Lifecycle management: spawn, pause, resume, checkpoint, kill APIs
    exposed via a Unix socket and REST API.

-   Resource quotas: cgroup-based CPU, memory, and GPU memory limits per
    agent.

-   Health monitoring: Heartbeat checks, automatic restarts on crash,
    and dead-letter queues for failed tasks.

-   Log aggregation: Structured JSON logs with correlation IDs, shipped
    to a local OpenTelemetry collector.

> sudo agentctl spawn \--contract /etc/agents/rag-planner.yaml \--class
> SRT
>
> sudo agentctl pause agent-rag-planner-001
>
> sudo agentctl checkpoint agent-rag-planner-001 \--dest
> /var/agent-checkpoints/

5.2.3 MCP Server (Native Tool Registry)

A system-level MCP (Model Context Protocol) server runs as a systemd
service. It provides:

-   A typed tool registry where tools are declared with JSON schemas and
    capability scopes.

-   Sandboxed tool execution using nsjail or bubblewrap containers.

-   Secret management integration (HashiCorp Vault or systemd-creds).

-   Audit logging of every tool invocation with input/output hashes.

Why at the OS level: Running MCP as a system service (rather than
per-agent) ensures consistent policy enforcement, shared tool caching,
and centralised audit logging.

5.2.4 A2A Message Bus

An inter-agent communication bus based on the A2A (Agent-to-Agent)
protocol specification. Implementation uses NATS or Redis Streams as the
transport layer, with:

-   Typed message envelopes (conversation IDs, performatives, schema
    versions).

-   Topic-based routing for marketplace, hierarchical, and blackboard
    patterns.

-   Message persistence for audit and replay.

-   Rate limiting and back-pressure per agent.

5.2.5 Observability Stack

Pre-configured and ready to use on first boot:

-   OpenTelemetry Collector --- receives traces, logs, and metrics from
    all agent components.

-   Prometheus --- metrics storage and alerting.

-   Grafana --- dashboards pre-configured with agent-specific panels
    (tokens/sec, first-token onset, tool latencies, RAG cache hits).

-   Loki --- log aggregation with agent correlation IDs.

-   Jaeger --- distributed tracing for multi-agent workflows.

5.2.6 Security Hardening

The distribution ships with security defaults that go beyond standard
Ubuntu:

-   AppArmor profiles for all agent processes, restricting filesystem,
    network, and device access.

-   Mandatory audit logging via auditd for all privileged operations.

-   Network segmentation: agent processes run in isolated network
    namespaces by default.

-   Encrypted agent memory: tmpfs mounts with dm-crypt for agent working
    directories.

-   Prompt injection defence: a content-filter proxy that sits between
    agents and LLM endpoints, scanning for known injection patterns.

5.2.7 GPU and Accelerator Support

Out-of-the-box GPU support is critical for any agent OS:

-   NVIDIA drivers and CUDA toolkit pre-installed, with GPU partitioning
    via MPS (Multi-Process Service) or MIG (Multi-Instance GPU) for
    agent-level GPU isolation.

-   ROCm support for AMD GPUs.

-   NPU support (Intel Meteor Lake, Qualcomm Hexagon) for edge
    deployments.

-   GPU memory accounting integrated with agentd resource quotas.

5.2.8 Agent CLI and Shell (agentsh)

A custom shell that serves as the primary interface:

-   Natural language command mode: Users can type natural language and
    the shell routes to the appropriate agent or system command.

-   Agent management commands: agentctl for lifecycle, agentlog for log
    tailing, agentmon for live monitoring.

-   Tab completion for agent names, tool names, and contract fields.

-   Built-in REPL for testing agent prompts and tool calls
    interactively.

5.3 Distribution Build Process

The custom distro is built using a reproducible pipeline:

6.  Start with Ubuntu Server 24.04 cloud image.

7.  Apply Packer template that installs all packages, configures
    services, and sets security defaults.

8.  Run Ansible playbooks for fine-grained configuration of agentd, MCP
    server, A2A bus, and observability stack.

9.  Generate ISO using live-build or Cubic for bare-metal installation.

10. Generate OVA/QCOW2/VMDK images for VM distribution.

11. Run automated test suite (see Section 12) against the built image.

12. Publish to a package repository for updates.

6\. Horizon 2: Purpose-Built OS with Custom Kernel Modules (AgentOS
Beta)

Horizon 2 extends the customised distribution with kernel-level agent
primitives. This is where AgentOS begins to diverge from being a mere
packaging of existing tools into a genuinely new kind of operating
system.

6.1 Custom Kernel Modules

6.1.1 Agent Scheduler Module (sched_agent)

A loadable kernel module that implements the three latency classes from
the Agent-OS paper:

-   **HRT (Hard Real-Time):** Earliest Deadline First (EDF) /
    Rate-Monotonic (RM) scheduling with CPU/GPU reservations, pinned
    threads, fixed memory arenas, and lock-free queues. For
    safety-critical agents (robotics, medical devices). Target: 1--20ms
    execution slices, jitter ≤5ms, zero deadline misses.

-   **SRT (Soft Real-Time):** Priority-queue scheduling with burst
    credits, streaming support, and adaptive buffering. For interactive
    agents (chat, speech, video). Target: 150--300ms first-token onset,
    0.8--1.2s full-turn, P95 jitter ≤20%.

-   **DT (Delay-Tolerant):** Best-effort queue-based scheduling with
    preemptible workers, aggressive batching, and resumable checkpoints.
    For batch workloads (RAG indexing, document processing). Target:
    SLAs in minutes--hours, maximise tokens/sec per dollar.

Why a kernel module: Linux's CFS (Completely Fair Scheduler) is designed
for general-purpose fairness. It does not understand token budgets,
model latencies, or the concept of an agent turn. sched_agent extends
the scheduler with agent-aware priority classes that map directly to the
HRT/SRT/DT taxonomy.

6.1.2 Agent Memory Manager (agentmm)

A kernel module that provides agent-aware memory management:

-   Per-agent memory namespaces with encryption-at-rest (using kernel
    keyring).

-   Context window management: kernel-level enforcement of
    max_context_tokens per agent, preventing runaway context growth.

-   Shared memory regions for inter-agent communication with
    capability-based access control.

-   Memory checkpointing: snapshot an agent's entire memory state for
    migration or recovery.

6.1.3 Agent Security Module (agentsec LSM)

A Linux Security Module (LSM) that enforces agent-specific security
policies:

-   Capability-scoped tool access: each agent's contract declares
    allowed tools; the LSM blocks all others at the kernel level.

-   Data flow tracking: prevents an agent from exfiltrating data outside
    its declared data scopes.

-   Tamper-evident audit log: kernel-level logging with cryptographic
    hash chains that cannot be modified by userspace code.

-   Consent gates: kernel-level hooks that pause execution and require
    human approval for high-risk operations (filesystem writes, network
    requests to new domains, payment operations).

6.2 Enhanced agentd (v2)

The Horizon 1 agentd daemon is rewritten to use the kernel modules:

-   Agent processes are created with the sched_agent scheduling class.

-   Memory allocation goes through agentmm for encrypted, quota-enforced
    namespaces.

-   Tool invocations are mediated by agentsec LSM, ensuring no bypasses.

-   Checkpointing uses kernel-level copy-on-write for near-instant
    snapshots.

6.3 Custom Kernel Build

The kernel is a custom build of the Linux kernel (based on the Ubuntu
HWE kernel) with:

-   CONFIG_PREEMPT_RT patch for real-time scheduling support (critical
    for HRT).

-   sched_agent, agentmm, and agentsec compiled as loadable modules.

-   Optimised CONFIG options for agentic workloads: higher HZ timer
    frequency (1000Hz), reduced scheduling latency, optimised cgroup v2
    support.

-   GPU scheduling patches for fair GPU time-slicing between agents.

7\. Horizon 3: Bare-Metal Agent OS from Scratch (AgentOS 1.0)

Horizon 3 is the long-term vision: a purpose-built operating system
where agents are the primary abstraction, not an afterthought bolted
onto a process model designed in 1969.

7.1 Microkernel Architecture

AgentOS 1.0 uses a microkernel design. The kernel contains only:

13. Agent lifecycle primitives (spawn, pause, resume, checkpoint,
    terminate).

14. Class-aware scheduling (HRT/SRT/DT with admission control).

15. Minimal IPC (message passing for agent-to-agent and agent-to-service
    communication).

16. Memory management with agent-aware namespaces and encryption.

17. Policy engine (capability-based access control with tamper-evident
    logging).

Everything else --- model serving, tool execution, memory/knowledge
services, observability --- runs as userspace services communicating
with the kernel via well-defined system calls.

7.2 Why a Microkernel

A microkernel approach is chosen over a monolithic kernel for several
reasons:

-   **Auditability:** A smaller kernel is easier to formally verify. For
    safety-critical deployments (medical, automotive), formal
    verification of the kernel's security and scheduling properties is
    essential.

-   **Fault isolation:** If a model serving component crashes, it does
    not bring down the kernel. The kernel restarts the service
    transparently.

-   **Modularity:** Services can be updated, replaced, or scaled
    independently. A new vector database can be swapped in without
    rebooting.

-   **Security surface:** Less code in the kernel means fewer potential
    vulnerabilities in the most privileged execution context.

7.3 Implementation Language

The kernel will be implemented in Rust with selective use of unsafe
blocks for hardware interaction. Rust is chosen because:

-   Memory safety without garbage collection --- critical for HRT agents
    where GC pauses would cause deadline misses.

-   Zero-cost abstractions enable high-level agent lifecycle management
    without runtime overhead.

-   The Rust ecosystem already has kernel-development support (the Linux
    kernel itself now accepts Rust modules).

-   AIOS has already begun an experimental Rust scaffold (aios-rs/) with
    trait definitions for context, memory, storage, tool, scheduler, and
    LLM abstractions --- validating Rust's viability for this domain.

7.4 Agent-Native Abstractions

In AgentOS 1.0, agents replace processes as the fundamental unit of
execution:

-   **AgentID:** A globally unique identifier with cryptographic
    attestation. Replaces PID.

-   **AgentContext:** The kernel-managed state of an agent --- prompt
    state, scratchpad, tool cursors, context window, and pending
    operations. Replaces process address space.

-   **AgentContract:** The declarative specification (capabilities,
    SLOs, policies, budgets) that the kernel validates before admitting
    an agent. Replaces executable metadata.

-   **AgentChannel:** Typed, capability-scoped IPC channels for
    agent-to-agent and agent-to-service communication. Replaces
    pipes/sockets.

-   **ToolCall:** A kernel-mediated system call for invoking external
    capabilities, validated against the agent's contract. Replaces
    system calls.

8\. Architecture Deep Dive

The five-layer architecture (adapted from the Koubaa Agent-OS paper) is
the consistent thread across all three horizons. Each horizon implements
the layers with increasing depth.

  --------------- --------------- ------------------ ------------------- ------------------
  **Layer**       **Role**        **H1               **H2                **H3
                                  Implementation**   Implementation**    Implementation**

  L5: User & App  User-facing     agentsh CLI, REST  Same + natural      Agent-native
                  interfaces,     API, web dashboard language shell      shell, visual
                  agent catalog,                     improvements        workflow editor
                  SDKs                                                   

  L4:             Workflow        Temporal           Same +              Native workflow
  Orchestration   engine, HITL    workflows, A2A     kernel-integrated   engine in
                  gates, agent    NATS bus           scheduling          userspace services
                  routing                                                

  L3: Agent       Agent           agentd daemon,     agentd v2 with      Kernel-native
  Runtime         execution,      cgroup isolation   kernel module       agent lifecycle
                  state                              integration         management
                  management,                                            
                  checkpoints                                            

  L2: Services    Memory/RAG,     ChromaDB, MCP      Same +              Userspace services
                  tool execution, server, OTel stack kernel-enforced     with kernel IPC
                  model gateway,                     tool access         
                  observability                                          

  L1: Kernel      Scheduling,     Linux kernel +     Custom kernel       Microkernel with
                  policy, context AppArmor + cgroups modules             agent-native
                  management,                        (sched_agent,       primitives
                  security                           agentmm, agentsec)  
  --------------- --------------- ------------------ ------------------- ------------------

8.1 Data Flow: A Request's Journey

When a user submits a task to AgentOS, the following flow occurs:

18. User Layer (L5): User submits task via agentsh, REST API, or web UI.
    An Agent Contract is attached (either explicit or from the Agent
    Catalog).

19. Orchestration Layer (L4): The workflow engine decomposes the task
    into steps. Each step is bound to an Agent Contract and assigned to
    a specialist agent.

20. Agent Runtime (L3): The assigned agent is spawned (or an existing
    instance is routed to). agentd creates the agent process with the
    appropriate scheduling class and resource quotas.

21. Kernel (L1): The kernel validates the Agent Contract against
    available resources (admission control). If schedulable, the agent
    is admitted; otherwise, the request is rejected with an explanation.

22. Services Layer (L2): The agent executes its logic, making ToolCalls
    (mediated by the kernel's policy engine) to the MCP server,
    memory/RAG services, and model gateway.

23. Observability: Every step emits OpenTelemetry traces with
    correlation IDs, creating an end-to-end audit trail.

24. Response: Results flow back up through the layers to the user, with
    citations and provenance attached.

8.2 Service Composition: Agent-as-a-Service

A powerful pattern enabled by the architecture is agent-as-a-service
composition. An agent can be registered in the Tool Registry (MCP
server) so that other agents can invoke it via standard tool-calling
semantics. The calling agent does not need to know it is invoking
another agent --- the kernel enforces all security and resource policies
transparently. This enables recursive composition of agents without
compromising isolation or auditability.

9\. The Agent Contract Specification

The Agent Contract is the single most important abstraction in AgentOS.
It serves as the portable, machine-readable definition of an agent,
analogous to an application binary interface (ABI) in traditional
systems.

9.1 Contract Schema (Illustrative)

> apiVersion: agentos/v0.2
>
> kind: AgentContract
>
> name: city-permit-assistant
>
> class:
>
> latency: SRT
>
> slo:
>
> onset_ms: 250
>
> turn_ms: 1000
>
> jitter_p95_pct: 20
>
> capabilities: \[\"web.fetch\", \"rag.retrieve\", \"summarize\"\]
>
> compute:
>
> cpu: \"2\"
>
> mem: \"4GiB\"
>
> gpu_mem: \"8GiB\"
>
> modelPolicy:
>
> allow: \[\"local/llama-3.1-8B\", \"cloud/claude-sonnet\"\]
>
> max_context_tokens: 32000
>
> placement: \[\"on-prem\", \"edge\"\]
>
> memory:
>
> namespace: \"city-planning\"
>
> retention_days: 90
>
> rag: { top_k: 8, require_grounding: true }
>
> security:
>
> consent_for: \[\"fs.write\", \"email.send\"\]
>
> data_scopes: \[\"city-permits\", \"public-records\"\]
>
> observability:
>
> tracing: opentelemetry
>
> log_fields: \[\"prompt\", \"sources\", \"tool_hashes\"\]

9.2 How the OS Uses the Contract

Every layer of the OS references the Agent Contract:

-   **Admission control (L1):** The kernel's admission controller
    validates that the declared latency class, compute requirements, and
    SLOs can be satisfied before admitting the agent.

-   **Scheduling (L1):** The class.latency field selects the scheduling
    algorithm: EDF/RM for HRT, priority queues for SRT, best-effort for
    DT.

-   **Tool access (L2):** The capabilities field is the allowlist. The
    MCP server blocks any tool not in this list. High-risk tools in
    security.consent_for require human approval.

-   **Memory/RAG (L2):** The memory field configures the agent's
    namespace, retention policy, and grounding requirements.

-   **Model routing (L2):** The modelPolicy constrains which models can
    be used and where they run (placement).

-   **Audit (cross-cutting):** The observability field ensures that all
    specified fields are captured in traces for compliance.

9.3 Binding Modes

Not all deployments can satisfy a contract perfectly. Three binding
modes handle this:

-   **Strict:** Every constraint is non-negotiable. Deployment is
    rejected on any mismatch. Used for safety-critical and
    compliance-sensitive agents.

-   **Smooth:** Allows version-compatible upgrades (newer model
    versions, compatible tool versions) with canary testing and
    automatic rollback on degradation.

-   **Flexible:** Policy-bounded substitutions are allowed (e.g.,
    falling back to a local model when cloud is unavailable). All
    substitutions are logged and auditable.

10\. Security Architecture

Security in AgentOS follows a zero-trust model: no agent executes
without a validated contract, no tool is invoked without capability
verification, and no action occurs without an audit trail.

10.1 Threat Model

The key threats AgentOS defends against:

-   **Prompt injection:** Malicious inputs that attempt to override
    agent instructions. Defence: content-filter proxy, instruction-data
    separation in prompts, and output validation.

-   **Data exfiltration:** An agent attempting to send sensitive data to
    unauthorised destinations. Defence: kernel-level data flow tracking,
    network namespace isolation, and output redaction.

-   **Privilege escalation:** An agent attempting to access tools or
    data beyond its contract. Defence: LSM-enforced capability scoping,
    no ambient authority.

-   **Side-channel attacks:** One agent inferring another's data through
    shared resources. Defence: memory encryption, timing-safe
    comparisons, and agent-level resource isolation.

-   **Supply chain:** Compromised tools or models. Defence: signed tool
    manifests, model checksums, and provenance tracking.

10.2 Defence-in-Depth Layers

  ------------- --------------------------- -------------------------------
  **Layer**     **Mechanism**               **What It Protects**

  Network       Per-agent network           Prevents unauthorised external
                namespaces, egress          communication
                firewalls, DNS filtering    

  Process       cgroups v2, seccomp-bpf,    Resource isolation and syscall
                AppArmor/agentsec LSM       filtering

  Memory        Encrypted tmpfs, kernel     Data at rest and in working
                keyring, agent namespaces   memory

  Application   MCP capability scoping,     Tool access and data leakage
                consent gates, output       
                redaction                   

  Audit         Tamper-evident logs with    Accountability and forensics
                hash chains, OTel traces    
  ------------- --------------------------- -------------------------------

11\. Real-Time and Latency Framework

The latency class system is what distinguishes AgentOS from every other
agent platform. It brings real-time systems thinking to the agentic
world.

  -------------- ------------------- ------------------- --------------------
  **Property**   **HRT (Hard         **SRT (Soft         **DT
                 Real-Time)**        Real-Time)**        (Delay-Tolerant)**

  Use case       Robotics, safety    Chatbots, speech    RAG indexing, batch
                 filters, medical    assistants, video   summarisation, code
                 devices             copilots            refactoring

  Deadline       1--20ms execution   150--300ms          Minutes to hours
                 slices              first-token onset   

  Jitter         ≤5ms                P95 ≤20%            N/A
  tolerance                                              

  Miss           System failure      User abandonment    Cost increase
  consequence                                            

  Scheduler      EDF /               Priority queues +   Best-effort +
                 Rate-Monotonic      burst credits       preemption

  Memory         Fixed arenas, no GC Rolling caches,     Standard
                                     adaptive buffers    allocation +
                                                         checkpoints

  Model          On-device, pinned   Edge/cloud with     Cloud batch,
  placement                          streaming           cost-optimised

  Acceptance     WCET profiling, 24h Latency             Throughput-cost
  test           burn-in, 0 misses   distributions, MOS  curves, checkpoint
                                     scores              fidelity
  -------------- ------------------- ------------------- --------------------

12\. VM Testing and Validation Strategy

Every horizon is VM-first. No component goes to bare-metal until it has
been thoroughly validated in virtualised environments.

12.1 VM Platform

-   Primary: QEMU/KVM on Linux hosts (closest to bare-metal
    performance).

-   Secondary: VirtualBox (for developer-accessible testing on any host
    OS).

-   Cloud: AWS EC2 bare-metal instances (i3.metal, g5.xlarge) for
    GPU-accelerated testing.

-   CI/CD: GitHub Actions with self-hosted runners using nested
    virtualisation.

12.2 Test Categories

  -------------- ------------------------------------ ------------------- --------------------
  **Category**   **What Is Tested**                   **Tools**           **Pass Criteria**

  Boot and Init  OS boots, all services start, agentd systemd-analyze,    Boot \< 30s, all
                 healthy                              custom boot checker services green

  Agent          spawn/pause/resume/checkpoint/kill   agentctl + pytest   100% lifecycle
  Lifecycle      for all latency classes              test suite          operations succeed

  Resource       CPU, memory, GPU quotas enforced     stress-ng,          No agent exceeds
  Isolation                                           gpu-burn, cgroup    declared quotas
                                                      monitors            

  Security       Capability enforcement, injection    Custom security     ≥95% injection
                 defence, data isolation              test suite + OWASP  deflection, 0
                                                      ZAP                 capability
                                                                          violations

  Performance    First-token onset, turn latency,     k6, locust, custom  Meets SLO targets
                 throughput                           LLM benchmarks      for each latency
                                                                          class

  Recovery       Checkpoint restore, crash recovery,  Chaos engineering   ≥99% recovery within
                 idempotent replay                    (litmus, pumba)     60s, 0 duplicate
                                                                          side effects

  Multi-agent    Orchestration, A2A messaging,        Multi-agent         Exactly-once
                 concurrent agent coordination        scenario scripts    semantics, no
                                                                          message loss
  -------------- ------------------------------------ ------------------- --------------------

12.3 Graduation to Bare-Metal

A component graduates from VM to bare-metal when:

25. All test categories pass at 100% for 7 consecutive days in VM.

26. Performance benchmarks in VM are within 10% of expected bare-metal
    performance.

27. At least 3 independent reviewers have signed off on the component's
    readiness.

28. A rollback plan is documented and tested.

13\. Technology Stack and Tool Choices

  --------------- --------------------- ----------------------------------
  **Component**   **Technology**        **Why This Choice**

  Base OS (H1)    Ubuntu Server 24.04   Best AI/ML ecosystem, LTS
                  LTS                   stability, CUDA support

  Agent daemon    Rust (tokio runtime)  Memory safety, async performance,
                                        no GC pauses for HRT

  MCP server      TypeScript (Node.js)  Ecosystem compatibility; Rust for
                  or Rust               H2+ performance

  A2A bus         NATS JetStream        Lightweight, persistent, supports
                                        typed subjects and back-pressure

  Workflow engine Temporal              Battle-tested durable workflows,
                                        exactly-once semantics, HITL
                                        support

  Vector DB       Qdrant (primary),     Rust-native, fast, supports
                  ChromaDB (dev)        namespaces and filtering

  LLM serving     Ollama (dev), vLLM    Ollama for ease; vLLM for
                  (prod)                continuous batching and throughput

  Observability   OTel + Prometheus +   Industry standard, extensible,
                  Grafana + Loki +      agent-aware dashboards
                  Jaeger                

  Security        AppArmor (H1), custom Progressive enforcement; Vault for
                  LSM (H2+), Vault      secrets

  GPU management  NVIDIA MPS/MIG, ROCm  Agent-level GPU partitioning

  Container       nsjail / bubblewrap   Lightweight tool sandboxing
  sandbox                               without full Docker overhead

  Build system    Packer + Ansible +    Reproducible image builds
                  live-build            

  CI/CD           GitHub Actions +      Nested virtualisation support for
                  self-hosted runners   VM testing

  Kernel (H3)     Custom microkernel in Memory safety, formal verification
                  Rust                  potential
  --------------- --------------------- ----------------------------------

14\. Development Phases and Timeline

14.0 Phase 0: RunOS (Days 1--3)

  ------------ ------------ ------------------------------------------------
  **Day**      **Focus**    **Deliverables and Checkpoint**

  Day 1        Foundation   Packer + Ansible pipeline; Ubuntu 24.04 base
                            image booting in QEMU; Ollama installed and
                            serving a default model; LiteLLM proxy
                            configured; SSH + UFW hardened. Checkpoint: SSH
                            in and run a prompt against a local LLM.

  Day 2        Tooling      FastMCP server (systemd service) with
                            filesystem, shell, web fetch, and calculator
                            tools; ChromaDB with default collection;
                            LangGraph + Claude Code CLI installed; SearXNG +
                            Playwright configured; Temporal dev server
                            running. Checkpoint: run a 3-step agentic
                            workflow with tool use.

  Day 3        Polish and   Grafana + Prometheus + Loki stack with RunOS
               Ship         dashboard; boot MOTD showing all service
                            statuses; QCOW2 image and installable ISO
                            generated; one-page README. Checkpoint: a new
                            user boots the image and runs an agent within 10
                            minutes, zero setup.
  ------------ ------------ ------------------------------------------------

14.1 Horizon 1 Phases (Months 1--12)

  ------------ -------------- ------------------------------------------------
  **Phase**    **Duration**   **Deliverables**

  1a:          Months 1--3    Base image build pipeline, agentd v0.1
  Foundation                  (spawn/kill), Agent Contract schema v0.1, MCP
                              server prototype, basic agentsh CLI

  1b: Core     Months 4--6    agentd v0.5 (full lifecycle), A2A bus on NATS,
  Services                    Temporal integration, OTel stack, GPU quota
                              management

  1c: Security Months 7--9    AppArmor profiles, encrypted memory, injection
  & Polish                    defence proxy, security test suite,
                              documentation

  1d: Beta &   Months 10--12  Public beta ISO/VM images, community feedback,
  Feedback                    bug fixes, performance tuning, first Agent
                              Catalog entries
  ------------ -------------- ------------------------------------------------

14.2 Horizon 2 Phases (Months 13--30)

  --------------- -------------- -------------------------------------------
  **Phase**       **Duration**   **Deliverables**

  2a: Kernel R&D  Months 13--18  sched_agent kernel module prototype,
                                 PREEMPT_RT integration, HRT scheduling
                                 validation

  2b: Memory &    Months 19--24  agentmm kernel module, agentsec LSM,
  Security                       kernel-level audit logging, agentd v2
                                 integration

  2c: Integration Months 25--30  Full kernel module integration, custom
  & Hardening                    kernel build pipeline, comprehensive test
                                 suite, performance benchmarking vs. H1
  --------------- -------------- -------------------------------------------

14.3 Horizon 3 Phases (Months 31--60+)

  ------------------ -------------- ----------------------------------------
  **Phase**          **Duration**   **Deliverables**

  3a: Microkernel    Months 31--40  Rust microkernel booting in QEMU, basic
  Bootstrap                         agent lifecycle, minimal IPC

  3b: Services &     Months 41--50  Userspace services (memory, tools,
  Drivers                           models, observability), hardware driver
                                    framework, filesystem

  3c: Integration &  Months 51--60+ Full OS stack, agent-native shell,
  Polish                            installer, documentation, first
                                    bare-metal boot
  ------------------ -------------- ----------------------------------------

15\. Risk Analysis and Mitigations

  ------------------ -------------- ---------------- ------------------------------------
  **Risk**           **Severity**   **Likelihood**   **Mitigation**

  Kernel module      Critical       Medium           Develop in VMs exclusively; use
  instability                                        KASAN/KCSAN for kernel sanitizers;
  crashes host OS                                    extensive fuzzing with syzkaller

  GPU scheduling     High           High             Start with NVIDIA MPS which is
  conflicts between                                  proven; invest in MIG for stronger
  agents                                             isolation; contribute upstream

  LLM stochasticity  Critical       High             For HRT, use small deterministic
  breaks HRT                                         models with fixed output lengths;
  guarantees                                         LLMs handle SRT/DT only; HRT uses
                                                     pre-validated lookup tables

  Standards          Medium         Medium           Version all contracts; adapter
  (MCP/A2A) evolve                                   pattern for protocol migration;
  incompatibly                                       participate in AAIF standards body

  Community adoption High           Medium           Release H1 early and free; target
  insufficient                                       specific niches (robotics labs,
                                                     smart city research); create
                                                     compelling tutorials

  Scope creep delays High           High             Strict phase gates; each phase has
  all horizons                                       frozen deliverables; no H2 work
                                                     begins until H1 beta ships

  Security           Critical       Medium           Red team exercises; bug bounty
  vulnerabilities in                                 programme; formal verification of
  agent isolation                                    security-critical kernel paths

  Performance        Medium         Medium           Continuous benchmarking; bypass
  overhead of                                        paths for DT agents where security
  security layers                                    overhead is less critical
  ------------------ -------------- ---------------- ------------------------------------

16\. Success Metrics and KPIs

16.1 Technical KPIs

  --------------------- ---------------- ---------------- ----------------
  **Metric**            **H1 Target**    **H2 Target**    **H3 Target**

  Agent spawn time      \< 5s            \< 1s            \< 100ms

  Checkpoint/restore    \< 30s           \< 5s            \< 500ms
  time                                                    

  HRT deadline miss     N/A (no HRT in   0% (over 24h     0% (over 7d
  rate                  H1)              burn-in)         burn-in)

  SRT first-token onset \< 500ms         \< 300ms         \< 200ms

  Injection deflection  ≥90%             ≥95%             ≥99%
  rate                                                    

  Security audit pass   100% (AppArmor)  100% (LSM)       100% (formal
  rate                                                    verification)

  Agent isolation       0%               0%               0%
  violation rate                                          

  Multi-agent           50               200              1000
  throughput                                              
  (agents/node)                                           
  --------------------- ---------------- ---------------- ----------------

16.2 Adoption KPIs

-   Phase 0 (RunOS): Working QCOW2 image and ISO built within 3 days;
    all 5 success criteria from Section P0.6 met; image shared
    internally for feedback.

-   H1 Beta: 100 GitHub stars, 20 active testers, 5 published Agent
    Contracts.

-   H1 GA: 1,000 downloads, 50 community-contributed tools in the Agent
    Catalog.

-   H2 Beta: 3 research groups using AgentOS for published papers.

-   H3 Preview: Demonstration at a major systems conference (OSDI, SOSP,
    or ASPLOS).

17\. Team Structure and Skills Required

  ----------------------- --------- ---------- ---------------------------------
  **Role**                **Count   **Count    **Key Skills**
                          (H1)**    (H2+)**    

  Systems/Kernel Engineer 1--2      3--4       Linux kernel development, Rust,
                                               real-time systems,
                                               cgroups/namespaces

  Agent Runtime Engineer  2--3      3--4       Python/Rust, LLM serving (vLLM,
                                               Ollama), agent frameworks
                                               (LangChain, AutoGen)

  Security Engineer       1         2          LSMs, AppArmor/SELinux,
                                               adversarial ML, formal methods

  Infrastructure/DevOps   1         2          Packer, Ansible, CI/CD, VM
                                               management, GPU orchestration

  Protocol/Standards      1         1--2       MCP, A2A, OpenTelemetry, protocol
  Engineer                                     design

  Frontend/UX (dashboard) 0--1      1          React/TypeScript, Grafana plugin
                                               development

  Technical Writer        0--1      1          Documentation, tutorials, API
                                               references
  ----------------------- --------- ---------- ---------------------------------

For a solo founder or very small team, Horizon 1 is achievable by
focusing on the agentd daemon and Agent Contract schema first, using
existing off-the-shelf components (NATS, Temporal, OTel) for everything
else. The custom kernel work in Horizon 2 requires specialised systems
programming expertise that should be hired or contracted for.

18\. References and Further Reading

Core references that inform this implementation plan:

29. Koubaa, A. (2025). Agent Operating Systems (Agent-OS): A Blueprint
    Architecture for Real-Time, Secure, and Scalable AI Agents.
    Preprints.org. doi:10.20944/preprints202509.0077.v1

30. Mei, K. et al. (2025). AIOS: LLM Agent Operating System. COLM 2025.
    arXiv:2403.16971

31. Ge, Y. et al. (2023). LLM as OS, Agents as Apps: Envisioning AIOS,
    Agents and the AIOS-Agent Ecosystem. arXiv:2312.03815

32. Daglis, A. et al. (2023). Siren: An Operating System for Real-Time
    Autonomous Systems. ASPLOS '23.

33. AIOS GitHub Repository. https://github.com/agiresearch/AIOS

34. AgenticCore GitHub Repository.
    https://github.com/MYusufY/agenticcore

35. Anthropic. Model Context Protocol (MCP).
    https://modelcontextprotocol.io

36. Google. Agent-to-Agent (A2A) Protocol. https://github.com/google/A2A

37. Linux Foundation. Agentic AI Foundation (AAIF).
    https://www.linuxfoundation.org/press/linux-foundation-announces-the-formation-of-the-agentic-ai-foundation

38. OpenTelemetry. https://opentelemetry.io

39. Martin, D.L. et al. (1999). The Open Agent Architecture. Applied
    Artificial Intelligence, 13, 91--128.

40. FIPA Agent Communication Language Specifications. Technical Report
    SC00061I, 2002.

*--- End of Document ---*
