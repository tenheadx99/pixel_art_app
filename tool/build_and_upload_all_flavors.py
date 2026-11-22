#!/usr/bin/env python3
"""
Builds release AABs for all 8 new flavors and uploads them to Google Play Production track.
Flavors: brick, bead, knit, mosaic, glow, sticker, quilt, voxel.
"""

import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_PATH = os.path.join(ROOT, "play-store-key.json")

FLAVORS = [
    ("brick", "com.tenhead.brickart"),
    ("bead", "com.tenhead.beadart"),
    ("knit", "com.tenhead.knitart"),
    ("mosaic", "com.tenhead.mosaicart"),
    ("glow", "com.tenhead.glowart"),
    ("sticker", "com.tenhead.stickerart"),
    ("quilt", "com.tenhead.quiltart"),
    ("voxel", "com.tenhead.voxelart"),
]

def build_flavor(flavor):
    aab_path = os.path.join(ROOT, "build", "app", "outputs", "bundle", f"{flavor}Release", f"app-{flavor}-release.aab")
    if os.path.exists(aab_path) and os.path.getsize(aab_path) > 10 * 1024 * 1024:
        print(f"[*] Bundle already exists for {flavor}: {aab_path} ({os.path.getsize(aab_path)/(1024*1024):.1f}MB)")
        return aab_path

    print(f"\n=======================================================")
    print(f"[BUILD] Building release AAB for flavor: {flavor}")
    print(f"=======================================================")
    cmd = [
        "flutter", "build", "appbundle",
        "--release",
        "--flavor", flavor,
        "-t", f"lib/main_{flavor}.dart",
        f"--dart-define=FLAVOR={flavor}"
    ]
    t0 = time.time()
    res = subprocess.run(cmd, cwd=ROOT)
    if res.returncode != 0:
        raise RuntimeError(f"Build failed for flavor {flavor} with code {res.returncode}")
    print(f"[BUILD SUCCESS] Flavor {flavor} built in {time.time() - t0:.1f}s")
    if not os.path.exists(aab_path):
        raise RuntimeError(f"Expected bundle not found at {aab_path}")
    return aab_path

def upload_flavor(flavor, package, aab_path):
    print(f"\n=======================================================")
    print(f"[UPLOAD] Uploading {flavor} ({package}) to Production track (draft release)...")
    print(f"=======================================================")
    cmd = [
        "fastlane", "supply",
        "--package_name", package,
        "--json_key", KEY_PATH,
        "--aab", aab_path,
        "--track", "production",
        "--release_status", "draft",
        "--skip_upload_metadata", "true",
        "--skip_upload_images", "true",
        "--skip_upload_screenshots", "true",
        "--skip_upload_changelogs", "true",
        "--changes_not_sent_for_review", "true",
    ]
    res = subprocess.run(cmd, cwd=ROOT)
    if res.returncode != 0:
        print(f"[WARN] Failed with draft status, attempting completed status...")
        cmd_completed = [c if c != "draft" else "completed" for c in cmd]
        res_comp = subprocess.run(cmd_completed, cwd=ROOT)
        if res_comp.returncode != 0:
            raise RuntimeError(f"Upload failed for {flavor} ({package})")
    print(f"[UPLOAD SUCCESS] {flavor} ({package}) successfully uploaded to Production track!")

def main():
    target_flavors = sys.argv[1:] if len(sys.argv) > 1 else [f[0] for f in FLAVORS]
    print(f"Target flavors to build & upload: {target_flavors}")

    for flavor, package in FLAVORS:
        if flavor not in target_flavors:
            continue
        try:
            aab_path = build_flavor(flavor)
            upload_flavor(flavor, package, aab_path)
        except Exception as e:
            print(f"[ERROR] Error processing {flavor}: {e}")
            sys.exit(1)

    print("\n" + "=" * 65)
    print("ALL TARGET FLAVORS BUILT AND UPLOADED SUCCESSFULLY!")
    print("=" * 65)

if __name__ == "__main__":
    main()
