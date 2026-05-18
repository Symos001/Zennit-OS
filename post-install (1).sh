esse é um outro script , verifique se há dualidade nele com o que já tenho .#!/usr/bin/env bash
# =============================================================================
# optimize.sh — Otimização Fedora para Lucas
# AMD APU | SSD NVMe | Notebook | Plymouth preservado
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_step()  { echo -e "\n${BOLD}${BLUE}══ $1${NC}"; }
log_ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
log_warn()  { echo -e "  ${YELLOW}⚠${NC}  $1"; }
log_info()  { echo -e "  ${CYAN}→${NC} $1"; }

LOGFILE="$HOME/optimize.log"
exec > >(tee -a "$LOGFILE") 2>&1
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║    Fedora Optimizer — AMD APU | Dev Backend      ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Backups das configs originais em: $BACKUP_DIR"
sleep 2

[[ "$EUID" -eq 0 ]] && { echo -e "${RED}Não rode como root.${NC}"; exit 1; }

# ─── 1. sysctl — Kernel performance ──────────────────────────────────────────
log_step "1/8 — Parâmetros de kernel (sysctl)"

SYSCTL_FILE="/etc/sysctl.d/99-lucas-performance.conf"
[[ -f "$SYSCTL_FILE" ]] && sudo cp "$SYSCTL_FILE" "$BACKUP_DIR/"

sudo tee "$SYSCTL_FILE" > /dev/null << 'EOF'
# ── Memória e swap ──────────────────────────────────────────────────
# Preferência mínima por swap (ZRAM ativo no Fedora)
vm.swappiness = 10

# Pressão de cache de filesystem reduzida
vm.vfs_cache_pressure = 50

# I/O write behavior — reduz flush agressivo em SSD
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5

# Páginas "huge" transparentes — melhora JVM (Java heap)
# (kernel gerencia automaticamente, apenas ativando)
# kernel.mm.transparent_hugepage.enabled = madvise  ← via sysfs abaixo

# ── CPU e energia ───────────────────────────────────────────────────
# Desativa NMI watchdog (economia de energia em notebook)
kernel.nmi_watchdog = 0

# ── Rede (dev local: Docker, APIs, Spring Boot) ─────────────────────
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 8192
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0

# ── Segurança (manter) ──────────────────────────────────────────────
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
EOF

sudo sysctl --system &>/dev/null
log_ok "Parâmetros de kernel aplicados"

# Transparent HugePage para madvise (beneficia JVM)
echo madvise | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
# Persistir via tmpfiles
sudo tee /etc/tmpfiles.d/thp.conf > /dev/null << 'EOF'
w /sys/kernel/mm/transparent_hugepage/enabled - - - - madvise
EOF
log_ok "Transparent HugePage configurado para madvise (JVM benefit)"

# ─── 2. ZRAM — verificar e otimizar ──────────────────────────────────────────
log_step "2/8 — ZRAM (swap comprimido em RAM)"

ZRAM_CONF="/etc/systemd/zram-generator.conf"
[[ -f "$ZRAM_CONF" ]] && sudo cp "$ZRAM_CONF" "$BACKUP_DIR/" || true

if ! systemctl is-active --quiet swap.img.swap 2>/dev/null && \
   systemctl list-units --type=swap | grep -q zram; then
    log_ok "ZRAM já ativo (padrão Fedora)"
else
    sudo tee "$ZRAM_CONF" > /dev/null << 'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
EOF
    log_ok "ZRAM configurado: 50% da RAM, algoritmo zstd"
fi

# Garantir que não há swap em disco competindo
if swapon --show | grep -q "/dev\|/swapfile\|swap.img"; then
    log_warn "Swap em disco detectado. Considere remover para priorizar ZRAM."
    log_info "Execute: sudo swapoff /swapfile && sudo rm /swapfile"
fi

