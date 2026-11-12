"""Fetch official, project-local runtime and open-source fonts. No system install."""
from pathlib import Path
import requests
import zipfile
import concurrent.futures

ROOT = Path(__file__).resolve().parents[1]

def fetch(url, dest):
    dest = ROOT / dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.stat().st_size > 1000:
        print(f"Already present: {dest.name}", flush=True)
        return dest
    print(f"Downloading {dest.name}", flush=True)
    with requests.get(url, timeout=(20, 180), stream=True) as response:
        response.raise_for_status()
        with dest.open("wb") as out:
            for chunk in response.iter_content(1024 * 1024):
                out.write(chunk)
    print(f"Saved {dest.name}: {dest.stat().st_size:,} bytes", flush=True)
    return dest

jobs = [
    ("https://github.com/godotengine/godot-builds/releases/download/4.5.2-stable/Godot_v4.5.2-stable_win64.exe.zip", ".tools/godot.zip"),
    ("https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf", "assets/fonts/NotoSansSC.ttf"),
    ("https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/OFL.txt", "assets/fonts/NotoSansSC-OFL.txt"),
    ("https://raw.githubusercontent.com/google/fonts/main/ofl/pressstart2p/PressStart2P-Regular.ttf", "assets/fonts/PressStart2P.ttf"),
    ("https://raw.githubusercontent.com/google/fonts/main/ofl/pressstart2p/OFL.txt", "assets/fonts/PressStart2P-OFL.txt"),
]
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
    for result in pool.map(lambda job: fetch(*job), jobs):
        pass
with zipfile.ZipFile(ROOT / ".tools/godot.zip") as archive:
    archive.extractall(ROOT / ".tools/godot")
print("Runtime and fonts ready.", flush=True)
