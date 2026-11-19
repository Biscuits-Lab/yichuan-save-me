"""Import the project and check startup through Godot's normal game entry."""
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / ".tools/godot/Godot_v4.5.2-stable_win64_console.exe"
TITLE_READY = "STARTUP CHECK: title initialized"


def run_godot(executable: Path, log: Path, *args: str, timeout: int = 180) -> list[str]:
    log.unlink(missing_ok=True)
    try:
        subprocess.run(
            [str(executable), "--headless", "--log-file", str(log), *args],
            cwd=executable.parent,
            stdout=subprocess.DEVNULL,
            timeout=timeout,
            check=True,
        )
    except (OSError, subprocess.SubprocessError) as error:
        raise RuntimeError(f"Godot failed. Log: {log}") from error
    if not log.is_file():
        raise RuntimeError(f"Godot did not write its log: {log}")
    lines = log.read_text(encoding="utf-8", errors="replace").splitlines()
    # Godot can exit successfully after reporting a resource or script error.
    for line in lines:
        if line.startswith(("ERROR:", "SCRIPT ERROR:", "SHADER ERROR:")):
            raise RuntimeError(f"{line}\nLog: {log}")
    return lines


def check_title(executable: Path, log: Path, *args: str) -> None:
    lines = run_godot(executable, log, *args, "--quit-after", "30", "--", "--check-startup", timeout=60)
    if TITLE_READY not in lines:
        raise RuntimeError(f"The main menu did not initialize. Log: {log}")
    print(f"Main menu initialized: {log.name}", flush=True)


def check_project_startup() -> None:
    run_godot(ENGINE, ROOT / ".tools/check-import.log", "--path", str(ROOT), "--import")
    check_title(ENGINE, ROOT / ".tools/check-source-startup.log", "--path", str(ROOT))


if __name__ == "__main__":
    check_project_startup()
