import subprocess
import logging
import shlex
from typing import Tuple, Optional

logger = logging.getLogger("security_scanner")

def run_command(command: str, timeout: Optional[int] = None) -> Tuple[int, str, str]:
    """
    Run a shell command and return exit code, stdout, stderr.
    Safe wrapper around subprocess.run.
    """
    try:
        # We use shell=True for complex pipes, but safer to avoid if possible.
        # For this migration, to keep it simple with existing bash logic compatibility,
        # we might need shell=True or careful splitting.
        # Let's try to avoid shell=True where possible, but for 'grep | awk' chains it's needed unless we do it in Python.
        # Ideally, we move the processing to Python.
        
        # If the command contains pipes, use shell=True. Otherwise split.
        use_shell = "|" in command or ">" in command
        
        cmd_args = command if use_shell else shlex.split(command)
        
        result = subprocess.run(
            cmd_args,
            capture_output=True,
            text=True,
            timeout=timeout,
            shell=use_shell
        )
        return result.returncode, result.stdout.strip(), result.stderr.strip()
    except subprocess.TimeoutExpired:
        logger.error(f"Command timed out: {command}")
        return 124, "", "Timeout"
    except Exception as e:
        logger.error(f"Command failed: {command} - {e}")
        return 1, "", str(e)

def setup_logging(log_file: str):
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler()
        ]
    )
