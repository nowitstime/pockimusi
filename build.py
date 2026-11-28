#!/usr/bin/env python3
"""
build.py - Pockimusi Build Script
Packages the pockimusi sources into pockimusi/Pockimusi.love
"""
import os
import zipfile

# Top-level files packed besides every .lua under src/ and everything in assets/
ROOT_FILES = ["main.lua", "conf.lua", "controls.gptk"]
ASSET_DIR = "assets"   # fonts (with their licences)


def collect_files(source_dir):
    """Every top-level runtime file, every .lua file under src/ and every file under assets/, sorted."""
    src_files = []
    for dirpath, _, filenames in os.walk(os.path.join(source_dir, "src")):
        for name in filenames:
            if name.endswith(".lua"):
                full = os.path.join(dirpath, name)
                src_files.append(os.path.relpath(full, source_dir).replace(os.sep, "/"))
    for dirpath, _, filenames in os.walk(os.path.join(source_dir, ASSET_DIR)):
        for name in filenames:
            full = os.path.join(dirpath, name)
            src_files.append(os.path.relpath(full, source_dir).replace(os.sep, "/"))
    return ROOT_FILES + sorted(src_files)


def build():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    source_dir = os.path.join(script_dir, "pockimusi")
    output_love = os.path.join(source_dir, "Pockimusi.love")

    files_to_pack = collect_files(source_dir)

    print(f"Building {output_love}...")
    temp_zip = output_love + ".tmp"
    with zipfile.ZipFile(temp_zip, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for rel_path in files_to_pack:
            full_path = os.path.join(source_dir, rel_path)
            if not os.path.exists(full_path):
                raise FileNotFoundError(f"Missing file: {full_path}")
            zf.write(full_path, arcname=rel_path)
            print(f"  + {rel_path} ({os.path.getsize(full_path)} bytes)")

    os.replace(temp_zip, output_love)
    print(f"Successfully generated Pockimusi.love ({os.path.getsize(output_love)} bytes)")

if __name__ == "__main__":
    build()
