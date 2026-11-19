"""Build the portable x64 release using the matching official Godot template.

Only the required ZIP member is fetched with validated HTTP byte ranges.
zipfile verifies the member CRC; the 1.35 GB multi-platform archive is not saved.
"""
from __future__ import annotations

import io
import json
from pathlib import Path
import tempfile
import urllib.request
import zipfile

from check_startup import ENGINE, ROOT, check_project_startup, check_title, run_godot


VERSION = "4.5.2-stable"
URL = (
    "https://github.com/godotengine/godot-builds/releases/download/"
    f"{VERSION}/Godot_v{VERSION}_export_templates.tpz"
)


class RemoteZip(io.RawIOBase):
    def __init__(self, url: str, size: int) -> None:
        self.url, self.size, self.pos = url, size, 0
        self.cache_start = -1
        self.cache = b""

    def seekable(self) -> bool:
        return True

    def tell(self) -> int:
        return self.pos

    def seek(self, offset: int, whence: int = 0) -> int:
        if whence == 0:
            self.pos = offset
        elif whence == 1:
            self.pos += offset
        elif whence == 2:
            self.pos = self.size + offset
        return self.pos

    def read(self, count: int = -1) -> bytes:
        count = min(self.size - self.pos, count if count >= 0 else self.size)
        if count <= 0:
            return b""
        end = self.pos + count
        if self.cache_start <= self.pos and end <= self.cache_start + len(self.cache):
            data = self.cache[self.pos - self.cache_start : end - self.cache_start]
            self.pos = end
            return data
        fetch_end = min(self.size, self.pos + max(count, 65536))
        request = urllib.request.Request(self.url, headers={"Range": f"bytes={self.pos}-{fetch_end - 1}"})
        expected = f"bytes {self.pos}-{fetch_end - 1}/{self.size}"
        with urllib.request.urlopen(request, timeout=180) as response:
            if response.status != 206 or response.headers.get("Content-Range") != expected:
                raise RuntimeError("Server did not return the requested byte range")
            content = response.read()
        if len(content) != fetch_end - self.pos:
            raise RuntimeError("Incomplete template download")
        self.cache_start, self.cache = self.pos, content
        self.pos = end
        return self.cache[:count]


def fetch_template() -> Path:
    target = ROOT / ".tools/export_templates/windows_release_x86_64.exe"
    if target.exists() and target.stat().st_size > 1_000_000:
        return target
    with urllib.request.urlopen(
        "https://api.github.com/repos/godotengine/godot-builds/releases/tags/" + VERSION,
        timeout=30,
    ) as release:
        metadata = json.load(release)
    asset = next(a for a in metadata["assets"] if a["browser_download_url"] == URL)
    print("Downloading official Windows x64 release template…", flush=True)
    with zipfile.ZipFile(RemoteZip(URL, asset["size"])) as archive:
        member = next(n for n in archive.namelist() if n.endswith("/windows_release_x86_64.exe"))
        data = archive.read(member)
        if data[:2] != b"MZ":
            raise RuntimeError("Invalid Windows executable template")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    print(f"Template verified: {len(data):,} bytes", flush=True)
    return target


def write_bundle(exe: Path, bundle: Path) -> None:
    with zipfile.ZipFile(bundle, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.write(exe, exe.name)
        archive.write(ROOT / "README.md", "README.md")
        for document in ("sandbox-mode.md", "sandbox-self-check.md", "sandbox-adventure.md", "sandbox-priest-imagegen-prompt.txt"):
            archive.write(ROOT / "docs" / document, "docs/" + document)
        for license_path in (ROOT / "assets/fonts").glob("*-OFL.txt"):
            archive.write(license_path, "licenses/" + license_path.name)
        archive.write(ROOT / "docs/licenses/Godot-MIT.txt", "licenses/Godot-MIT.txt")


def main() -> None:
    check_project_startup()
    fetch_template()
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    exe = build / "windows-v0.6.1/毅川救我.exe"
    bundle = build / "毅川救我-v0.6.1-地牢与沙盒-Windows-x64.zip"
    with tempfile.TemporaryDirectory(prefix=".windows-build-", dir=build) as staging:
        staged_exe = Path(staging) / exe.name
        run_godot(
            ENGINE, ROOT / ".tools/export.log",
            "--path", str(ROOT), "--export-release", "Windows Desktop", str(staged_exe),
        )
        check_title(staged_exe, ROOT / ".tools/check-export-startup.log")
        staged_bundle = Path(staging) / bundle.name
        write_bundle(staged_exe, staged_bundle)
        exe.parent.mkdir(exist_ok=True)
        staged_exe.replace(exe)
        staged_bundle.replace(bundle)
    print(f"Built: {exe} ({exe.stat().st_size / 1024 / 1024:.1f} MiB)", flush=True)
    print(f"Packaged: {bundle}", flush=True)


if __name__ == "__main__":
    main()
