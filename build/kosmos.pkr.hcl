packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}

# ── Variables ──────────────────────────────────────────────────────────────────

variable "ubuntu_iso_url" {
  default = "https://releases.ubuntu.com/24.04.2/ubuntu-24.04.2-live-server-amd64.iso"
}

variable "ubuntu_iso_checksum" {
  default = "sha256:d6dab0c3a657988501b4bd76f1297c053df710e06e0c3aece60dead24f270b4d"
}

variable "vm_name" {
  default = "kosmos"
}

variable "disk_size" {
  default = "51200"  # 50 GB
}

variable "memory" {
  default = "8192"  # 8 GB — enough for a 7B model + stack
}

variable "cpus" {
  default = "4"
}

variable "ssh_username" {
  default = "kosmos"
}

variable "ssh_password" {
  default = "kosmos"
}


# ── Source: QEMU ───────────────────────────────────────────────────────────────

source "qemu" "kosmos" {
  iso_url          = var.ubuntu_iso_url
  iso_checksum     = var.ubuntu_iso_checksum
  output_directory = "${path.root}/../dist"
  vm_name          = "${var.vm_name}.qcow2"
  disk_size        = var.disk_size
  memory           = var.memory
  cpus             = var.cpus
  format           = "qcow2"
  accelerator      = "kvm"
  cpu_model        = "host"   # expose host CPU features (x86-64-v2+) so NumPy 2.x runs
  headless         = true

  ssh_username         = var.ssh_username
  ssh_private_key_file = "${path.root}/http/packer_key"
  ssh_timeout          = "60m"

  # Ubuntu 24.04 live-server autoinstall via cloud-init over Packer HTTP.
  #
  # We use the GRUB command-line ('c') approach instead of editing the menu
  # entry ('e' + arrow navigation) because the entry structure varies across
  # 24.04.x point releases, making arrow-count navigation fragile.
  #
  # 'c' opens the GRUB command prompt unconditionally; we then type the exact
  # kernel + initrd lines and boot.  The ';' in ds=nocloud-net;s=... is a GRUB
  # command separator, so we wrap the value in single quotes.
  boot_wait = "12s"
  boot_command = [
    "c<wait3>",
    "linux /casper/vmlinuz autoinstall 'ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/'<enter><wait5>",
    "initrd /casper/initrd<enter><wait3>",
    "boot<enter>"
  ]

  http_directory   = "${path.root}/http"
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"

  qemuargs = [
    ["-serial", "stdio"]
  ]
}

# ── Build ──────────────────────────────────────────────────────────────────────

build {
  name    = "kosmos"
  sources = ["source.qemu.kosmos"]

  # Wait for cloud-init to finish before Ansible runs
  provisioner "shell" {
    inline = [
      "cloud-init status --wait",
      "echo 'cloud-init done'"
    ]
  }

  provisioner "ansible" {
    playbook_file   = "${path.root}/ansible/site.yml"
    user            = var.ssh_username
    # use_proxy=true routes Ansible through Packer's already-established
    # communicator connection (password auth) rather than opening a new
    # direct SSH connection that requires key injection. On Ubuntu 24.04
    # server, sshd disables PasswordAuthentication after cloud-init finalises,
    # so key injection via a fresh password-auth session fails.
    use_proxy       = true
    extra_arguments = [
      "--become",
      "-e", "ansible_become_password=${var.ssh_password}",  # sudo password for the kosmos user
      "-e", "@${path.root}/ansible/vars/defaults.yml"
    ]
  }

  # Compact the image after provisioning
  post-processor "shell-local" {
    inline = [
      "qemu-img convert -O qcow2 -c dist/${var.vm_name}.qcow2 dist/${var.vm_name}.compact.qcow2",
      "mv dist/${var.vm_name}.compact.qcow2 dist/${var.vm_name}.qcow2",
      "echo '✓ QCOW2 ready: dist/${var.vm_name}.qcow2'"
    ]
  }
}
