"""Validate the narrowly scoped CVE-2025-47273 SBOM assessment at runtime."""

import importlib.metadata
import importlib.util
import json
import sysconfig
from pathlib import Path


def require(condition, message):
    # Explicit checks keep working under python -O, unlike assert statements.
    if not condition:
        raise SystemExit(message)


def main():
    site = Path(sysconfig.get_path("purelib"))
    # This deliberately does not derive the approved version from requirements:
    # a dependency bot must not silently renew the source-code assessment.
    approved_pip = "26.3"
    require(
        importlib.metadata.version("pip") == approved_pip,
        "Reassess pip source/SBOM and baseline before approving a new pip version",
    )
    require(
        importlib.util.find_spec("setuptools") is None,
        "Installed setuptools needs audit",
    )
    require(
        importlib.util.find_spec("pip._vendor.setuptools") is None,
        "pip vendors setuptools; reassess the exception",
    )
    require(
        not list(site.rglob("package_index.py")),
        "Vulnerable PackageIndex module exists",
    )
    bom = site / "pip/_vendor/bom.cdx.json"
    components = json.loads(bom.read_text())["components"]
    require(
        any(
            item.get("name") == "setuptools" and item.get("version") == "70.3.0"
            for item in components
        ),
        "Expected pip SBOM changed; reassess the exception",
    )
    print("Verified pip 26.3 SBOM entry; setuptools PackageIndex code is absent")


if __name__ == "__main__":
    main()
