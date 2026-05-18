#!/usr/bin/env bash
# =============================================================================
# post-install.sh — Fedora Post-Install para Lucas
# Dev Backend Java | AMD APU | Fluent Blue Dark | Warp WebApps
# v3 — FiraCode + Polyglot Dev Stack + Symos-dotfiles + Starship + OnlyOffice
# =============================================================================

set -euo pipefail

# ─── Cores para output ────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_step()  { echo -e "\n${BOLD}${BLUE}══ $1${NC}"; }
log_ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
log_warn()  { echo -e "  ${YELLOW}⚠${NC}  $1"; }
log_err()   { echo -e "  ${RED}✗${NC} $1"; }
log_info()  { echo -e "  ${CYAN}→${NC} $1"; }

LOGFILE="$HOME/post-install.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║      Fedora Post-Install — Lucas Dev Setup       ║"
echo "║   Java · Go · Rust · Ruby · Node · .NET · Bun   ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Log completo em: $LOGFILE"
sleep 2

# ─── Verificações iniciais ────────────────────────────────────────────────────
if [[ "$EUID" -eq 0 ]]; then
    log_err "Não rode como root. O script pedirá sudo quando necessário."
    exit 1
fi

if ! ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
    log_err "Sem conexão com a internet. Abortando."
    exit 1
fi

export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$HOME/.bun/bin:$PATH"

# ─── 1. DNF otimizado ─────────────────────────────────────────────────────────
log_step "1/16 — Otimizando DNF"

sudo tee /etc/dnf/dnf.conf > /dev/null << 'EOF'
[main]
gpgcheck=True
installonly_limit=3
clean_requirements_on_remove=True
best=False
skip_if_unavailable=True
fastestmirror=True
max_parallel_downloads=10
defaultyes=True
keepcache=True
EOF
log_ok "dnf.conf otimizado"

# ─── 2. RPM Fusion + Flathub ──────────────────────────────────────────────────
log_step "2/16 — Repositórios: RPM Fusion + Flathub"

FEDORA_VER=$(rpm -E %fedora)

sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm" \
    || log_warn "RPM Fusion pode já estar instalado"

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
log_ok "RPM Fusion + Flathub configurados"

# ─── 3. Atualização completa ──────────────────────────────────────────────────
log_step "3/16 — Atualização completa do sistema"
sudo dnf upgrade -y --refresh
log_ok "Sistema atualizado"

# ─── 4. Codecs + drivers AMD ──────────────────────────────────────────────────
log_step "4/16 — Codecs multimídia + drivers AMD APU"

sudo dnf install -y \
    ffmpeg \
    gstreamer1-plugins-base \
    gstreamer1-plugins-good \
    gstreamer1-plugins-bad-free \
    gstreamer1-plugins-ugly-free \
    gstreamer1-plugin-openh264 \
    gstreamer1-vaapi \
    mesa-va-drivers \
    mesa-vdpau-drivers \
    libva-utils \
    radeontop \
    || log_warn "Alguns codecs podem ter falhado"

GRUB_FILE="/etc/default/grub"
if ! grep -q "amd_pstate=active" "$GRUB_FILE"; then
    sudo sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 amd_pstate=active"/' "$GRUB_FILE"
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg
    log_ok "amd_pstate=active adicionado ao GRUB"
else
    log_ok "amd_pstate=active já configurado"
fi

# ─── 5. Fontes ────────────────────────────────────────────────────────────────
log_step "5/16 — Fontes: MS Core + FiraCode NF + JetBrainsMono NF"

sudo dnf install -y curl cabextract xorg-x11-font-utils fontconfig unzip

sudo rpm -i --force \
    https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm \
    2>/dev/null || log_warn "MS Core Fonts pode já estar instalado"

FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

