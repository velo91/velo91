#!/usr/bin/env bash
set -uo pipefail

# harden-server-dokploy.sh
# Ubuntu 24.04 LTS -> hardening -> reboot #1 -> hardening/CVE -> reboot #2
# -> verification -> Dokploy installation
#
# IMPORTANT:
# - Run from the non-root admin user that will remain as the server admin.
# - Dokploy currently documents Ubuntu 24.04 LTS as a tested distro.
# - Do NOT blindly apply historical kernel CVE module blocks.
# - Dokploy needs ports 80, 443 and 3000 free at installation time.
# - The Dokploy installer must run as root and will install Docker if needed.

SCRIPT_VERSION="2026-08-29-dokploy"
LOG_FILE="/tmp/harden-server-$(date +%Y%m%d-%H%M%S).log"
DRY_RUN=false
SKIP_REBOOT=false
INTERACTIVE=false
SKIP_DOKPLOY=false
BACKUP_DIR="/root/harden-backups-$(date +%Y%m%d-%H%M%S)"
STATE_DIR="$HOME/.harden-server"
REBOOT1_MARKER="$STATE_DIR/reboot1-done"
REBOOT2_MARKER="$STATE_DIR/reboot2-done"
HARDENING_MARKER="$STATE_DIR/hardening-done"
DOKPLOY_MARKER="$STATE_DIR/dokploy-installed"

mkdir -p "$STATE_DIR" 2>/dev/null || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --skip-reboot) SKIP_REBOOT=true; shift ;;
    --interactive) INTERACTIVE=true; shift ;;
    --skip-dokploy) SKIP_DOKPLOY=true; shift ;;
    *) echo "Usage: $0 [--dry-run] [--skip-reboot] [--interactive] [--skip-dokploy]"; exit 1 ;;
  esac
done

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()   { log "  ✔ $*"; }
info() { log "  → $*"; }
warn() { log "  ⚠️  $*" >&2; }
err()  { log "  ❌ $*" >&2; }

