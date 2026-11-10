#!/usr/bin/env python3
"""
build.py - PocketGroove Build Script
Packages the pocketgroove sources into pocketgroove/PocketGroove.love
"""
import os
import zipfile

def build():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    source_dir = os.path.join(script_dir, "pocketgroove")
    output_love = os.path.join(source_dir, "PocketGroove.love")

    files_to_pack = [
        "main.lua",
        "conf.lua",
        "controls.gptk",
        "src/config.lua",
        "src/input.lua",
        "src/looper.lua",
        "src/theory.lua",
        "src/synth/drums_bank.lua",
        "src/synth/init.lua",
        "src/synth/synths_bank.lua",
        "src/instruments/bass.lua",
        "src/instruments/drums.lua",
        "src/instruments/grain.lua",
        "src/instruments/harp.lua",
        "src/instruments/init.lua",
        "src/ui/chrome.lua",
    ]

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
    print(f"Successfully generated PocketGroove.love ({os.path.getsize(output_love)} bytes)")

if __name__ == "__main__":
    build()
