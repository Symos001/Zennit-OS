
<div><img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/a8d1d13e-6fce-4572-92bb-9669386858a6" />
</div>
<h1 align="center"> zennit-OS</h1>

<p align="center">
  <em>Uma suíte automatizada de pós-instalação e otimização de performance para Fedora Workstation, focada em desenvolvimento Backend.</em>
</p>

---

## 📌 Visão Geral

O **zennit-OS** é um conjunto de scripts projetado para transformar uma instalação limpa do Fedora em um ambiente de desenvolvimento robusto, ágil e visualmente agradável. Ele foi desenhado especificamente para extrair o máximo de performance de notebooks com **AMD APU** e **SSD NVMe**, gerenciando desde a instalação de linguagens de programação até o tuning fino de kernel.

O projeto é composto por três módulos principais:
1. **`post-install.sh`**: Configuração de repositórios, interface, dotfiles e ferramentas de desenvolvimento.
2. **`optimize.sh`**: Tuning de performance (Kernel, ZRAM, I/O, boot time e energia).
3. **`runner.py`**: Um wrapper interativo em Python para orquestrar a execução segura dos scripts.

---

## 💻 Stack de Desenvolvimento

O setup instala e configura as seguintes tecnologias, focando no isolamento de ambientes e gerenciadores de versão:

* **Java:** JDK 21 (Default) e JDK 17 via `SDKMan`, com Maven e Gradle.
* **Python:** Gerenciado de forma ultra-rápida via `uv`.
* **Node.js:** Versão LTS via `fnm`, incluindo `pnpm`, `yarn` e `Bun`.
* **Rust:** Toolchain estável via `rustup` (com `rust-analyzer` e `clippy`).
* **Go & Ruby:** Instalação nativa / `rbenv`.
* **.NET 9:** SDK completo para C#.
* **Infra/DB:** Docker CE (com Compose) rodando sem `sudo`, DBeaver e Bruno (API Client).
* **Editor:** Neovim + integração com dotfiles gerenciados via GNU Stow.

---

## ⚙️ Otimizações do Sistema (Under the Hood)

O script `optimize.sh` aplica melhorias agressivas de performance, preservando a estabilidade da máquina:

* **CPU & Energia:** Ativação do `amd_pstate=active` (EPP), `powertop` auto-tune, `auto-cpufreq` e perfil `tuned` de economia.
* **Memória:** Configuração do ZRAM (zstd, 50% RAM), redução do `vm.swappiness` (10) e Transparent HugePage configurado para `madvise` (beneficiando diretamente a JVM).
* **Armazenamento:** Scheduler I/O configurado para `kyber` (ideal para NVMe) e montagem BTRFS com `noatime`, compressão `zstd:1` e `discard=async`.
* **Boot:** Desativação de serviços gargalo (como `NetworkManager-wait-online`), economizando de 5 a 10 segundos no tempo de boot, preservando a splash screen do Plymouth.

---

## 🎨 Interface e UI

O ambiente utiliza o GNOME, mas com uma roupagem totalmente personalizada:
* **Tema:** Fluent Blue Dark + Fluent Icons + Folder Color.
* **Fontes:** FiraCode Nerd Font e JetBrainsMono Nerd Font.
* **Terminal:** ZSH + Starship Prompt (linkado via repositório `Symos-dotfiles`).

---

## 🚀 Como Usar

### Pré-requisitos
* Fedora Workstation recém-instalado (atualizado ou não, o script cuida do `dnf upgrade`).
* Conexão ativa com a internet.
* **NÃO** execute os scripts logado como `root`. O sistema pedirá elevação de privilégios (`sudo`) quando estritamente necessário.

### Instalação

1. Clone este repositório para a sua máquina:
   ```bash
   git clone [https://github.com/seu-usuario/zennit-OS.git](https://github.com/seu-usuario/zennit-OS.git)
   cd zennit-OS

2. Dê permissão de execução ao orquestrador em Python:

```bash
chmod +x runner.py
Execute o menu interativo:
```
```bash
./runner.py
Escolha a opção desejada no menu (Pós-instalação, Otimização ou Ambos) e deixe a automação trabalhar!
```

📂 Estrutura de Arquivos
```Plaintext
zennit-OS/
├── post-install.sh      # Instalação de pacotes, repositórios, UI e Dev Stack
├── optimize.sh          # Tuning de sysctl, SSD, Boot e energia
└── runner.py            # CLI interativa para rodar os arquivos acima de forma segura
```

⚠️ Pós-execução (Próximos Passos Manuais)
Após a automação finalizar, algumas ações requerem atenção manual devido a autenticações ou extensões de navegador:

Reiniciar a sessão: Faça logout e login para que as variáveis de ambiente (Docker, SDKMan, fnm, cargo) entrem no seu PATH.

Cloud Drive: Rode rclone config para autenticar seu OneDrive.

Extensões GNOME: Acesse extensions.gnome.org e ative ferramentas como Dash to Dock, AppIndicator e GSConnect.

Tmux: Abra o terminal, digite tmux e pressione prefix + I para baixar os plugins via TPM.   
