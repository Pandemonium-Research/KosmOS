# KosmOS Test Report

**Date:** 2026-04-12  
**Scope:** Static analysis — build pipeline, Ansible roles, templates, tests, scripts  
**Build:** No live VM available; QEMU/KVM build not executed. All findings are from code review and static analysis.

---

## Summary

| Severity | Count |
|---|---|
| Critical | 2 |
| High | 5 |
| Medium | 7 |
| Low | 8 |
| **Total** | **22** |

Shell scripts (`smoke.sh`, `kosmos-motd.sh`) pass `bash -n` syntax check.  
Python files (`agent_e2e.py`, `mcp_server.py`) pass `ast.parse()` syntax check.  
All YAML templates parse cleanly after Jinja2 substitution, except the `.service` files (systemd INI format, not YAML — correct by design).

---

## Critical

### C1 — Role ordering: venv created before Python 3.12 is fully set up

**File:** [build/ansible/roles/llm/tasks/main.yml](build/ansible/roles/llm/tasks/main.yml#L71-L78) / [build/ansible/site.yml](build/ansible/site.yml)

The `llm` role (runs second) installs `litellm[proxy]` using the Ansible `pip` module with `virtualenv: /opt/kosmos/venv` and `virtualenv_python: python3.12`. The `agent` role (runs third) later creates the same venv with `uv venv --python python3.12`.

Two problems:
1. The `pip` module creates the venv first; the `uv venv` task in `agent` skips it (`creates: .../activate`). Packages installed by `llm` are fine, but packages installed later by `agent`'s `uv pip install` go into the same pip-created venv (without uv's lock guarantees).
2. If Ubuntu 24.04's system Python 3.12 differs from the deadsnakes one (or is missing `venv`), the `pip` task in `llm` fails before the PPA is added.

**Fix:** Move venv creation to the `base` role or a dedicated pre-step, so all subsequent roles share a single creation point.

---

### C2 — Rust `creates` guard is always false → rustup re-runs on every Ansible execution

