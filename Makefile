.PHONY: build run stop test clean help

DIST := dist/kosmos.qcow2

# SSH/SCP helpers — password auth, no host-key checking (dev VM only)
SSH_OPTS := -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -o PasswordAuthentication=yes
SSH  := sshpass -p kosmos ssh  $(SSH_OPTS) kosmos@127.0.0.1
SCP  := sshpass -p kosmos scp  $(SSH_OPTS)

help:           ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*##"}{printf "  %-8s %s\n",$$1,$$2}'

build:          ## Build the KosmOS QCOW2 image (~60-90 min)
	@which packer >/dev/null 2>&1 || bash scripts/install-packer.sh
	@# Packer requires dist/ to not exist; run 'make clean' first if rebuilding.
	LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 packer build build/kosmos.pkr.hcl

run: $(DIST)   ## Boot the image in the background (log → /tmp/kosmos-qemu.log)
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
	@which sshpass >/dev/null 2>&1 || (echo "Installing sshpass..." && sudo apt-get install -y sshpass)
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
