"""Export the single-threaded browser build with the matching Godot template."""

import argparse
import io
from pathlib import Path
import shutil
import tempfile
import urllib.request
import zipfile

from build_windows import RemoteZip, URL
from check_startup import ENGINE, ROOT, run_godot


def fetch_template() -> None:
    target = ROOT / ".tools/export_templates/web_nothreads_release.zip"
    if zipfile.is_zipfile(target):
        return
    request = urllib.request.Request(URL, method="HEAD")
    with urllib.request.urlopen(request, timeout=30) as response:
        archive_size = int(response.headers["Content-Length"])
    print("Downloading the official single-threaded Web template…", flush=True)
    with zipfile.ZipFile(RemoteZip(URL, archive_size)) as archive:
        data = archive.read("templates/" + target.name)
    with zipfile.ZipFile(io.BytesIO(data)) as template:
        if template.testzip() is not None:
            raise RuntimeError("The Web template contains a corrupt file")
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=target.parent, prefix="web-template-") as staging:
        staged = Path(staging) / target.name
        staged.write_bytes(data)
        staged.replace(target)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, default=ENGINE)
    engine = parser.parse_args().godot.resolve()
    if not engine.is_file():
        parser.error(f"Godot executable not found: {engine}")
    fetch_template()
    output = ROOT / "build/web"
    output.mkdir(parents=True, exist_ok=True)
    run_godot(engine, ROOT / ".tools/web-import.log", "--path", str(ROOT), "--import")
    run_godot(
        engine, ROOT / ".tools/web-export.log",
        "--path", str(ROOT), "--export-release", "Web", str(output / "index.html"),
    )
    for suffix in ("html", "js", "wasm", "pck"):
        exported = output / ("index." + suffix)
        if not exported.is_file() or not exported.stat().st_size:
            raise RuntimeError(f"Missing Web export file: {exported}")
    licenses = output / "licenses"
    licenses.mkdir(exist_ok=True)
    shutil.copyfile(ROOT / "docs/licenses/Godot-MIT.txt", licenses / "Godot-MIT.txt")
    for font_license in (ROOT / "assets/fonts").glob("*-OFL.txt"):
        shutil.copyfile(font_license, licenses / font_license.name)
    print(f"Built: {output}", flush=True)


if __name__ == "__main__":
    main()
