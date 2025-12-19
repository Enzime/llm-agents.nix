#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for claude-desktop package.

This script updates both claude-desktop and patchy-cnb packages since they
share the same version (from the k3d3/claude-desktop-linux-flake repo).
"""

import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_url_hash,
    fetch_github_latest_release,
)

PACKAGE_DIR = Path(__file__).parent
PATCHY_CNB_DIR = PACKAGE_DIR.parent / "patchy-cnb"

OWNER = "k3d3"
REPO = "claude-desktop-linux-flake"


def update_package_file(package_file: Path, version: str, src_hash: str | None = None) -> None:
    """Update version and optionally hash in a package.nix file."""
    content = package_file.read_text()

    # Update version
    content = re.sub(
        r'version = "[^"]+";',
        f'version = "{version}";',
        content,
    )

    # Update source hash if provided
    if src_hash:
        content = re.sub(
            r'(src = fetch[^{]+\{[^}]*hash = ")[^"]+(")',
            rf'\g<1>{src_hash}\2',
            content,
            flags=re.DOTALL,
        )

    package_file.write_text(content)


def get_current_version(package_file: Path) -> str:
    """Get current version from package.nix."""
    content = package_file.read_text()
    match = re.search(r'version = "([^"]+)";', content)
    if not match:
        raise ValueError(f"Could not find version in {package_file}")
    return match.group(1)


def main() -> None:
    """Update the claude-desktop and patchy-cnb packages."""
    package_file = PACKAGE_DIR / "package.nix"
    patchy_package_file = PATCHY_CNB_DIR / "package.nix"

    current = get_current_version(package_file)
    latest = fetch_github_latest_release(OWNER, REPO)

    print(f"Current: {current}, Latest: {latest}")

    if current == latest:
        print("Already up to date")
        return

    # Calculate new hash for Windows installer
    installer_url = f"https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/Claude-Setup-x64.exe?v={latest}"
    print(f"Calculating hash for: {installer_url}")
    installer_hash = calculate_url_hash(installer_url)
    print(f"Installer hash: {installer_hash}")

    # Update claude-desktop package
    update_package_file(package_file, latest, installer_hash)
    print(f"Updated claude-desktop to {latest}")

    # Update patchy-cnb version (hash will be updated by nix-update)
    update_package_file(patchy_package_file, latest)
    print(f"Updated patchy-cnb version to {latest}")

    # Run nix-update for patchy-cnb to update the fetchFromGitHub hash
    print("Running nix-update for patchy-cnb to update source hash...")
    result = subprocess.run(
        [
            "nix",
            "run",
            "nixpkgs#nix-update",
            "--",
            "--flake",
            "patchy-cnb",
            "--version",
            latest,
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"Warning: nix-update for patchy-cnb failed: {result.stderr}")
        print("You may need to update the patchy-cnb hash manually")
    else:
        print("Successfully updated patchy-cnb hashes")


if __name__ == "__main__":
    main()