install_nerd_font() {
    local name="$1"
    local check_file="$2"
    if [[ ! -f "$FONT_DIR/$name/$check_file" ]]; then
        log_info "Baixando $name Nerd Font..."
        curl -fLo "/tmp/${name}.zip" \
            "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${name}.zip"
        mkdir -p "$FONT_DIR/$name"
        unzip -q "/tmp/${name}.zip" -d "$FONT_DIR/$name/"
        rm -f "/tmp/${name}.zip"
        log_ok "$name Nerd Font instalada"
    else
        log_ok "$name Nerd Font já presente"
    fi
}

install_nerd_font "FiraCode"      "FiraCodeNerdFont-Regular.ttf"
install_nerd_font "JetBrainsMono" "JetBrainsMonoNerdFont-Regular.ttf"

fc-cache -fv "$FONT_DIR" &>/dev/null
log_ok "Cache de fontes atualizado"

# ── Starship prompt ────────────────────────────────────────────────────────
if ! command -v starship &>/dev/null; then
    log_info "Instalando Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
    log_ok "Starship instalado"
else
    log_ok "Starship já instalado ($(starship --version | head -1))"
fi

# ─── 6. Ferramentas de sistema ────────────────────────────────────────────────
log_step "6/16 — Ferramentas de sistema e CLI"

sudo dnf install -y \
    htop btop bat eza fd-find ripgrep fzf zoxide \
    tmux ncdu neofetch stow git zsh \
    gnome-tweaks gnome-extensions-app dconf-editor \
    firewall-config timeshift rclone libnotify \
    python3-nautilus blueman earlyoom irqbalance \
    powertop tuned \
    || log_warn "Alguns pacotes podem não estar disponíveis"

sudo systemctl enable --now earlyoom
sudo systemctl enable --now irqbalance
sudo systemctl enable --now tuned
sudo tuned-adm profile laptop-ac-powersave

sudo tee /etc/systemd/system/powertop.service > /dev/null << 'EOF'
[Unit]
Description=PowerTop auto-tune
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/powertop --auto-tune
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable --now powertop.service
log_ok "Ferramentas instaladas e serviços ativados"

# ─── 7. Sysctl + btrfs ───────────────────────────────────────────────────────
log_step "7/16 — Otimizações de kernel + btrfs"

sudo tee /etc/sysctl.d/99-lucas-performance.conf > /dev/null << 'EOF'
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
kernel.nmi_watchdog = 0
net.core.netdev_max_backlog = 16384
net.ipv4.tcp_fastopen = 3
EOF
sudo sysctl --system &>/dev/null
log_ok "Parâmetros de kernel aplicados"

if grep -q "btrfs" /etc/fstab && ! grep -q "noatime" /etc/fstab; then
    sudo sed -i '/btrfs/s/defaults/defaults,noatime,compress=zstd:1,space_cache=v2,discard=async/' /etc/fstab
    log_ok "fstab btrfs otimizado"
fi
sudo systemctl enable --now fstrim.timer

# ─── 8. Desativar serviços desnecessários ────────────────────────────────────
log_step "8/16 — Serviços desnecessários (Plymouth preservado)"

for svc in NetworkManager-wait-online.service avahi-daemon ModemManager; do
    sudo systemctl disable --now "$svc" 2>/dev/null \
        && log_ok "$svc desativado" \
        || log_warn "$svc já estava desativado ou não existe"
done
log_info "Plymouth preservado ✓"

# ─── 9. Dotfiles — Symos001/Symos-dotfiles via GNU Stow ──────────────────────
log_step "9/16 — Dotfiles: Symos001/Symos-dotfiles via GNU Stow"

DOTFILES_DIR="$HOME/.dotfiles"

if [[ -d "$DOTFILES_DIR/.git" ]]; then
    log_info "Dotfiles já clonados — atualizando..."
    git -C "$DOTFILES_DIR" pull --rebase --autostash
else
    log_info "Clonando Symos-dotfiles (com submódulos)..."
    git clone --recurse-submodules \
        https://github.com/Symos001/Symos-dotfiles.git \
        "$DOTFILES_DIR"
fi
log_ok "Dotfiles em $DOTFILES_DIR"