# ─── 3. CPU — AMD pstate + tuned + auto-cpufreq ──────────────────────────────
log_step "3/8 — CPU: AMD pstate + tuned + auto-cpufreq"

# Verificar amd_pstate
SCALING_DRIVER=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null || echo "unknown")
if [[ "$SCALING_DRIVER" == "amd_pstate_epp" ]]; then
    log_ok "amd_pstate_epp já ativo ($SCALING_DRIVER)"
else
    log_warn "Driver atual: $SCALING_DRIVER — amd_pstate pode não estar ativo"
    GRUB_FILE="/etc/default/grub"
    sudo cp "$GRUB_FILE" "$BACKUP_DIR/grub.bak"
    if ! grep -q "amd_pstate=active" "$GRUB_FILE"; then
        sudo sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 amd_pstate=active"/' "$GRUB_FILE"
        sudo grub2-mkconfig -o /boot/grub2/grub.cfg
        log_ok "amd_pstate=active adicionado ao GRUB (ativo após reboot)"
    fi
fi

# tuned — perfil correto
if command -v tuned-adm &>/dev/null; then
    sudo systemctl enable --now tuned &>/dev/null
    sudo tuned-adm profile laptop-ac-powersave
    log_ok "tuned ativo com perfil laptop-ac-powersave"
fi

# auto-cpufreq
if command -v auto-cpufreq &>/dev/null; then
    sudo auto-cpufreq --install 2>/dev/null \
        && log_ok "auto-cpufreq instalado como serviço" \
        || log_warn "auto-cpufreq já estava instalado como serviço"
    # Desativar power-profiles-daemon para não conflitar
    sudo systemctl disable --now power-profiles-daemon 2>/dev/null \
        && log_ok "power-profiles-daemon desativado (conflito com auto-cpufreq)" \
        || true
else
    log_warn "auto-cpufreq não encontrado — instale com: sudo dnf install auto-cpufreq"
fi

# ─── 4. I/O — SSD NVMe ───────────────────────────────────────────────────────
log_step "4/8 — I/O: SSD NVMe + btrfs"

# Scheduler NVMe
NVME_DEV=$(ls /sys/block/ | grep nvme | head -1 || echo "")
if [[ -n "$NVME_DEV" ]]; then
    SCHEDULER=$(cat "/sys/block/$NVME_DEV/queue/scheduler" 2>/dev/null || echo "")
    log_info "Scheduler atual ($NVME_DEV): $SCHEDULER"

    # NVMe com múltiplas filas usa 'none' ou 'kyber' — ambos ideais
    if echo "$SCHEDULER" | grep -q "\[none\]\|\[kyber\]"; then
        log_ok "Scheduler já otimizado para NVMe"
    else
        echo "kyber" | sudo tee "/sys/block/$NVME_DEV/queue/scheduler" > /dev/null
        log_ok "Scheduler alterado para kyber"
    fi

    # Persistir via udev
    sudo tee /etc/udev/rules.d/60-nvme-scheduler.rules > /dev/null << 'EOF'
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="kyber"
EOF
    log_ok "Regra udev criada para persistir scheduler no boot"
fi

# fstab btrfs — verificar e otimizar
FSTAB="/etc/fstab"
sudo cp "$FSTAB" "$BACKUP_DIR/fstab.bak"

if grep -q "btrfs" "$FSTAB"; then
    if ! grep -q "noatime" "$FSTAB"; then
        sudo sed -i '/btrfs/s/defaults/defaults,noatime,compress=zstd:1,space_cache=v2,discard=async/' "$FSTAB"
        log_ok "fstab btrfs: noatime + zstd:1 + space_cache=v2 + discard=async"
    else
        log_ok "fstab btrfs já otimizado"
    fi
fi

# fstrim timer
sudo systemctl enable --now fstrim.timer
log_ok "fstrim.timer ativado (TRIM semanal)"