confirm() {
  if ! $INTERACTIVE; then
    return 0
  fi
  local prompt="$1"
  read -r -p "$(echo -e "\033[1;33m?? ${prompt} [y/N]: \033[0m")" ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

run() {
  if $DRY_RUN; then
    log "  [DRY-RUN] $*"
  else
    log "  $*"
    eval "$@"
  fi
}

backup() {
  local file="$1"
  if [[ -f "$file" ]]; then
    mkdir -p "$BACKUP_DIR"
    local dir="$BACKUP_DIR$(dirname "$file")"
    mkdir -p "$dir"
    cp -a "$file" "$dir/$(basename "$file").bak-$(date +%Y%m%d-%H%M%S)"
    ok "Backup $file → $BACKUP_DIR"
  fi
}

if ! sudo -n true 2>/dev/null; then
  echo "⚠️  Perlu sudo. Jalankan 'sudo -v' terlebih dahulu."
  exit 1
fi

[[ -f /etc/os-release ]] || { err "Tidak bisa menentukan OS."; exit 1; }
. /etc/os-release
OS_ID="${ID:-unknown}"
OS_VER="${VERSION_ID:-unknown}"

cat <<EOF
╔════════════════════════════════════════════════════════════╗
║       Server Hardening + Dokploy v${SCRIPT_VERSION}        ║
╚════════════════════════════════════════════════════════════╝
EOF

log "OS: $OS_ID $OS_VER"
log "Mode: $($DRY_RUN && echo "DRY-RUN" || echo "LIVE")"
log "Interactive: $INTERACTIVE"
log "Log: $LOG_FILE"
log "Backup: $BACKUP_DIR"

# ---------------------------------------------------------------------------
# PHASE 1 — APT UPDATE/UPGRADE -> REBOOT #1
# ---------------------------------------------------------------------------
if [[ ! -f "$REBOOT1_MARKER" ]]; then
  log "━━━ PHASE 1 — APT Update & Upgrade ━━━"

  run sudo apt update -qq
  run sudo apt upgrade -y -qq
  run sudo apt autoremove -y -qq

  info "Kernel aktif sebelum reboot #1: $(uname -r)"
  info "Installed kernels:"
  dpkg -l 'linux-image*' 2>/dev/null | grep '^ii' || true

  # Marker MUST be written before reboot. Anything after reboot is not reliable.
  if ! $DRY_RUN; then
    touch "$REBOOT1_MARKER"
  fi

  if $SKIP_REBOOT; then
    warn "SKIP_REBOOT=true — reboot #1 tidak dilakukan."
    warn "Setelah apt upgrade selesai, reboot manual lalu jalankan script lagi."
    exit 0
  fi

  if $DRY_RUN; then
    warn "DRY-RUN — reboot #1 tidak dilakukan."
    exit 0
  fi

  warn "REBOOT #1 akan dilakukan dalam 15 detik..."
  echo "Setelah server hidup kembali, jalankan script yang sama."
  sleep 15
  sudo reboot
  exit 0
fi

# ---------------------------------------------------------------------------
# PHASE 2 — HARDENING
# ---------------------------------------------------------------------------
if [[ ! -f "$HARDENING_MARKER" ]]; then
  log "━━━ PHASE 2 — Hardening ━━━"

  # Safety: only delete default ubuntu account if it is NOT the current user.
  if id "ubuntu" &>/dev/null; then
    CURRENT_USER="$(id -un)"
    if [[ "$CURRENT_USER" == "ubuntu" ]]; then
      warn "Anda sedang login sebagai 'ubuntu'. User ubuntu TIDAK akan dihapus."
    elif confirm "Hapus user 'ubuntu' beserta home directory?"; then
      run sudo deluser --remove-home ubuntu
      ok "User ubuntu dihapus"
    else
      warn "User ubuntu dipertahankan."
    fi
  else
    info "User ubuntu tidak ada."
  fi

  # SSH hardening
  log "━━━ SSH hardening ━━━"
  SSHD_CONF="/etc/ssh/sshd_config"
  backup "$SSHD_CONF"

  HAS_SSH_KEY=0
  for home in /root /home/*; do
    if [[ -f "$home/.ssh/authorized_keys" && -s "$home/.ssh/authorized_keys" ]]; then
      HAS_SSH_KEY=1
      break
    fi
  done

  if [[ "$HAS_SSH_KEY" -eq 0 ]]; then
    warn "Tidak ada authorized_keys ditemukan."
    warn "PasswordAuthentication dan PermitRootLogin TIDAK akan diubah."
    warn "Pasang SSH key terlebih dahulu lalu jalankan ulang script."
    if ! $INTERACTIVE; then
      exit 1
    fi
  else
    # Use a managed block and explicitly replace existing directives.
    run "sudo sed -i -E '/^[#[:space:]]*(LoginGraceTime|PermitRootLogin|MaxAuthTries|PasswordAuthentication|ClientAliveInterval|ClientAliveCountMax)[[:space:]]+/d' '$SSHD_CONF'"
    run "cat <<'EOF' | sudo tee -a '$SSHD_CONF' >/dev/null
# === Hardening oleh harden-server.sh ===
LoginGraceTime 30
PermitRootLogin no
MaxAuthTries 3
PasswordAuthentication no
ClientAliveInterval 120
ClientAliveCountMax 360
EOF"
    run sudo sshd -t
    run sudo systemctl restart ssh
    ok "SSH hardening diterapkan"
  fi

  # DNS
  log "━━━ DNS Cloudflare + Google DNS-over-TLS ━━━"
  RESOLVED_CONF="/etc/systemd/resolved.conf"
  backup "$RESOLVED_CONF"

  run "sudo sed -i -E '/^[[:space:]]*(DNS|FallbackDNS|DNSOverTLS|DNSStubListener|Cache)=/d' '$RESOLVED_CONF'"
  run "cat <<'EOF' | sudo tee -a '$RESOLVED_CONF' >/dev/null
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com 2606:4700:4700::1111#cloudflare-dns.com 2606:4700:4700::1001#cloudflare-dns.com
FallbackDNS=8.8.8.8#dns.google 8.8.4.4#dns.google 2001:4860:4860::8888#dns.google 2001:4860:4860::8844#dns.google
DNSOverTLS=yes
DNSStubListener=yes
Cache=yes
EOF"
  run sudo systemctl restart systemd-resolved
  run sudo resolvectl flush-caches

  # File descriptor limits
  log "━━━ File descriptor limits ━━━"
  LIMITS_CONF="/etc/security/limits.d/99-harden-server.conf"
  backup "$LIMITS_CONF"
  run "cat <<'EOF' | sudo tee '$LIMITS_CONF' >/dev/null
*         hard    nofile      500000
*         soft    nofile      500000
root      hard    nofile      500000
root      soft    nofile      500000
EOF"

  # Sysctl/network
  log "━━━ Network hardening ━━━"
  NET_CONF="/etc/sysctl.d/99-network-hardening.conf"
  backup "$NET_CONF"
  run "cat <<'EOF' | sudo tee '$NET_CONF' >/dev/null
# === harden-server.sh ===
fs.file-max = 500000
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_tw_reuse = 1
vm.swappiness = 10
EOF"
  run sudo sysctl --system

  # Shared memory
  log "━━━ /dev/shm hardening ━━━"
  FSTAB="/etc/fstab"
  backup "$FSTAB"
  run "sudo sed -i '\|^[[:space:]]*tmpfs[[:space:]]\+/dev/shm[[:space:]]|d' '$FSTAB'"
  run "echo 'tmpfs   /dev/shm    tmpfs   defaults,nosuid,nodev,noexec    0 0' | sudo tee -a '$FSTAB' >/dev/null"
  run sudo mount -o remount /dev/shm

  # Swap
  log "━━━ Swap ━━━"
  if ! command -v dphys-swapfile &>/dev/null; then
    run sudo apt install -y dphys-swapfile
  fi
  run "sudo dphys-swapfile swapoff 2>/dev/null || true"
  run "sudo dphys-swapfile uninstall 2>/dev/null || true"
  SWAPFILE_CONF="/etc/dphys-swapfile"
  backup "$SWAPFILE_CONF"
  run "cat <<'EOF' | sudo tee '$SWAPFILE_CONF' >/dev/null
CONF_SWAPFILE=/var/swap
CONF_SWAPSIZE=4096
CONF_SWAPFACTOR=2
CONF_MAXSWAP=4096
EOF"
  run sudo dphys-swapfile setup
  run sudo dphys-swapfile swapon

  # Unattended upgrades
  log "━━━ Unattended security upgrades ━━━"
  run sudo apt install -y -qq unattended-upgrades apt-listchanges
  run "cat <<'EOF' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null
APT::Periodic::Update-Package-Lists \"1\";
APT::Periodic::Unattended-Upgrade \"1\";
EOF"
  run "cat <<'EOF' | sudo tee /etc/apt/apt.conf.d/52server-security-updates >/dev/null
Unattended-Upgrade::Origins-Pattern {
        \"origin=Ubuntu,archive=\${distro_codename}-security\";
};
EOF"
  run sudo systemctl enable --now apt-daily.timer apt-daily-upgrade.timer
  run sudo unattended-upgrade --dry-run --debug || true

  # -------------------------------------------------------------------------
  # CVE: assessment only.
  #
  # Historical module-specific blocks are NOT automatically applied.
  # A patched kernel is preferred. Blocking esp4/rxrpc/rds/etc blindly can
  # break legitimate networking/features and is unnecessary if the installed
  # Ubuntu kernel already contains the fix.
  # -------------------------------------------------------------------------
  log "━━━ Kernel/CVE assessment ━━━"
  info "Running kernel: $(uname -r)"
  info "Ubuntu: $(lsb_release -ds 2>/dev/null || echo "$PRETTY_NAME")"
  info "Installed kernels:"
  dpkg -l 'linux-image*' 2>/dev/null | grep '^ii' | awk '{print "  " $2}' || true
  info "Relevant loaded modules:"
  lsmod | grep -E 'algif_aead|esp4|esp6|rxrpc|rds|act_pedit|kvm_amd|kvm_intel' || \
    info "  None of the historical modules are loaded."

  if confirm "Terapkan mitigasi CVE module-specific dari catatan lama?"; then
    warn "Mitigasi module-specific tidak dijalankan otomatis pada build ini."
    warn "Gunakan advisory Ubuntu untuk menentukan apakah sebuah module memang perlu diblokir."
  else
    info "CVE module-specific dilewati."
  fi

  if ! $DRY_RUN; then
    touch "$HARDENING_MARKER"
  fi

  log "━━━ Reboot #2 ━━━"
  if $SKIP_REBOOT; then
    warn "SKIP_REBOOT=true — reboot #2 tidak dilakukan."
    warn "Reboot manual, lalu jalankan script lagi."
    exit 0
  fi

  if $DRY_RUN; then
    warn "DRY-RUN — reboot #2 tidak dilakukan."
    exit 0
  fi

  # Marker MUST be written before reboot.
  touch "$REBOOT2_MARKER"

  warn "REBOOT #2 akan dilakukan dalam 15 detik..."
  echo "Setelah server hidup kembali, jalankan script yang sama."
  sleep 15
  sudo reboot
  exit 0
fi

# ---------------------------------------------------------------------------
# PHASE 3 — FINAL VERIFICATION + DOKPLOY
# ---------------------------------------------------------------------------
log "━━━ PHASE 3 — Final verification ━━━"

echo
echo "=== OS ==="
cat /etc/os-release | grep -E '^(PRETTY_NAME|VERSION_ID)='

echo
echo "=== Kernel ==="
uname -a

echo
echo "=== SSH ==="
sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|maxauthtries|logingracetime|clientaliveinterval|clientalivecountmax)'

echo
echo "=== DNS ==="
resolvectl status | sed -n '1,80p'

echo
echo "=== /dev/shm ==="
findmnt /dev/shm || true

echo
echo "=== Swap ==="
swapon --show

echo
echo "=== Sysctl ==="
sysctl fs.file-max vm.swappiness net.ipv4.tcp_syncookies net.core.somaxconn net.ipv4.tcp_max_syn_backlog

# ---------------------------------------------------------------------------
# Dokploy
# ---------------------------------------------------------------------------
if $SKIP_DOKPLOY; then
  info "Dokploy installation dilewati (--skip-dokploy)."
  exit 0
fi

if [[ -f "$DOKPLOY_MARKER" ]]; then
  ok "Dokploy sudah ditandai terinstall."
  exit 0
fi

log "━━━ Dokploy preflight ━━━"

if [[ "$OS_ID" != "ubuntu" || "$OS_VER" != "24.04" ]]; then
  err "Dokploy installation dihentikan: script ini menargetkan Ubuntu 24.04 LTS."
  err "Detected: $OS_ID $OS_VER"
  exit 1
fi

# Dokploy requires ports 80, 443, 3000 to be free.
PORT_CONFLICT=0
for port in 80 443 3000; do
  if sudo ss -lntp "( sport = :$port )" 2>/dev/null | grep -q ":$port"; then
    warn "Port $port sedang digunakan:"
    sudo ss -lntp "( sport = :$port )" 2>/dev/null || true
    PORT_CONFLICT=1
  fi
done

if [[ "$PORT_CONFLICT" -ne 0 ]]; then
  err "Dokploy tidak diinstall karena port 80/443/3000 harus bebas."
  exit 1
fi

# Check whether this is already a container.
if [[ -f /.dockerenv ]]; then
  err "Dokploy harus dipasang pada Linux host, bukan di dalam container."
  exit 1
fi

# Ensure curl exists.
if ! command -v curl &>/dev/null; then
  run sudo apt install -y curl
fi

# Docker is optional: Dokploy installer can install it.
if command -v docker &>/dev/null; then
  info "Docker sudah terpasang: $(docker --version)"
else
  info "Docker belum terpasang; installer Dokploy akan memasangnya."
fi

cat <<'EOF'

============================================================
DOKPLOY INSTALLATION
============================================================

Dokploy membutuhkan:
  - Ubuntu 24.04 LTS
  - minimal 2 GB RAM
  - minimal 30 GB disk
  - port 80, 443, 3000 bebas

Installer resmi:
  https://dokploy.com/install.sh

============================================================
EOF

if $INTERACTIVE; then
  if ! confirm "Install Dokploy latest stable sekarang?"; then
    warn "Instalasi Dokploy dibatalkan."
    exit 0
  fi
fi

if $DRY_RUN; then
  log "[DRY-RUN] curl -sSL https://dokploy.com/install.sh | sudo sh"
  exit 0
fi

log "━━━ Installing Dokploy latest stable ━━━"

# Run the official installer as root, as required by Dokploy.
curl -sSL https://dokploy.com/install.sh | sudo sh

# Set timezone Dokploy ke WIB
if sudo docker service ls --format '{{.Name}}' | grep -qx 'dokploy'; then
    sudo docker service update --env-add TZ=Asia/Jakarta dokploy
    ok "Timezone Dokploy diubah ke Asia/Jakarta"
else
    warn "Service dokploy belum ditemukan, timezone tidak diubah."
fi

if command -v docker &>/dev/null && sudo docker service ls 2>/dev/null | grep -q dokploy; then
  touch "$DOKPLOY_MARKER"
  ok "Dokploy terdeteksi berjalan."
else
  warn "Installer selesai, tetapi service Dokploy belum terdeteksi."
  warn "Periksa dengan: sudo docker service ls"
fi

cat <<'EOF'

============================================================
HARDENING + DOKPLOY SELESAI
============================================================

Akses awal Dokploy:
  http://IP-SERVER:3000

Timezone Dokploy:
  Asia/Jakarta (WIB)

------------------------------------------------------------
CLOUDFLARE
------------------------------------------------------------

Jika menggunakan Cloudflare:

  Pastikan SSL/TLS Encryption Mode:
      Full (Strict)

  Cloudflare Dashboard:
    SSL/TLS → Overview
    → Configure SSL/TLS Encryption
    → Full (Strict)

  Dokploy menyediakan dua pilihan certificate untuk
  Full (Strict):

  1. Let's Encrypt
  2. Cloudflare Origin CA

  Jika menggunakan Cloudflare Origin CA:

  1. Cloudflare Dashboard
       → SSL/TLS
       → Origin Server
       → Create Certificate

  2. Pilih:
       Generate private key and CSR with Cloudflare

  3. Masukkan hostname yang akan dicakup certificate, misalnya:
     *.contoh.com
     contoh.com

  4. Setelah certificate dibuat, salin dalam format PEM.

  5. Masuk ke Dokploy:
     Certificates → Add Certificate

     Kemudian isi:
     Certificate Name → *.contoh.com Cloudflare's Origin CA
     Certificate Data → paste Origin Certificate
     Private Key → paste Private Key

     Lalu simpan/create certificate.

  6. Saat membuat Domain di Dokploy:

     HTTPS       : ON
     Certificate : pilih None
                   (bukan Let's Encrypt karena sudah Origin CA)

  7. Pastikan hostname Domain Dokploy sama dengan
     hostname yang tercakup dalam certificate.

Pastikan DNS Cloudflare sudah menunjuk ke IP server
sebelum membuat Domain di Dokploy.

------------------------------------------------------------
SETELAH HTTPS BERFUNGSI
------------------------------------------------------------

Setelah domain HTTPS untuk panel Dokploy sudah berhasil
dan dapat diakses, published port 3000 dapat dinonaktifkan:

  sudo docker service update \
    --publish-rm "published=3000,target=3000,mode=host" \
    dokploy

Dengan demikian panel Dokploy tidak lagi perlu diakses
langsung melalui:

  http://IP-SERVER:3000

------------------------------------------------------------
VERIFIKASI
------------------------------------------------------------

  sudo docker service ls
  sudo docker ps
  sudo ss -lntp
  sudo docker info

============================================================
EOF
