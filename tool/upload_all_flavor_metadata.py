#!/usr/bin/env python3
"""
Uploads store metadata (Titles, Short Descriptions, Full Descriptions in 7 languages)
and store images (featureGraphic.png 1024x500 and icon.png 512x512) for all 8 new flavors
to Google Play Console using Fastlane Supply.
Does NOT upload any APK or AAB builds.
"""

import os
import subprocess
import sys

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

def main():
    print("=" * 65)
    print("Uploading Metadata to Google Play for 8 New Flavors")
    print("=" * 65)

    success_list = []
    fail_list = []

    for flavor, package in FLAVORS:
        meta_path = os.path.join(ROOT, "fastlane", "metadata", flavor, "android")
        print(f"\n>>> Uploading metadata for '{flavor}' ({package})...")

        cmd = [
            "fastlane", "supply",
            "--package_name", package,
            "--json_key", KEY_PATH,
            "--metadata_path", meta_path,
            "--skip_upload_apk", "true",
            "--skip_upload_aab", "true",
            "--skip_upload_changelogs", "true",
            "--skip_upload_screenshots", "true",
            "--skip_upload_images", "false",
            "--changes_not_sent_for_review", "true",
        ]

        try:
            res = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, check=True)
            print(f"[SUCCESS] {flavor} ({package}) uploaded successfully!")
            success_list.append(flavor)
        except subprocess.CalledProcessError as e:
            print(f"[ERROR] Failed uploading for {flavor} ({package}):")
            print(e.stderr or e.stdout)
            fail_list.append((flavor, e.stderr or e.stdout))

    print("\n" + "=" * 65)
    print(f"Summary: {len(success_list)} succeeded, {len(fail_list)} failed.")
    print("=" * 65)
    if success_list:
        print("Succeeded:", ", ".join(success_list))
    if fail_list:
        print("Failed:")
        for flv, err in fail_list:
            print(f" - {flv}: {err[:160]}...")

if __name__ == "__main__":
    main()

