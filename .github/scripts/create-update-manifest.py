#!/usr/bin/env python3
"""Read actual APK metadata (including Flutter ABI version offsets) for updates."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def apk_metadata(apk, abi, aapt):
    badging = subprocess.check_output([aapt, "dump", "badging", str(apk)], text=True)
    package = re.search(r"^package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", badging, re.M)
    sdk = re.search(r"^sdkVersion:'(\d+)'", badging, re.M)
    native = re.search(r"^native-code:(.+)$", badging, re.M)
    if not package or not sdk or not native or re.findall(r"'([^']+)'", native[1]) != [abi]:
        raise ValueError(f"Missing or unexpected APK metadata: {apk}")
    if package[1] != "com.example.jiongtu":
        raise ValueError(f"Unexpected application ID: {package[1]}")
    with apk.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    return {
        "name": apk.name,
        "abi": abi,
        "versionName": package[3],
        "versionCode": int(package[2]),
        "minSdk": int(sdk[1]),
        "size": apk.stat().st_size,
        "sha256": digest,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aapt", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--directory", type=Path, default=Path("release"))
    args = parser.parse_args()
    assets = [
        apk_metadata(args.directory / f"jiongtu-{abi}.apk", abi, args.aapt)
        for abi in ("armeabi-v7a", "arm64-v8a", "x86_64")
    ]
    manifest = {
        "schemaVersion": 1,
        "packageName": "com.example.jiongtu",
        "tag": args.tag,
        "assets": assets,
    }
    (args.directory / "update.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
