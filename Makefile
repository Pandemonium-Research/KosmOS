.PHONY: build run stop test clean keygen help

DIST           := dist/kosmos.qcow2
PACKER_KEY     := build/http/packer_key
PACKER_KEY_PUB := build/http/packer_key.pub

# SSH helpers — key auth, no host-key checking (dev VM only)
# Note: ssh uses -p (lowercase) for port; scp uses -P (uppercase)
SSH_OPTS := -i $(PACKER_KEY) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
SSH  := ssh  -p 2222 $(SSH_OPTS) kosmos@127.0.0.1
SCP  := scp  -P 2222 $(SSH_OPTS)

help:           ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*##"}{printf "  %-10s %s\n",$$1,$$2}'

keygen:         ## Generate the Packer SSH keypair (run once after cloning)
	@if [ -f $(PACKER_KEY) ]; then \
	  echo "Key already exists: $(PACKER_KEY)"; \
	  echo "Delete it first if you want to regenerate."; \
	  exit 0; \
	fi
	ssh-keygen -t ed25519 -f $(PACKER_KEY) -N "" -C "packer-build"
	sed -i "s|\"ssh-ed25519 [^\"]*\"|\"$$(cat $(PACKER_KEY_PUB))\"|" build/http/user-data
	@echo ""
	@echo "Done. Commit $(PACKER_KEY_PUB) and build/http/user-data if the key changed."

build: _check-key  ## Build the KosmOS QCOW2 image (~60-90 min)
	@which packer >/dev/null 2>&1 || bash scripts/install-packer.sh
	@rm -rf dist/
	LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 packer build build/kosmos.pkr.hcl

run: $(DIST)    ## Boot the image in the background (log → /tmp/kosmos-qemu.log)
	@echo "Booting KosmOS VM..."
	@nohup bash scripts/run.sh >/tmp/kosmos-qemu.log 2>&1 & echo $$! >/tmp/kosmos-qemu.pid
	@echo "QEMU PID $$(cat /tmp/kosmos-qemu.pid) — tail -f /tmp/kosmos-qemu.log"

stop:           ## Shut down the running VM
	@if [ -f /tmp/kosmos-qemu.pid ]; then \
	  kill "$$(cat /tmp/kosmos-qemu.pid)" 2>/dev/null && rm /tmp/kosmos-qemu.pid && echo "KosmOS stopped"; \
	else \
	  echo "No running KosmOS VM found"; \
	fi

test:           ## Run smoke + e2e tests against the running VM (start with 'make run' first)
	@[ -f $(PACKER_KEY) ] || (echo "ERROR: Packer key missing. Run 'make keygen' first."; exit 1)
	@echo "Waiting for SSH (services may take ~2 min after boot)..."
	@until $(SSH) true 2>/dev/null; do printf '.'; sleep 5; done; echo " ready"
	$(SCP) -r tests/ kosmos@127.0.0.1:~/
	@echo ""
	@echo "=== smoke test ==="
	$(SSH) 'bash ~/tests/smoke.sh'
	@echo ""
	@echo "=== agent e2e ==="
	$(SSH) '/opt/kosmos/venv/bin/python ~/tests/agent_e2e.py'

clean:          ## Remove the built image
	rm -rf dist/

# Internal: verify the packer private key exists before building
_check-key:
	@[ -f $(PACKER_KEY) ] || (echo "ERROR: Packer key missing. Run 'make keygen' first."; exit 1)