**File:** [build/ansible/roles/agent/tasks/main.yml](build/ansible/roles/agent/tasks/main.yml#L103-L113)

```yaml
- name: Install Rust via rustup (system-wide)
  shell: |
    curl ... | sh -s -- -y --no-modify-path --default-toolchain stable
  args:
    creates: /root/.cargo/bin/rustc      # ← wrong path
  environment:
    CARGO_HOME: /usr/local/cargo         # ← rustup installs HERE
    RUSTUP_HOME: /usr/local/rustup
```

`CARGO_HOME=/usr/local/cargo` tells rustup to install its binaries to `/usr/local/cargo/bin/rustc`. The `creates` guard checks `/root/.cargo/bin/rustc`, which will never exist. The shell task therefore re-downloads and re-runs the rustup installer on every Ansible run.

**Fix:**
```yaml
creates: /usr/local/cargo/bin/rustc
```

---

## High

### H1 — Grafana "KosmOS Logs" panel has no Loki datasource → panel always errors

**File:** [build/ansible/roles/observe/files/kosmos-dashboard.json](build/ansible/roles/observe/files/kosmos-dashboard.json)

The `KosmOS Logs` panel issues the Loki LogQL query `{job="kosmos"}` but its `datasource` field is `{}` (empty). Grafana will route it to the default datasource (Prometheus), which cannot handle LogQL. Every user opening the dashboard will see an error on this panel.

All other panels also have `datasource: {}` but their PromQL queries work fine because Prometheus is the default datasource.

**Fix:** Set an explicit Loki datasource on the logs panel:
```json
"datasource": { "type": "loki", "uid": "loki" }
```
and provision Grafana's Loki datasource with `uid: loki` in [grafana-datasources.yaml.j2](build/ansible/roles/observe/templates/grafana-datasources.yaml.j2).

---

### H2 — Loki retention will never be enforced → disk fills unboundedly

**File:** [build/ansible/roles/observe/templates/loki-config.yaml.j2](build/ansible/roles/observe/templates/loki-config.yaml.j2)

```yaml
limits_config:
  retention_period: 168h   # 7 days
```

Loki requires a `compactor` section with `retention_enabled: true` for `retention_period` to have any effect. Without it, chunks accumulate indefinitely in `/var/lib/loki/chunks`.

**Fix:** Add to `loki-config.yaml.j2`:
```yaml
compactor:
  working_directory: /var/lib/loki/compactor
  retention_enabled: true
  retention_delete_delay: 2h
```

---

### H3 — Prometheus scrapes Ollama at `/metrics` — endpoint does not exist

**File:** [build/ansible/roles/observe/templates/prometheus.yml.j2](build/ansible/roles/observe/templates/prometheus.yml.j2#L11-L14)

```yaml
- job_name: ollama
  metrics_path: /metrics
  static_configs:
    - targets: ["{{ ollama_host }}:{{ ollama_port }}"]
```

Ollama does not expose a Prometheus `/metrics` endpoint. All scrape attempts will return `404`, polluting Prometheus with perpetual up=0 alerts and error logs.

**Fix:** Remove the `ollama` scrape job, or replace it with the correct Ollama metrics path if a future Ollama version adds one. For now, use `node_exporter` and process-level metrics to track Ollama resource usage.

---

### H4 — `/opt/kosmos/motd` directory never created → MOTD copy may fail

**File:** [build/ansible/roles/base/tasks/main.yml](build/ansible/roles/base/tasks/main.yml#L99-L117)

The directory loop creates `/opt/kosmos` but not `/opt/kosmos/motd`:

```yaml
loop:
  - "{{ kosmos_config_dir }}"
  - "{{ kosmos_data_dir }}"
  - "{{ kosmos_log_dir }}"
  - /opt/kosmos           # ← created
```

Then immediately:
```yaml
- name: Copy MOTD script to /opt/kosmos/motd
  copy:
    dest: /opt/kosmos/motd/kosmos-motd.sh  # ← parent dir missing
```

Ansible's `copy` module will fail if the parent directory (`/opt/kosmos/motd/`) does not exist.

**Fix:** Add `/opt/kosmos/motd` to the directory creation loop, or use `file: state=directory` before the copy.

---

### H5 — MOTD file duplication and mismatch

**Files:** [build/ansible/roles/base/files/kosmos-motd.sh](build/ansible/roles/base/files/kosmos-motd.sh) vs [motd/kosmos-motd.sh](motd/kosmos-motd.sh)

There are two MOTD files with completely different contents:

| File | Size | Purpose |
|---|---|---|
| `roles/base/files/kosmos-motd.sh` | 174 bytes | Thin stub: `exec /opt/kosmos/motd/kosmos-motd.sh` |
| `motd/kosmos-motd.sh` | 3,604 bytes | Full MOTD implementation |

`motd.yml` installs the stub to `/etc/update-motd.d/99-kosmos`, which then calls the full script from `/opt/kosmos/motd/`. `base/main.yml` copies the full script to `/opt/kosmos/motd/kosmos-motd.sh`. This architecture works but is fragile: if the `/opt/kosmos/motd/` copy fails (see H4), the installed MOTD stub will silently fail. The two-file design also makes maintenance confusing.

---

## Medium

### M1 — `uv` install path inconsistency masked by `ignore_errors: true`

**File:** [build/ansible/roles/agent/tasks/main.yml](build/ansible/roles/agent/tasks/main.yml#L28-L42)

```yaml
- name: Install uv
  shell: curl -LsSf https://astral.sh/uv/install.sh | sh
  args:
    creates: /root/.local/bin/uv      # default path
  environment:
    UV_INSTALL_DIR: /usr/local/bin    # astral.sh installs here instead
```

When `UV_INSTALL_DIR=/usr/local/bin` is set, `astral.sh` installs `uv` to `/usr/local/bin/uv` — not `/root/.local/bin/uv`. The `creates` guard therefore never fires, and the installer runs on every build. The subsequent symlink task (`src: /root/.local/bin/uv`) would then create a dangling symlink (the source doesn't exist), but `ignore_errors: true` hides this failure.

**Fix:** Set `creates: /usr/local/bin/uv` to match `UV_INSTALL_DIR`, and remove the now-unnecessary symlink task.

---

### M2 — `python3.12-distutils` package does not exist in Ubuntu 24.04

**File:** [build/ansible/roles/agent/tasks/main.yml](build/ansible/roles/agent/tasks/main.yml#L14-L25)

```yaml
- python3.12-distutils   # ← removed from stdlib in Python 3.12; no Ubuntu 24.04 package
```

`distutils` was removed from the Python 3.12 standard library, and Ubuntu 24.04 does not ship a `python3.12-distutils` backport package. Installing this package will cause the apt task to fail with "Unable to locate package".

**Fix:** Remove `python3.12-distutils` from the package list. `uv` and modern `pip` do not require `distutils`.

---

### M3 — LiteLLM exposed on all interfaces with a well-known default key

**File:** [build/ansible/roles/llm/templates/litellm.service.j2](build/ansible/roles/llm/templates/litellm.service.j2#L13) / [litellm_config.yaml.j2](build/ansible/roles/llm/templates/litellm_config.yaml.j2#L34)

```ini
ExecStart=... --host 0.0.0.0           # all interfaces
```
```yaml
master_key: "kosmos-local"             # public default
```

LiteLLM is externally reachable (UFW allows port 4000) with a publicly known API key. Anyone who reaches the VM can call arbitrary models including cloud models if API keys are configured in `/etc/kosmos/env`.

**Fix for a dev image:** At minimum, document clearly that `master_key` must be changed before adding real API keys. For a production hardening path, consider `--host 127.0.0.1` and using an SSH tunnel or reverse proxy with auth.

---

### M4 — `.bash_profile` not updated for login shells if file pre-exists

**File:** [build/ansible/roles/agent/tasks/main.yml](build/ansible/roles/agent/tasks/main.yml#L156-L165)

```yaml
- name: Copy .bashrc to .bash_profile for login shells
  copy:
    src: "{{ kosmos_home }}/.bashrc"
    dest: "{{ kosmos_home }}/.bash_profile"
    force: false    # ← won't overwrite if exists
```

Ubuntu cloud-init may create a skeleton `.bash_profile` during user provisioning. With `force: false`, the kosmos `PATH`, `VIRTUAL_ENV`, and `LITELLM_API_BASE` exports are never written to `.bash_profile`. SSH login sessions (non-interactive) use `.bash_profile`, not `.bashrc`, so the venv and env vars are absent for SSH-based agent workflows.

**Fix:** Either use `force: true` (replace with a blockinfile approach instead, similar to `.bashrc`) or remove the task and rely solely on `/etc/profile.d/` entries.

---

### M5 — Grafana Prometheus metric names are speculative

**File:** [build/ansible/roles/observe/files/kosmos-dashboard.json](build/ansible/roles/observe/files/kosmos-dashboard.json)

Two dashboard panels reference metric names that may not match what the services actually export:

| Panel | Metric in dashboard | Likely actual metric |
|---|---|---|
| Ollama — Active Requests | `ollama_requests_total` | Unknown / not exposed |
| LiteLLM — Request Rate | `litellm_request_total` | `litellm_requests_total` (plural) |

Both panels will show "No data" on a fresh install.

---

### M6 — Promtail systemd service runs as root

**File:** [build/ansible/roles/observe/tasks/main.yml](build/ansible/roles/observe/tasks/main.yml#L238-L255)

The Promtail service unit has no `User=` directive, so systemd runs it as `root`. Loki and node_exporter both use dedicated system users (`loki`, `prometheus`). Promtail should run as `loki` (or a `promtail` system user) for least privilege.

**Fix:** Add `User=loki` to the Promtail service unit.

---

### M7 — Deprecated `apt_key` module and potentially stale NodeSource repo URL

**File:** [build/ansible/roles/agent/tasks/main.yml](build/ansible/roles/agent/tasks/main.yml#L75-L88)

```yaml
- name: Add NodeSource GPG key
  apt_key:                          # deprecated in Ansible since 2.13
    url: https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key
```

`apt_key` stores keys in the deprecated `/etc/apt/trusted.gpg` keyring, triggering apt warnings. The `nodesource-repo.gpg.key` filename is the new key, but paired with the old per-version `node_22.x` repo URL — this mixed configuration may fail as NodeSource migrates repos.

**Fix:** Use `get_url` + `apt_repository` with `signed-by` pointing to a keyring file in `/etc/apt/keyrings/`.

---

## Low

### L1 — E2E test depends on live web search — fails intermittently

**File:** [tests/agent_e2e.py](tests/agent_e2e.py#L68)

```python
params = urllib.parse.urlencode({"engines": "google,duckduckgo", ...})
```

Google and DuckDuckGo both apply rate-limits and CAPTCHAs to SearXNG instances. On a freshly booted VM with a new IP, both engines may return 0 results, causing the e2e test to call `fail()` and exit 1. This is not a KosmOS defect but will confuse users running the test for the first time.

**Fix:** Add a fallback search engine (e.g., `bing`, `brave`) or use SearXNG's Wikipedia engine as a reliable baseline for CI.

---

### L2 — ChromaDB embedding model downloads at query time, not build time

**File:** [tests/agent_e2e.py](tests/agent_e2e.py#L127-L135)

ChromaDB's default embedding function (`sentence-transformers/all-MiniLM-L6-v2`) downloads ~90 MB on first use. This happens at the first `query_texts` call inside the VM. The model is not pulled during the Packer build, adding ~30s latency (plus potential network dependency) to the first agent run.

**Fix:** Add a post-provision step to pre-warm the ChromaDB embedding model:
```bash
python3 -c "from chromadb.utils.embedding_functions import DefaultEmbeddingFunction; DefaultEmbeddingFunction()"
```

---

### L3 — Packer GRUB boot command is brittle

**File:** [build/kosmos.pkr.hcl](build/kosmos.pkr.hcl#L68-L74)

```hcl
boot_wait = "5s"
boot_command = ["<spacebar><wait>", "e<wait>", "<down><down><down><end>", ...]
```

The three `<down>` key presses assume a fixed GRUB menu layout. Ubuntu point releases (e.g., 24.04.3) may add or remove menu entries, shifting the `<down>` count needed to reach the correct kernel line. A 5s `boot_wait` is also marginal for nested virtualisation.

**Fix:** Increase `boot_wait` to `"10s"` and consider using `<wait5>` between key presses. Pin a specific ISO URL/checksum or test the boot sequence against each new ISO.

---

### L4 — Weak Grafana admin password with no post-boot reminder

**File:** [build/ansible/vars/defaults.yml](build/ansible/vars/defaults.yml#L47)

```yaml
grafana_admin_password: kosmos   # change post-boot for production use
```

The README mentions this, but the MOTD does not. Any user who opens Grafana on port 3000 can log in as `admin/kosmos`.

---

### L5 — LiteLLM `claude` alias references outdated model

**File:** [build/ansible/roles/agent/tasks/main.yml](build/ansible/roles/agent/tasks/main.yml#L149)

```bash
alias claude='claude --model claude-3-5-sonnet'
```

`claude-3-5-sonnet-20241022` is a valid model but no longer the latest. The current recommended model for new deployments is `claude-sonnet-4-6` (`claude-sonnet-4-6`). This alias will keep working via LiteLLM's routing, but the model used is older and more expensive per token than `claude-haiku-4-5-20251001` for light tasks.

---

### L6 — `calculator()` uses `eval()` on user input

**File:** [build/ansible/roles/tools/files/mcp_server.py](build/ansible/roles/tools/files/mcp_server.py#L157-L169)

```python
_SAFE_CALC_RE = re.compile(r"^[\d\s\+\-\*/\(\)\.\^%]+$")
...
return float(eval(expression, {"__builtins__": {}}))
```

The regex allows only digits and arithmetic operators, which is a reasonable guard. However, `eval` with `{"__builtins__": {}}` is not fully sandboxed in all Python versions — certain class traversal attacks via `().__class__.__mro__[1].__subclasses__()` remain possible if the regex is ever loosened. Given the MCP server is exposed on port 8080, this is a latent risk.

**Fix:** Replace `eval` with a proper expression parser such as `ast.literal_eval` extended for arithmetic, or the `simpleeval` library.

---

### L7 — Static salt in cloud-init password hash

**File:** [build/http/user-data](build/http/user-data#L24)

```yaml
password: "$6$rounds=4096$saltsaltsalt$..."
```

The salt `saltsaltsalt` is static and predictable. For a known password (`kosmos`), this means the hash is identical across every KosmOS image. If an attacker obtains the hash (e.g., via a QCOW2 image leak), cracking is trivial with a targeted wordlist. Acceptable for a dev image but worth fixing for any image intended for wider distribution.

---

## Build Validation (Static)

| Check | Result |
|---|---|
| `bash -n tests/smoke.sh` | PASS |
| `bash -n motd/kosmos-motd.sh` | PASS |
| `ast.parse(tests/agent_e2e.py)` | PASS |
| `ast.parse(mcp_server.py)` | PASS |
| YAML: `litellm_config.yaml.j2` | PASS |
| YAML: `prometheus.yml.j2` | PASS |
| YAML: `loki-config.yaml.j2` | PASS |
| YAML: `promtail-config.yaml.j2` | PASS |
| YAML: `grafana-datasources.yaml.j2` | PASS |
| YAML: `searxng-compose.yml.j2` | PASS |
| JSON: `kosmos-dashboard.json` | PASS |
| Packer HCL: `kosmos.pkr.hcl` | Not validated (packer not installed) |
| Ansible lint: all roles | Not validated (ansible-lint not installed) |
| Live build / boot | Not tested (no KVM environment) |
| Smoke test (`tests/smoke.sh`) | Not tested (requires running VM) |
| E2E test (`tests/agent_e2e.py`) | Not tested (requires running VM) |

---

## Priority Fix Order

1. **C2** — Fix Rust `creates` path (1-line change, prevents re-downloading rustup every build)
2. **M2** — Remove `python3.12-distutils` (prevents build failure on Ubuntu 24.04)
3. **H4** — Add `/opt/kosmos/motd` to directory creation loop (prevents MOTD copy failure)
4. **C1** — Restructure venv creation order (move to `base` role or pre-step)
5. **H2** — Add Loki compactor section (prevents unbounded disk growth)
6. **H1** — Fix Grafana Logs panel datasource (one-line JSON change)
7. **H3** — Remove or fix Ollama Prometheus scrape job
8. **M1** — Fix `uv` install `creates` path and remove dead symlink task
9. **M4** — Fix `.bash_profile` propagation for login shells
10. **M6** — Add `User=loki` to Promtail service
