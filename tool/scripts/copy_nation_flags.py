#!/usr/bin/env python3
"""Copy selected nation flags from attrs/1x1 into attrs/nations."""

from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/tiki_taka/attrs/1x1"
DST = ROOT / "assets/tiki_taka/attrs/nations"

NATIONS = {
    "Hungary": "hu",
    "Saudi Arabia": "sa",
    "Sweden": "se",
    "Chile": "cl",
    "Czech Republic": "cz",
    "Russia": "ru",
    "Serbia": "rs",
    "Wales": "gb-wls",
    "Australia": "au",
    "Bulgaria": "bg",
    "Ghana": "gh",
    "Montenegro": "me",
    "Norway": "no",
    "Peru": "pe",
    "Poland": "pl",
    "Scotland": "gb-sct",
    "South Korea": "kr",
    "Finland": "fi",
    "Ireland": "ie",
    "Liberia": "lr",
    "Northern Ireland": "gb-nir",
    "Romania": "ro",
    "Slovakia": "sk",
    "Ukraine": "ua",
}


def filename_for(display_name: str) -> str:
    return f"{display_name.replace(' ', '-')}.svg"


def main() -> None:
    copied: list[str] = []
    for display_name, code in NATIONS.items():
        src_file = SRC / f"{code}.svg"
        dst_file = DST / filename_for(display_name)
        if not src_file.is_file():
            raise FileNotFoundError(src_file)
        shutil.copy2(src_file, dst_file)
        copied.append(dst_file.name)

    print(f"Copied {len(copied)} files to {DST}")
    for name in copied:
        print(f"  {name}")


if __name__ == "__main__":
    main()
