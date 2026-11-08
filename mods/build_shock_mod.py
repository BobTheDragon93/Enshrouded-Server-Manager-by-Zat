"""Build a deterministic ESM-Z-compatible EML upload ZIP; no game files included."""
from pathlib import Path
import hashlib
import json
import zipfile
import argparse

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "mods" / "zat-shock-tuning"


def build(active_config=None):
    manifest = json.loads((SOURCE / "mod.json").read_text(encoding="utf-8"))
    destination = ROOT / "dist" / "mods" / f"Bob-Shock-Tuning-v{manifest['version']}.zip"
    destination.parent.mkdir(parents=True, exist_ok=True)
    files = ["mod.json", "src/mod.lua", "src/arrow_chain.lua", "src/spell_chain.lua",
             "src/impact_builder.lua", "src/chain_propagation.lua", "src/fire_arrows.lua", "src/ground_fire.lua", "src/config.lua",
             "src/fire_effects.lua", "src/fire_effect_catalog.lua", "src/fire_effect_preview.lua",
             "README.txt", "VALIDATION.txt", "LICENSE.txt"]
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name in files:
            info = zipfile.ZipInfo(f"{manifest['id']}/{name}", date_time=(2026, 10, 21, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            source = active_config if active_config is not None and name == "src/config.lua" else SOURCE / name
            archive.writestr(info, source.read_bytes())
        info = zipfile.ZipInfo(f"{manifest['id']}/src/config.defaults.lua", date_time=(2026, 10, 21, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        archive.writestr(info, (SOURCE / "src/config.lua").read_bytes())
    checksum = hashlib.sha256(destination.read_bytes()).hexdigest()
    destination.with_suffix(".zip.sha256").write_text(f"{checksum}  {destination.name}\n", encoding="ascii")
    print(destination)
    return destination


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--active-config", type=Path)
    build(parser.parse_args().active_config)
