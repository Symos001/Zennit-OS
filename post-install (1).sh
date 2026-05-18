#!/usr/bin/env bash
# =============================================================================
# post-install.sh — Fedora Post-Install para Lucas
# Dev Backend Java | AMD APU | Fluent Blue Dark | Warp WebApps
# v6 — Correções: robustez de rede, SDKMan não-interativo, GRUB único, etc.
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
log_ok "Sistema updated"

# ─── 4. Codecs + drivers AMD ──────────────────────────────────────────────────
log_step "4/16 — Codecs multimídia + drivers AMD APU"

# Garantir grubby para injeção de parâmetros de kernel
sudo dnf install -y grubby

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

sudo grubby --update-kernel=ALL --args="amd_pstate=active"
log_ok "amd_pstate=active injetado de forma persistente via grubby"

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
        local tmp_zip="/tmp/${name}.zip"
        if curl -fLo "$tmp_zip" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${name}.zip"; then
            mkdir -p "$FONT_DIR/$name"
            if unzip -q "$tmp_zip" -d "$FONT_DIR/$name/"; then
                rm -f "$tmp_zip"
                log_ok "$name Nerd Font instalada"
            else
                log_warn "Falha ao descompactar $name"
            fi
        else
            log_warn "Download da fonte $name falhou"
        fi
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
    curl -sS https://starship.rs/install.sh | sh -s -- --yes || log_warn "Falha ao instalar Starship"
    log_ok "Starship instalado"
else
    log_ok "Starship já instalado ($(starship --version | head -1))"
fi

# ─── 6. Ferramentas de sistema + Configuração ZSH ─────────────────────────────
log_step "6/16 — Ferramentas de sistema, CLI e Shell padrão ZSH"

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
sudo tuned-adm profile off || true
log_warn "earlyoom ativo: pode encerrar processos sob alta pressão de memória (builds/IDEs)."

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

# Define o ZSH como shell padrão do usuário
if [[ "$(getent passwd "$USER" | cut -d: -f7)" != */zsh ]]; then
    log_info "Configurando o ZSH como shell padrão..."
    sudo chsh -s "$(which zsh)" "$USER"
    log_ok "ZSH definido como shell padrão"
fi
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

# btrfs: só modifica se a linha de montagem usar "defaults"
if grep -q "btrfs" /etc/fstab && ! grep -q "noatime" /etc/fstab; then
    if grep "btrfs.*defaults" /etc/fstab &>/dev/null; then
        sudo sed -i '/btrfs/s/defaults/defaults,noatime,compress=zstd:1,space_cache=v2,discard=async/' /etc/fstab
        log_ok "fstab btrfs otimizado"
    else
        log_warn "A partição btrfs não usa 'defaults' nas opções de montagem — ajuste manualmente se desejar."
    fi
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
    git -C "$DOTFILES_DIR" pull --rebase --autostash || log_warn "Falha ao atualizar dotfiles"
else
    log_info "Clonando Symos-dotfiles (com submódulos)..."
    git clone --recurse-submodules \
        https://github.com/Symos001/Symos-dotfiles.git \
        "$DOTFILES_DIR" || log_warn "Clone dos dotfiles falhou"
fi
log_ok "Dotfiles em $DOTFILES_DIR"

cd "$DOTFILES_DIR"

# Limpeza preventiva do zshrc/tmux real para o Stow criar symlinks sem conflito
if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
    mv "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%Y%m%d-%H%M%S)"
    log_warn "Backup protetor de arquivo real existente: ~/.zshrc.bak"
fi

if [[ -f "$HOME/.tmux.conf" && ! -L "$HOME/.tmux.conf" ]]; then
    mv "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak.$(date +%Y%m%d-%H%M%S)"
    log_warn "Backup protetor de arquivo real existente: ~/.tmux.conf.bak"
fi

