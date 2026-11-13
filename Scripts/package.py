#!/usr/bin/env python3
"""Package Nally.app into a distributable macOS zip archive with SHA-256 checksum."""

from __future__ import annotations

import argparse
import hashlib
import os
import plistlib
import subprocess
import sys
from pathlib import Path


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def package_bundle(bundle_path: Path, output_dir: Path) -> Path:
    info_plist_path = bundle_path / "Contents" / "Info.plist"
    if not info_plist_path.is_file():
        raise FileNotFoundError(f"Missing Info.plist at {info_plist_path}")

    with info_plist_path.open("rb") as fh:
        plist = plistlib.load(fh)

    bundle_name = plist.get("CFBundleName") or bundle_path.stem
    short_version = plist.get("CFBundleShortVersionString") or plist.get("CFBundleVersion") or "dev"

    output_dir.mkdir(parents=True, exist_ok=True)
    archive_path = output_dir / f"{bundle_name}-{short_version}-arm64.zip"
    if archive_path.exists():
        archive_path.unlink()

    print(f"[PACK] Archiving {bundle_path.name} -> {archive_path} ...")
    subprocess.run(
        [
            "/usr/bin/ditto",
            "-c",
            "-k",
            "--sequesterRsrc",
            "--keepParent",
            str(bundle_path),
            str(archive_path),
        ],
        check=True,
    )

    checksum = sha256_file(archive_path)
    checksum_path = archive_path.with_suffix(".zip.sha256")
    checksum_path.write_text(f"{checksum}  {archive_path.name}\n", encoding="utf-8")

    size_bytes = archive_path.stat().st_size
    print(f"[PACK] Size:   {size_bytes:,} bytes")
    print(f"[PACK] SHA256: {checksum}")
    print(f"[PACK] Done! Artifacts written to {output_dir}")
    return archive_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Package Nally.app for macOS distribution.")
    parser.add_argument("bundle", type=Path, help="Path to built Nally.app bundle")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path.cwd() / "build" / "dist",
        help="Directory for generated zip and checksum (default: ./build/dist)",
    )
    args = parser.parse_args()

    bundle_path = args.bundle.resolve()
    if not bundle_path.is_dir():
        print(f"Error: bundle not found at {bundle_path}", file=sys.stderr)
        return 1

    package_bundle(bundle_path, args.output_dir.resolve())
    return 0


if __name__ == "__main__":
    os.umask(0o022)
    sys.exit(main())
