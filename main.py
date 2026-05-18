#!/usr/bin/env python3
import os
import sys
import subprocess

# Definição de cores ANSI para um visual moderno
CLEAR = "\033[H\033[2J"
BLUE = "\033[1;34m"
GREEN = "\033[1;32m"
YELLOW = "\033[1;33m"
RED = "\033[1;31m"
CYAN = "\033[1;36m"
MAGENTA = "\033[1;35m"
RESET = "\033[0m"
BOLD = "\033[1m"

def print_banner():
    """Exibe o cabeçalho personalizado do gerenciador."""
    print(f"{CYAN}╔══════════════════════════════════════════════════╗{RESET}")
    print(f"{CYAN}║        Fedora Automation Wrapper — Lucas         ║{RESET}")
    print(f"{CYAN}║               Setup & Performance                ║{RESET}")
    print(f"{CYAN}╚══════════════════════════════════════════════════╝{RESET}\n")

def run_script(script_name):
    """Garante permissão de execução e roda o script herdando o TTY."""
    if not os.path.exists(script_name):
        print(f"{RED}✗ Erro: O arquivo '{script_name}' não foi encontrado no diretório atual!{RESET}")
        return False

    print(f"{BLUE}➔ Preparando ambiente para: {YELLOW}{script_name}{RESET}")
    
    # Garante que o script possui permissão de execução (chmod +x)
    try:
        os.chmod(script_name, 0o755)
        print(f"{GREEN}✓ Permissões de execução verificadas.{RESET}")
    except Exception as e:
        print(f"{YELLOW}⚠ Aviso: Falha ao ajustar permissões via Python ({e}). Tentando rodar mesmo assim...{RESET}")

    print(f"{MAGENTA}🚀 Iniciando execução...{RESET}\n")
    
    try:
        # Executa herdando o stdout/stdin para manter prompts do sudo funcionais
        result = subprocess.run([f"./{script_name}"], check=True)
        print(f"\n{GREEN}✓ Script '{script_name}' finalizado com sucesso!{RESET}")
        return True
    except subprocess.CalledProcessError:
        print(f"\n{RED}✗ O script '{script_name}' retornou um erro durante a execução.{RESET}")
        return False
    except KeyboardInterrupt:
        print(f"\n{YELLOW}⚠ Execução interrompida pelo usuário (Ctrl+C).{RESET}")
        return False

def main():
    # Impede execução direta como Root (assim como os scripts internos exigem)
    if os.getuid() == 0:
        print(f"{RED}✗ Não rode o wrapper como root/sudo.{RESET}")
        print(f"{YELLOW}Os scripts internos gerenciam o pedido de elevação de privilégios quando necessário.{RESET}")
        sys.exit(1)

    while True:
        print_banner()
        print(f"{BOLD}Selecione a automação que deseja executar:{RESET}\n")
        print(f"  {CYAN}[1]{RESET} Rodar Pós-Instalação Completa ({YELLOW}post-install.sh{RESET})")
        print(f"  {CYAN}[2]{RESET} Rodar Otimizações do Sistema ({YELLOW}optimize.sh{RESET})")
        print(f"  {CYAN}[3]{RESET} Rodar Ambos ({YELLOW}Post-Install ➔ Otimização{RESET})")
        print(f"  {CYAN}[4]{RESET} Sair do Programa\n")

        try:
            choice = input(f"{BOLD}Escolha uma opção (1-4): {RESET}").strip()
            print("") # Linha em branco para respiro visual
            
            if choice == '1':
                run_script("post-install.sh")
            elif choice == '2':
                run_script("optimize.sh")
            elif choice == '3':
                print(f"{BLUE}=== ETAPA 1: Pós-Instalação ==={RESET}")
                if run_script("post-install.sh"):
                    print(f"\n{BLUE}=== ETAPA 2: Otimização ==={RESET}")
                    run_script("optimize.sh")
            elif choice == '4':
                print(f"{GREEN}Saindo. Bom código, Lucas! ☕{RESET}")
                break
            else:
                print(f"{RED}Opção inválida! Escolha um número entre 1 e 4.{RESET}")
                
        except (KeyboardInterrupt, EOFError):
            print(f"\n\n{GREEN}Saindo. Automação encerrada.{RESET}")
            break

        print(f"\n{cyan_dim=}\033[2mPressione Enter para voltar ao menu principal...{RESET}")
        input()
        print(CLEAR, end="")

if __name__ == "__main__":
    main()