# Aplicar pacotes stow (diretórios = pacotes)
for dir in "$DOTFILES_DIR"/*/; do
    pkg=$(basename "$dir")
    [[ "$pkg" == .* ]] && continue
    
    if [[ -d "$HOME/.config/$pkg" && ! -L "$HOME/.config/$pkg" ]]; then
        mv "$HOME/.config/$pkg" "$HOME/.config/${pkg}.bak.$(date +%Y%m%d)"
    fi

    stow --restow --target="$HOME" "$pkg" 2>/dev/null \
        && log_ok "stow: $pkg" \
        || log_warn "stow: $pkg falhou (possível conflito — verifique manualmente)"
done

# Vincular arquivos soltos do root do repositório
if [[ -f "$DOTFILES_DIR/.zshrc" ]]; then
    ln -sf "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
    log_ok "Linkado: ~/.zshrc"
fi

if [[ -f "$DOTFILES_DIR/.tmux.conf" ]]; then
    ln -sf "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
    log_ok "Linkado: ~/.tmux.conf"
fi

# TPM — Tmux Plugin Manager
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ ! -d "$TPM_DIR" ]]; then
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR" || log_warn "Falha ao clonar TPM"
    log_ok "TPM instalado"
fi

"$TPM_DIR/bin/install_plugins" 2>/dev/null \
    && log_ok "Plugins tmux instalados" \
    || log_warn "Plugins tmux — rode prefix+I na primeira sessão tmux"

cd - > /dev/null

if [[ ! -f "$HOME/.zshrc" ]]; then
    touch "$HOME/.zshrc"
fi

# ─── 10. Linguagens de programação ───────────────────────────────────────────
log_step "10/16 — Linguagens: Java · Go · Rust · Ruby · Node · Bun · pnpm · yarn · .NET 9"

# ── Java via SDKMan ──────────────────────────────────────────────────────
log_info "[Java] Instalando SDKMan..."
if [[ ! -d "$HOME/.sdkman" ]]; then
    curl -s "https://get.sdkman.io" | bash -s -- -y || log_warn "Falha ao instalar SDKMan"
fi
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh" || true

if command -v sdk &>/dev/null; then
    sdk install java 21-tem  2>/dev/null || true
    sdk install java 17-tem 2>/dev/null || true
    sdk install maven            2>/dev/null || true
    sdk install gradle           2>/dev/null || true
    sdk default java 21-tem  2>/dev/null || true
    log_ok "[Java] JDK 21 (default) + JDK 17 + Maven + Gradle via SDKMan"
else
    log_warn "[Java] SDKMan não disponível no contexto do script."
fi

# ── Go ────────────────────────────────────────────────────────────────────
if ! command -v go &>/dev/null; then
    sudo dnf install -y golang
fi
log_ok "[Go] $(go version 2>/dev/null | awk '{print $3}' || echo 'instalado')"

# ── Rust via rustup ───────────────────────────────────────────────────────
if ! command -v rustup &>/dev/null; then
    log_info "[Rust] Instalando via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path || log_warn "Falha ao instalar rustup"
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
    curl -fsSL https://fnm.vercel.app/install | bash || log_warn "Falha ao instalar fnm"
    export PATH="$HOME/.local/share/fnm:$PATH"
fi
eval "$(fnm env 2>/dev/null)" || true
fnm install --lts 2>/dev/null || true
fnm use lts-latest 2>/dev/null || true
log_ok "[Node] $(node --version 2>/dev/null || echo 'disponível após relogin') via fnm"

# ── pnpm ──────────────────────────────────────────────────────────────────
if ! command -v pnpm &>/dev/null; then
    curl -fsSL https://get.pnpm.io/install.sh | sh - || log_warn "Falha ao instalar pnpm"
    export PATH="$HOME/.local/share/pnpm:$PATH"
fi
log_ok "[pnpm] $(pnpm --version 2>/dev/null || echo 'instalado')"

# ── yarn ──────────────────────────────────────────────────────────────────
if command -v npm &>/dev/null && ! command -v yarn &>/dev/null; then
    npm install -g yarn &>/dev/null || log_warn "Falha ao instalar yarn"
fi
log_ok "[yarn] $(yarn --version 2>/dev/null || echo 'instalado')"

# ── Bun ───────────────────────────────────────────────────────────────────
if ! command -v bun &>/dev/null; then
    log_info "[Bun] Instalando..."
    curl -fsSL https://bun.sh/install | bash || log_warn "Falha ao instalar Bun"
    export PATH="$HOME/.bun/bin:$PATH"
fi
log_ok "[Bun] $(bun --version 2>/dev/null || echo 'disponível após relogin')"

# ── .NET 9 ────────────────────────────────────────────────────────────────
if ! command -v dotnet &>/dev/null; then
    log_info "[.NET] Instalando SDK 9..."
    if ! sudo dnf install -y dotnet-sdk-9.0 &>/dev/null; then
        curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 9.0 --install-dir "$HOME/.dotnet" || log_warn "Falha ao instalar .NET"
        export PATH="$HOME/.dotnet:$HOME/.dotnet/tools:$PATH"
    fi
fi
log_ok "[.NET] $(dotnet --version 2>/dev/null || echo 'disponível após relogin')"

# ─── 11. Docker + firewalld ───────────────────────────────────────────────────
log_step "11/16 — Docker CE + Compose"

# Garantir plugin dnf para adicionar repositório
sudo dnf install -y dnf-plugins-core

if ! command -v docker &>/dev/null; then
    sudo dnf config-manager --add-repo \
        https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo systemctl enable --now docker
    getent group docker || sudo groupadd docker
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
    curl -LsSf https://astral.sh/uv/install.sh | sh || log_warn "Falha ao instalar uv"
    log_ok "uv instalado"
else
    log_ok "uv já instalado"
fi

log_ok "Neovim instalado — config carregada dos dotfiles (nvim/)"

flatpak install -y flathub io.dbeaver.DBeaverCommunity && log_ok "DBeaver instalado" || log_warn "Falha ao instalar DBeaver"
flatpak install -y flathub com.usebruno.Bruno           && log_ok "Bruno instalado"   || log_warn "Falha ao instalar Bruno"

# ── LibreOffice → OnlyOffice ───────────────────────────────────────────────
log_info "Removendo LibreOffice..."
sudo dnf remove -y libreoffice\* 2>/dev/null && log_ok "LibreOffice removido" || log_warn "LibreOffice não instalado"
sudo dnf autoremove -y &>/dev/null || true

log_info "Instalando OnlyOffice Desktop Editors..."
flatpak install -y flathub org.onlyoffice.desktopeditors && log_ok "OnlyOffice Desktop Editors instalado" || log_warn "Falha ao instalar OnlyOffice"

# ─── 13. Tema + Wallpaper Dinâmico Nativo (Firewatch) ────────────────────────
log_step "13/16 — Tema Fluent Blue Dark + Wallpaper Dinâmico Nativo (Sem Mac)"

THEME_DIR="$HOME/.local/share/themes"
ICON_DIR="$HOME/.local/share/icons"
mkdir -p "$THEME_DIR" "$ICON_DIR"

if [[ ! -d "$THEME_DIR/Fluent-Dark" ]]; then
    if git clone --depth=1 https://github.com/vinceliuice/Fluent-gtk-theme /tmp/fluent-gtk-theme; then
        cd /tmp/fluent-gtk-theme
        ./install.sh --dest "$THEME_DIR" --name Fluent --theme default --color dark --size standard --tweaks blur round --icon fedora --libadwaita \
            && log_ok "Fluent GTK Theme instalado" || log_warn "Falha na instalação do tema Fluent"
        cd -
    else
        log_warn "Clone do tema Fluent falhou"
    fi
else
    log_ok "Fluent GTK Theme já presente"
fi

if [[ ! -d "$ICON_DIR/Fluent-dark" ]]; then
    if git clone --depth=1 https://github.com/vinceliuice/Fluent-icon-theme /tmp/fluent-icon-theme; then
        cd /tmp/fluent-icon-theme
        ./install.sh --dest "$ICON_DIR" --theme default --color dark \
            && log_ok "Fluent Icon Theme instalado" || log_warn "Falha na instalação dos ícones Fluent"
        cd -
    else
        log_warn "Clone do ícone Fluent falhou"
    fi
else
    log_ok "Fluent Icon Theme já presente"
fi

if [[ ! -d /tmp/folder-color ]]; then
    if git clone --depth=1 https://github.com/costales/folder-color /tmp/folder-color; then
        cd /tmp/folder-color
        python3 setup.py install --prefix="$HOME/.local" 2>/dev/null || log_warn "Folder Color pode não ter sido instalado"
        cd -
        nautilus -q 2>/dev/null || true
        log_ok "Folder Color instalado"
    else
        log_warn "Clone do Folder Color falhou"
    fi
fi

gsettings set org.gnome.desktop.interface gtk-theme           'Fluent-Dark' 2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme          'Fluent-dark' 2>/dev/null || true
gsettings set org.gnome.desktop.interface color-scheme        'prefer-dark' 2>/dev/null || true
gsettings set org.gnome.desktop.wm.preferences theme          'Fluent-Dark' 2>/dev/null || true
gsettings set org.gnome.desktop.interface monospace-font-name 'FiraCode Nerd Font 11' 2>/dev/null || true

sudo flatpak override --filesystem="$HOME/.local/share/themes"
sudo flatpak override --filesystem="$HOME/.local/share/icons"
sudo flatpak override --env=GTK_THEME=Fluent-Dark
sudo flatpak override --env=ICON_THEME=Fluent-dark
log_ok "Tema + Fontes aplicados"

# ── Configuração Pura do Wallpaper Dinâmico (Firewatch) ──
log_info "Baixando imagens e estruturando XML nativo do Firewatch..."
WP_DIR="$HOME/.local/share/backgrounds/firewatch"
PROP_DIR="$HOME/.local/share/gnome-background-properties"
mkdir -p "$WP_DIR" "$PROP_DIR"

for i in {1..4}; do
    curl -fLo "$WP_DIR/firewatch_$i.jpg" \
        "https://raw.githubusercontent.com/adi1090x/dynamic-wallpaper/master/images/firewatch/firewatch_$i.jpg" 2>/dev/null &
done
wait

cat << EOF > "$WP_DIR/firewatch.xml"
<background>
  <starttime>
    <year>2026</year><month>01</month><day>01</day>
    <hour>00</hour><minute>00</minute><second>00</second>
  </starttime>
  <static><duration>21600.0</duration><file>$WP_DIR/firewatch_4.jpg</file></static>
  <transition><duration>3600.0</duration><from>$WP_DIR/firewatch_4.jpg</from><to>$WP_DIR/firewatch_1.jpg</to></transition>
  <static><duration>32400.0</duration><file>$WP_DIR/firewatch_1.jpg</file></static>
  <transition><duration>3600.0</duration><from>$WP_DIR/firewatch_1.jpg</from><to>$WP_DIR/firewatch_2.jpg</to></transition>
  <static><duration>3600.0</duration><file>$WP_DIR/firewatch_2.jpg</file></static>
  <transition><duration>3600.0</duration><from>$WP_DIR/firewatch_2.jpg</from><to>$WP_DIR/firewatch_3.jpg</to></transition>
  <static><duration>10800.0</duration><file>$WP_DIR/firewatch_3.jpg</file></static>
  <transition><duration>3600.0</duration><from>$WP_DIR/firewatch_3.jpg</from><to>$WP_DIR/firewatch_4.jpg</to></transition>
</background>
EOF

cat << EOF > "$PROP_DIR/firewatch.xml"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
<wallpapers>
  <wallpaper deleted="false">
    <name>Firewatch Dinâmico</name>
    <filename>$WP_DIR/firewatch.xml</filename>
    <options>zoom</options>
  </wallpaper>
</wallpapers>
EOF
log_ok "Wallpaper Firewatch Dinâmico configurado de forma 100% nativa!"

# ─── 14. GNOME Extensions ────────────────────────────────────────────────────
log_step "14/16 — Instalando extensões GNOME solicitadas"

sudo dnf install -y unzip jq gnome-shell-extension-common 2>/dev/null

EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
mkdir -p "$EXT_DIR"

install_gnome_ext() {
    local uuid="$1"
    local ext_id="$2"
    
    if [[ ! -d "$EXT_DIR/$uuid" ]]; then
        log_info "Instalando extensão: $uuid..."
        local shell_ver
        shell_ver=$(gnome-shell --version | awk '{print $3}' | cut -d. -f1)
        
        local download_url
        download_url=$(curl -s "https://extensions.gnome.org/extension-query/?search=$ext_id" | jq -r ".extensions[] | select(.uuid==\"$uuid\") | .shell_version_map.\"$shell_ver\".download_url" 2>/dev/null)
        
        if [[ -z "$download_url" || "$download_url" == "null" ]]; then
            download_url=$(curl -s "https://extensions.gnome.org/extension-info/?uuid=$uuid" | jq -r '.download_url' 2>/dev/null)
        fi

        if [[ -n "$download_url" && "$download_url" != "null" ]]; then
            mkdir -p "$EXT_DIR/$uuid"
            if curl -sL "https://extensions.gnome.org$download_url" -o "/tmp/$uuid.zip"; then
                if unzip -q "/tmp/$uuid.zip" -d "$EXT_DIR/$uuid/"; then
                    log_ok "Extensão $uuid baixada"
                else
                    log_warn "Falha ao descompactar $uuid"
                fi
                rm -f "/tmp/$uuid.zip"
            else
                log_warn "Download da extensão $uuid falhou"
            fi
        else
            log_warn "Não foi possível obter URL para $uuid via API."
        fi
    else
        log_ok "Extensão $uuid já instalada"
    fi
}

# Instalação cronológica de todas as suas extensões desejadas
install_gnome_ext "dash-to-dock@micxgx.gmail.com" "dash-to-dock"
install_gnome_ext "appindicatorsupport@rgcjonas.gmail.com" "appindicator"
install_gnome_ext "caffeine@patapon.info" "caffeine"
install_gnome_ext "compiz-alike-magic-lamp-effect@hermes81.github.com" "magic-lamp"
install_gnome_ext "add-to-desktop@bobsilverberg" "add-to-desktop"
install_gnome_ext "ding@rastersoft.com" "desktop-icons"
install_gnome_ext "blur-my-shell@aunetx" "blur-my-shell"

flatpak install -y flathub io.github.realmazharhussain.GdmSettings && log_ok "GDM Settings instalado" || log_warn "Falha ao instalar GdmSettings"

log_info "Habilitando chaves do ecossistema de extensões..."
gsettings set org.gnome.shell enabled-extensions "['dash-to-dock@micxgx.gmail.com', 'appindicatorsupport@rgcjonas.gmail.com', 'caffeine@patapon.info', 'compiz-alike-magic-lamp-effect@hermes81.github.com', 'add-to-desktop@bobsilverberg', 'ding@rastersoft.com', 'blur-my-shell@aunetx']" 2>/dev/null || true
log_ok "Extensões integradas à inicialização do GNOME"

# ─── 15. Warp (GNOME WebApps) ────────────────────────────────────────────────
log_step "15/16 — Warp (GNOME WebApps)"

flatpak install -y flathub app.drey.Warp && log_ok "Warp instalado" || log_warn "Falha ao instalar Warp"

# ─── 16. Backup: Timeshift + rclone ──────────────────────────────────────────
log_step "16/16 — Sistema de Backup"
log_info "Timeshift e rclone já instalados (etapa 6)"

# ─── Resumo final e injeções no .zshrc ────────────────────────────────────────
log_step "Finalizando injeções de ambiente no .zshrc"

sed -i '/# zennit-os paths/d' "$HOME/.zshrc" 2>/dev/null || true
cat << 'EOF' >> "$HOME/.zshrc"

# zennit-os paths
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$HOME/.bun/bin:$HOME/.dotnet:$HOME/.dotnet/tools:$PATH"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
eval "$(fnm env 2>/dev/null)"
eval "$(starship init zsh 2>/dev/null)"
EOF

echo -e "\n${BOLD}${GREEN}╔══════════════════════════════════════════════════╗"
echo "║   Post-Install Concluído! Shell Padrão: ZSH      ║"
echo "╚══════════════════════════════════════════════════╝${NC}\n"
echo -e "${YELLOW}⚠  Lembre-se de reiniciar a sessão (logout/login) para que todas as variáveis de ambiente e o novo shell sejam carregados corretamente.${NC}"
