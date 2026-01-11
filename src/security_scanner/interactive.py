import typer
import shutil
from rich.console import Console
from rich.table import Table
from rich.prompt import Prompt, Confirm
from rich.panel import Panel
from typing import Optional

from security_scanner.modules import tools
from security_scanner.modules.installer import Installer
from security_scanner.modules import network
from security_scanner.utils import run_command

console = Console()
installer = Installer()

class SessionState:
    target: str = "127.0.0.1"

state = SessionState()

def clear_screen():
    print("\033c", end="")

def show_header():
    clear_screen()
    console.print(Panel.fit(
        f"[bold blue]Security Scanner Interactive Mode[/bold blue]\n"
        f"Target: [bold yellow]{state.target}[/bold yellow]",
        border_style="blue"
    ))

def manage_tools_menu():
    while True:
        show_header()
        
        # Assess tools
        tool_result = tools.assess_tools()
        
        table = Table(title="Available Tools")
        table.add_column("Tool", style="cyan")
        table.add_column("Category", style="magenta")
        table.add_column("Status", style="green")
        table.add_column("Package", style="dim")
        
        tools_list = tool_result.tools
        
        for idx, tool in enumerate(tools_list):
            status_style = "green" if tool.status == "Installed" else "red"
            pkg = tools.get_package_name(tool.name)
            table.add_row(
                f"{idx + 1}. {tool.name}", 
                tool.category, 
                f"[{status_style}]{tool.status}[/{status_style}]",
                pkg
            )
            
        console.print(table)
        console.print("\n[bold]Actions:[/bold]")
        console.print("  [cyan]<number>[/cyan] : Install/Uninstall Tool")
        console.print("  [cyan]b[/cyan]        : Back to Main Menu")
        
        choice = Prompt.ask("\nSelect option")
        
        if choice.lower() == 'b':
            break
            
        try:
            idx = int(choice) - 1
            if 0 <= idx < len(tools_list):
                tool = tools_list[idx]
                if tool.status == "Installed":
                    if Confirm.ask(f"Uninstall {tool.name}?"):
                        installer.uninstall(tool.name)
                else:
                    if Confirm.ask(f"Install {tool.name}?"):
                        installer.install(tool.name)
                Prompt.ask("Press Enter to continue...")
        except ValueError:
            pass

def operations_menu():
    while True:
        show_header()
        console.print("[bold]Operations:[/bold]")
        console.print("1. Run Nmap Scan (Quick)")
        console.print("2. Run Nmap Scan (Full)")
        console.print("3. Run Nikto Web Scan")
        console.print("4. Ping Target")
        console.print("b. Back")
        
        choice = Prompt.ask("\nSelect Operation")
        
        if choice == '1':
            cmd = f"nmap -F {state.target}"
            console.print(f"[dim]Running: {cmd}[/dim]")
            code, out, err = run_command(cmd)
            console.print(out)
            Prompt.ask("Press Enter...")
            
        elif choice == '2':
            cmd = f"nmap -A -T4 {state.target}"
            console.print(f"[dim]Running: {cmd}[/dim]")
            code, out, err = run_command(cmd)
            console.print(out)
            Prompt.ask("Press Enter...")
            
        elif choice == '3':
            if not shutil.which("nikto"):
                console.print("[red]Nikto is not installed![/red]")
            else:
                cmd = f"nikto -h {state.target}"
                console.print(f"[dim]Running: {cmd}[/dim]")
                # Nikto can take a while, stream output?
                # For now just run wait
                with console.status("Running Nikto..."):
                    code, out, err = run_command(cmd, timeout=300)
                console.print(out)
            Prompt.ask("Press Enter...")
            
        elif choice == '4':
            cmd = f"ping -c 4 {state.target}"
            code, out, err = run_command(cmd)
            console.print(out)
            Prompt.ask("Press Enter...")
            
        elif choice.lower() == 'b':
            break

def main_menu():
    while True:
        show_header()
        console.print("[bold]Main Menu:[/bold]")
        console.print("1. [cyan]Manage Tools[/cyan] (Install/Uninstall)")
        console.print("2. [cyan]Set Target[/cyan]")
        console.print("3. [cyan]Run Operations[/cyan]")
        console.print("4. [red]Exit[/red]")
        
        choice = Prompt.ask("\nSelect option")
        
        if choice == '1':
            manage_tools_menu()
        elif choice == '2':
            new_target = Prompt.ask("Enter Target IP/Hostname", default=state.target)
            state.target = new_target
        elif choice == '3':
            operations_menu()
        elif choice == '4':
            console.print("Goodbye!")
            break
