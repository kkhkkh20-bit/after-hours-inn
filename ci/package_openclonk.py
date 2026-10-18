from pathlib import Path
import hashlib, shutil, subprocess, urllib.request
root = Path(__file__).resolve().parent.parent
build = root / "build"
build.mkdir(exist_ok=True)
installer = build / "openclonk-8.1-x64.exe"
url = "https://www.openclonk.org/builds/release/8.1/openclonk-8.1-x64.exe"
if not installer.exists():
    urllib.request.urlretrieve(url, installer)
expected = "cb595b8b7495b9c68cb21db01c852ff3c12f20de51d72dfc99009aa1093f0b01"
assert hashlib.sha256(installer.read_bytes()).hexdigest() == expected, "Upstream installer changed"
out = build / "openclonk-windows"
subprocess.run([shutil.which("7z"), "x", "-y", f"-o{out}", str(installer)], check=True)
# Installer-only plugins/uninstaller are not part of the portable game.
shutil.rmtree(out / "$PLUGINSDIR", ignore_errors=True)
(out / "uninst.exe").unlink(missing_ok=True)
source = root / "experiments/openclonk"
for item in source.iterdir():
    if item.suffix == ".zip":
        continue
    dest = out / item.name
    if item.is_dir():
        shutil.copytree(item, dest, dirs_exist_ok=True)
    else:
        shutil.copy2(item, dest)
for name in ["openclonk.exe", "Objects.ocd", "System.ocg", "Material.ocg", "Graphics.ocg", "START-INN.cmd", "AfterHours.ocs/Script.c", "COPYING", "LGPL.txt"]:
    assert (out / name).is_file(), f"Missing {name}"
print("Complete original Windows game + inn scenario prepared:", out)