cd "$DOTFILES_DIR"

# Aplicar pacotes stow (diretórios = pacotes)
for dir in "$DOTFILES_DIR"/*/; do
    pkg=$(basename "$dir")
    # Pular diretórios ocultos e .tmux/plugins (gerenciado pelo TPM)
    [[ "$pkg" == .* ]] && continue
    stow --restow --target="$HOME" "$pkg" 2>/dev/null \
        && log_ok "stow: $pkg" \
        || log_warn "stow: $pkg falhou (possível conflito — verifique manualmente)"
done

# Arquivos soltos no root do repo (.zshrc, .tmux.conf)
for dotfile in .zshrc .tmux.conf; do
    if [[ -f "$DOTFILES_DIR/$dotfile" ]]; then
        if [[ -f "$HOME/$dotfile" && ! -L "$HOME/$dotfile" ]]; then
            mv "$HOME/$dotfile" "$HOME/${dotfile}.bak.$(date +%Y%m%d)"
            log_warn "Backup criado: ~/${dotfile}.bak"
        fi
        ln -sf "$DOTFILES_DIR/$dotfile" "$HOME/$dotfile"
        log_ok "Linkado: ~/$dotfile"
    fi
done

# TPM — Tmux Plugin Manager
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ ! -d "$TPM_DIR" ]]; then
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    log_ok "TPM instalado"
fi

# Instalar plugins headless
"$TPM_DIR/bin/install_plugins" 2>/dev/null \
    && log_ok "Plugins tmux instalados" \
    || log_warn "Plugins tmux — rode prefix+I na primeira sessão tmux"

cd - > /dev/null

# ─── 10. Linguagens de programação ───────────────────────────────────────────
log_step "10/16 — Linguagens: Java · Go · Rust · Ruby · Node · Bun · pnpm · yarn · .NET 9"

# ── Java via SDKMan ──────────────────────────────────────────────────────
log_info "[Java] Instalando SDKMan..."
if [[ ! -d "$HOME/.sdkman" ]]; then
    curl -s "https://get.sdkman.io" | bash
fi
export SDKMAN_DIR="$HOME/.sdkman"
# shellcheck disable=SC1091
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh" || true

if command -v sdk &>/dev/null; then
    sdk install java 21.0.3-tem  2>/dev/null || true
    sdk install java 17.0.11-tem 2>/dev/null || true
    sdk install maven            2>/dev/null || true
    sdk install gradle           2>/dev/null || true
    sdk default java 21.0.3-tem  2>/dev/null || true
    log_ok "[Java] JDK 21 (default) + JDK 17 + Maven + Gradle via SDKMan"
else
    log_warn "[Java] SDKMan não disponível no contexto do script. Após relogin:"
    log_warn "  source ~/.sdkman/bin/sdkman-init.sh && sdk install java 21.0.3-tem"
fi

# ── Go ────────────────────────────────────────────────────────────────────
if ! command -v go &>/dev/null; then
    sudo dnf install -y golang
fi
log_ok "[Go] $(go version 2>/dev/null | awk '{print $3}' || echo 'instalado')"

# ── Rust via rustup ───────────────────────────────────────────────────────
if ! command -v rustup &>/dev/null; then
    log_info "[Rust] Instalando via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi
source "$HOME/.cargo/env" 2>/dev/null || true
rustup toolchain install stable    2>/dev/null || true
rustup component add rust-analyzer clippy rustfmt 2>/dev/null || true
rustup update stable &>/dev/null   2>/dev/null || true
log_ok "[Rust] $(rustc --version 2>/dev/null || echo 'disponível após relogin')"

# ── Ruby via rbenv ────────────────────────────────────────────────────────
if ! command -v rbenv &>/dev/null; then
    log_info "[Ruby] Instalando rbenv..."
    if ! sudo dnf install -y rbenv ruby-build &>/dev/null; then
        git clone https://github.com/rbenv/rbenv.git "$HOME/.rbenv" 2>/dev/null || true
        git clone https://github.com/rbenv/ruby-build.git "$HOME/.rbenv/plugins/ruby-build" 2>/dev/null || true
    fi
    export PATH="$HOME/.rbenv/bin:$PATH"
fi
eval "$(rbenv init - 2>/dev/null)" || true
RUBY_VER=$(rbenv install -l 2>/dev/null | grep -E '^\s+[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ' || echo "")
if [[ -n "$RUBY_VER" ]]; then
    rbenv install "$RUBY_VER" 2>/dev/null || true
    rbenv global "$RUBY_VER"  2>/dev/null || true
    log_ok "[Ruby] $RUBY_VER via rbenv"
else
    sudo dnf install -y ruby ruby-devel &>/dev/null || true
    log_ok "[Ruby] instalado via dnf (fallback)"
fi

# ── Node.js via fnm ───────────────────────────────────────────────────────
if ! command -v fnm &>/dev/null; then
    log_info "[Node] Instalando fnm..."
    curl -fsSL https://fnm.vercel.app/install | bash
    export PATH="$HOME/.local/share/fnm:$PATH"
fi
eval "$(fnm env 2>/dev/null)" || true
fnm install --lts 2>/dev/null || true
fnm use lts-latest 2>/dev/null || true
log_ok "[Node] $(node --version 2>/dev/null || echo 'disponível após relogin') via fnm"

# ── pnpm ──────────────────────────────────────────────────────────────────
if ! command -v pnpm &>/dev/null; then
    curl -fsSL https://get.pnpm.io/install.sh | sh -
    export PATH="$HOME/.local/share/pnpm:$PATH"
fi
log_ok "[pnpm] $(pnpm --version 2>/dev/null || echo 'instalado')"

# ── yarn ──────────────────────────────────────────────────────────────────
if command -v npm &>/dev/null && ! command -v yarn &>/dev/null; then
    npm install -g yarn &>/dev/null
fi
log_ok "[yarn] $(yarn --version 2>/dev/null || echo 'instalado')"

# ── Bun ───────────────────────────────────────────────────────────────────
if ! command -v bun &>/dev/null; then
    log_info "[Bun] Instalando..."
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
fi
log_ok "[Bun] $(bun --version 2>/dev/null || echo 'disponível após relogin')"

# ── .NET 9 ────────────────────────────────────────────────────────────────
if ! command -v dotnet &>/dev/null; then
    log_info "[.NET] Instalando SDK 9..."
    if ! sudo dnf install -y dotnet-sdk-9.0 &>/dev/null; then
        log_warn "[.NET] Não encontrado no repo padrão — usando script oficial Microsoft..."
        curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 9.0 --install-dir "$HOME/.dotnet"
        export PATH="$HOME/.dotnet:$HOME/.dotnet/tools:$PATH"
    fi
fi
log_ok "[.NET] $(dotnet --version 2>/dev/null || echo 'disponível após relogin')"

# ─── 11. Docker + firewalld ───────────────────────────────────────────────────
log_step "11/16 — Docker CE + Compose"

if ! command -v docker &>/dev/null; then
    sudo dnf config-manager --add-repo \
        https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo systemctl enable --now docker
    sudo usermod -aG docker "$USER"
    log_ok "Docker CE instalado — logout/login para usar sem sudo"
else
    log_ok "Docker já instalado"
fi

sudo firewall-cmd --permanent --zone=trusted --add-interface=docker0 2>/dev/null || true
sudo firewall-cmd --reload 2>/dev/null || true
log_ok "docker0 → zone trusted"

# ─── 12. Python + uv + Neovim + apps ─────────────────────────────────────────
log_step "12/16 — Python (uv) + Neovim + DBeaver + Bruno"

sudo dnf install -y python3 python3-pip neovim

if ! command -v uv &>/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    log_ok "uv instalado"
else
    log_ok "uv já instalado"
fi

log_ok "Neovim instalado — config carregada dos dotfiles (nvim/)"

flatpak install -y flathub io.dbeaver.DBeaverCommunity && log_ok "DBeaver instalado"
flatpak install -y flathub com.usebruno.Bruno           && log_ok "Bruno instalado"

# ── LibreOffice → OnlyOffice ───────────────────────────────────────────────
log_info "Removendo LibreOffice..."
sudo dnf remove -y \
    libreoffice\* \
    2>/dev/null && log_ok "LibreOffice removido" \
    || log_warn "LibreOffice não estava instalado ou já foi removido"
sudo dnf autoremove -y &>/dev/null || true

log_info "Instalando OnlyOffice Desktop Editors..."
flatpak install -y flathub org.onlyoffice.desktopeditors \
    && log_ok "OnlyOffice Desktop Editors instalado via Flatpak" \
    || log_warn "OnlyOffice falhou — instale manualmente: flatpak install flathub org.onlyoffice.desktopeditors"

# ─── 13. Tema: Fluent Blue Dark + Ícones Fluent + Folder Color ───────────────
log_step "13/16 — Tema Fluent Blue Dark + Ícones Fluent + Folder Color"

THEME_DIR="$HOME/.local/share/themes"
ICON_DIR="$HOME/.local/share/icons"
mkdir -p "$THEME_DIR" "$ICON_DIR"

if [[ ! -d "$THEME_DIR/Fluent-Dark" ]]; then
    git clone --depth=1 https://github.com/vinceliuice/Fluent-gtk-theme /tmp/fluent-gtk-theme
    cd /tmp/fluent-gtk-theme
    ./install.sh \
        --dest "$THEME_DIR" \
        --name Fluent \
        --theme default \
        --color dark \
        --size standard \
        --tweaks blur round \
        --icon fedora \
        --libadwaita
    cd -
    log_ok "Fluent GTK Theme instalado"
else
    log_ok "Fluent GTK Theme já presente"
fi

if [[ ! -d "$ICON_DIR/Fluent-dark" ]]; then
    git clone --depth=1 https://github.com/vinceliuice/Fluent-icon-theme /tmp/fluent-icon-theme
    cd /tmp/fluent-icon-theme
    ./install.sh --dest "$ICON_DIR" --theme default --color dark
    cd -
    log_ok "Fluent Icon Theme instalado"
else
    log_ok "Fluent Icon Theme já presente"
fi

if [[ ! -d /tmp/folder-color ]]; then
    git clone --depth=1 https://github.com/costales/folder-color /tmp/folder-color
    cd /tmp/folder-color
    python3 setup.py install --prefix="$HOME/.local" 2>/dev/null || true
    cd -
    nautilus -q 2>/dev/null || true
    log_ok "Folder Color instalado"
fi

gsettings set org.gnome.desktop.interface gtk-theme           'Fluent-Dark'
gsettings set org.gnome.desktop.interface icon-theme          'Fluent-dark'
gsettings set org.gnome.desktop.interface color-scheme        'prefer-dark'
gsettings set org.gnome.desktop.wm.preferences theme          'Fluent-Dark'
gsettings set org.gnome.desktop.interface monospace-font-name 'FiraCode Nerd Font 11'
log_ok "Tema + FiraCode como fonte monospace aplicados"

sudo flatpak override --filesystem="$HOME/.local/share/themes"
sudo flatpak override --filesystem="$HOME/.local/share/icons"
sudo flatpak override --env=GTK_THEME=Fluent-Dark
sudo flatpak override --env=ICON_THEME=Fluent-dark
log_ok "Flatpak configurado para usar tema Fluent"

# ─── 14. GNOME Extensions ────────────────────────────────────────────────────
log_step "14/16 — GNOME Extensions"

sudo dnf install -y gnome-shell-extension-blur-my-shell \
    || log_warn "blur-my-shell não encontrado no repo — instale via extensions.gnome.org"

flatpak install -y flathub io.github.realmazharhussain.GdmSettings \
    && log_ok "GDM Settings instalado" \
    || log_warn "GDM Settings falhou — tente manualmente"

log_info "Extensões adicionais (instalar via https://extensions.gnome.org):"
log_info "  • Blur-Me        → /extension/4236/"
log_info "  • Dash to Dock   → /extension/307/"
log_info "  • AppIndicator   → /extension/615/"
log_info "  • Clipboard Ind. → /extension/779/"
log_info "  • GSConnect      → /extension/1319/"

# ─── 15. Warp (GNOME WebApps) ────────────────────────────────────────────────
log_step "15/16 — Warp (GNOME WebApps)"

flatpak install -y flathub app.drey.Warp \
    && log_ok "Warp instalado" \
    || log_warn "Warp não encontrado — instale manualmente: flatpak install flathub app.drey.Warp"

# ─── 16. Backup: Timeshift + rclone ──────────────────────────────────────────
log_step "16/16 — Sistema de Backup"

log_info "Timeshift e rclone já instalados (etapa 6)"
log_warn "Execute: rclone config  (autenticar com OneDrive)"
log_info "Instale backup.sh + backup.service + backup.timer do setup de backup"

# ─── Resumo final ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║         Post-Install Concluído! ✓                ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BOLD}Stack instalada:${NC}"
echo ""
printf "  %-22s %s\n" "Java 21"      "JDK 21 (default) + JDK 17 via SDKMan"
printf "  %-22s %s\n" "Go"           "via dnf"
printf "  %-22s %s\n" "Rust"         "via rustup (stable + rust-analyzer + clippy)"
printf "  %-22s %s\n" "Ruby"         "via rbenv (latest stable)"
printf "  %-22s %s\n" "Node.js LTS"  "via fnm"
printf "  %-22s %s\n" "pnpm"         "via script oficial"
printf "  %-22s %s\n" "yarn"         "via npm"
printf "  %-22s %s\n" "Bun"          "via script oficial"
printf "  %-22s %s\n" ".NET 9 SDK"   "via dnf ou script Microsoft"
printf "  %-22s %s\n" "Python"       "dnf + uv"
printf "  %-22s %s\n" "Docker CE"    "+ Compose plugin"
printf "  %-22s %s\n" "Dotfiles"     "~/.dotfiles → GNU Stow (nvim, alacritty, tmux, zsh)"
printf "  %-22s %s\n" "Fontes"       "FiraCode NF + JetBrainsMono NF + MS Core Fonts"
printf "  %-22s %s\n" "Starship"     "prompt moderno (instalar init no .zshrc via dotfiles)"
printf "  %-22s %s\n" "Tema"         "Fluent Blue Dark + Ícones Fluent"
printf "  %-22s %s\n" "Office"       "OnlyOffice Desktop (LibreOffice removido)"
printf "  %-22s %s\n" "WebApps"      "Warp (GNOME WebApps)"
echo ""

echo -e "${BOLD}Próximos passos:${NC}"
echo ""
echo -e "  ${CYAN}1.${NC} Reiniciar sessão para ativar no PATH:"
echo "       Docker sem sudo · SDKMan · Rust/Cargo · Bun · fnm · .NET"
echo ""
echo -e "  ${CYAN}2.${NC} OneDrive:  rclone config"
echo ""
echo -e "  ${CYAN}3.${NC} Extensões GNOME: https://extensions.gnome.org"
echo "       (Blur-Me · Dash to Dock · AppIndicator · Clipboard · GSConnect)"
echo ""
echo -e "  ${CYAN}4.${NC} Timeshift: sudo timeshift-gtk"
echo ""
echo -e "  ${CYAN}5.${NC} Plugins tmux: abra o tmux → prefix + I"
echo ""
echo -e "  ${CYAN}6.${NC} Verificar dotfiles:"
echo "       ls -la ~/.config/nvim ~/.config/alacritty ~/.zshrc ~/.tmux.conf"
echo ""
echo -e "  Log: ${BOLD}$LOGFILE${NC}"
echo ""