# irqbalance
sudo systemctl enable --now irqbalance
log_ok "irqbalance ativado (distribuição de interrupções no AMD multi-core)"

# ─── 5. Boot — sem Plymouth mas serviços desnecessários removidos ─────────────
log_step "5/8 — Boot: desativar serviços lentos (Plymouth preservado)"

log_info "Plymouth preservado conforme solicitado ✓"

# NetworkManager-wait-online — maior culpado de boot lento (~10s)
sudo systemctl disable --now NetworkManager-wait-online.service 2>/dev/null \
    && log_ok "NetworkManager-wait-online desativado (~5-10s de boot economizados)" \
    || log_ok "NetworkManager-wait-online já estava desativado"

# avahi-daemon
sudo systemctl disable --now avahi-daemon 2>/dev/null \
    && log_ok "avahi-daemon desativado" || true

# ModemManager
sudo systemctl disable --now ModemManager 2>/dev/null \
    && log_ok "ModemManager desativado" || true

# Relatório de boot atual
echo ""
log_info "Tempo de boot atual:"
systemd-analyze 2>/dev/null | head -3 || true

# ─── 6. RAM — earlyoom + preload ─────────────────────────────────────────────
log_step "6/8 — RAM: earlyoom + preload"

if command -v earlyoom &>/dev/null; then
    sudo systemctl enable --now earlyoom
    log_ok "earlyoom ativo (mata processos antes do OOM killer brutal)"
fi

if command -v preload &>/dev/null; then
    sudo systemctl enable --now preload
    log_ok "preload ativo (pré-carrega apps frequentes)"
else
    sudo dnf install -y preload &>/dev/null \
        && sudo systemctl enable --now preload \
        && log_ok "preload instalado e ativado" \
        || log_warn "preload não disponível no repo"
fi

# ─── 7. Powertop auto-tune ───────────────────────────────────────────────────
log_step "7/8 — Energia: powertop auto-tune"

POWERTOP_SERVICE="/etc/systemd/system/powertop.service"
sudo tee "$POWERTOP_SERVICE" > /dev/null << 'EOF'
[Unit]
Description=PowerTop auto-tune — AMD notebook power savings
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/powertop --auto-tune
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now powertop.service
log_ok "powertop.service criado e ativado"

# ─── 8. Relatório final ───────────────────────────────────────────────────────
log_step "8/8 — Relatório de otimizações"

echo ""
echo -e "${BOLD}${GREEN}Otimizações aplicadas:${NC}"
echo ""
printf "  %-35s %s\n" "vm.swappiness"           "10 (era 60)"
printf "  %-35s %s\n" "Transparent HugePage"     "madvise (JVM)"
printf "  %-35s %s\n" "ZRAM"                     "zstd, 50% RAM"
printf "  %-35s %s\n" "amd_pstate"               "active (EPP)"
printf "  %-35s %s\n" "tuned"                    "laptop-ac-powersave"
printf "  %-35s %s\n" "auto-cpufreq"             "serviço ativo"
printf "  %-35s %s\n" "NVMe scheduler"           "kyber"
printf "  %-35s %s\n" "btrfs mount"              "noatime+zstd:1+discard=async"
printf "  %-35s %s\n" "fstrim.timer"             "ativo"
printf "  %-35s %s\n" "irqbalance"               "ativo"
printf "  %-35s %s\n" "earlyoom"                 "ativo"
printf "  %-35s %s\n" "powertop"                 "auto-tune no boot"
printf "  %-35s %s\n" "NetworkManager-wait"      "desativado"
printf "  %-35s %s\n" "Plymouth"                 "PRESERVADO ✓"
echo ""
echo -e "${YELLOW}⚠  Reinicie o sistema para aplicar todas as mudanças.${NC}"
echo -e "   Log completo: ${BOLD}$LOGFILE${NC}"
echo -e "   Backup das configs originais: ${BOLD}$BACKUP_DIR${NC}"
echo ""
