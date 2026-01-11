import platform
import shutil
from security_scanner.utils import run_command, logger
from security_scanner.modules.tools import get_package_name

class Installer:
    def __init__(self):
        self.os = platform.system()
        self.pkg_manager = self._detect_package_manager()
        
    def _detect_package_manager(self):
        if self.os == "Darwin":
            if shutil.which("brew"):
                return "brew"
        elif self.os == "Linux":
            if shutil.which("apt-get"):
                return "apt"
            elif shutil.which("yum"):
                return "yum"
            elif shutil.which("dnf"):
                return "dnf"
            elif shutil.which("pacman"):
                return "pacman"
        return None

    def install(self, tool_name: str) -> bool:
        package = get_package_name(tool_name)
        if not self.pkg_manager:
            logger.error("No supported package manager found.")
            return False
            
        logger.info(f"Installing {package} via {self.pkg_manager}...")
        
        cmd = ""
        if self.pkg_manager == "brew":
            cmd = f"brew install {package}"
        elif self.pkg_manager == "apt":
            cmd = f"sudo apt-get install -y {package}"
        elif self.pkg_manager == "yum":
            cmd = f"sudo yum install -y {package}"
        elif self.pkg_manager == "dnf":
            cmd = f"sudo dnf install -y {package}"
        elif self.pkg_manager == "pacman":
            cmd = f"sudo pacman -S --noconfirm {package}"
            
        code, out, err = run_command(cmd)
        if code == 0:
            logger.info(f"Successfully installed {package}")
            return True
        else:
            logger.error(f"Failed to install {package}: {err}")
            return False

    def uninstall(self, tool_name: str) -> bool:
        package = get_package_name(tool_name)
        if not self.pkg_manager:
            logger.error("No supported package manager found.")
            return False

        logger.info(f"Uninstalling {package} via {self.pkg_manager}...")

        cmd = ""
        if self.pkg_manager == "brew":
            cmd = f"brew uninstall {package}"
        elif self.pkg_manager == "apt":
            cmd = f"sudo apt-get remove -y {package}"
        elif self.pkg_manager == "yum":
            cmd = f"sudo yum remove -y {package}"
        elif self.pkg_manager == "dnf":
            cmd = f"sudo dnf remove -y {package}"
        elif self.pkg_manager == "pacman":
            cmd = f"sudo pacman -Rs --noconfirm {package}"

        code, out, err = run_command(cmd)
        if code == 0:
            logger.info(f"Successfully uninstalled {package}")
            return True
        else:
            logger.error(f"Failed to uninstall {package}: {err}")
            return False
