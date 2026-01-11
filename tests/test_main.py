from typer.testing import CliRunner
from security_scanner.main import app

runner = CliRunner()

def test_help():
    result = runner.invoke(app, ["--help"])
    assert result.exit_code == 0
    assert "Run a full security scan" in result.stdout
