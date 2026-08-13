#!/usr/bin/env python3
"""Curated city skyline cards → iOS asset catalog (1x/2x/3x + light grade).

Sources are fixed Unsplash photo IDs (Unsplash License) chosen for landmark
skylines — not random LoremFlickr tag pulls. Attribution lives in ASSET_CREDITS.txt.
"""
from __future__ import annotations

import argparse
import io
import json
import time
import urllib.request
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "ios/KadenRacing/Resources/Assets.xcassets"
CREDITS = ROOT / "ASSET_CREDITS.txt"
NOTE = ROOT / "ios/KadenRacing/Resources/CITY_CARD_PHOTOS.txt"
UA = "KadenRacing/1.0 (city card assets; attribution in ASSET_CREDITS.txt)"

SIZES = {
    "1x": (640, 360),
    "2x": (1280, 720),
    "3x": (1920, 1080),
}


@dataclass(frozen=True)
class CityCard:
    asset: str
    place: str
    photo_id: str  # e.g. photo-1496442226666-8d4d0e62e6e9
    photographer: str
    # Soft grade: (r_mul, g_mul, b_mul, contrast, brightness)
    grade: tuple[float, float, float, float, float]


# Landmark-forward Unsplash stills — audited for correct city identity.
# Neutral grade keeps photos natural (heavy grades looked cheap).
NATURAL = (1.0, 1.0, 1.0, 1.02, 1.0)

CITIES: list[CityCard] = [
    CityCard("CityCardLibertyMetro", "New York (Times Square)",
             "photo-1496442226666-8d4d0e62e6e9", "Nastya Dulhiier", NATURAL),
    CityCard("CityCardPacificTerrace", "Tokyo (Akihabara)",
             "photo-1540959733332-eab4deabeeaf", "Jezael Melgoza", NATURAL),
    CityCard("CityCardGulfSpires", "Dubai (Burj Al Arab / Palm)",
             "photo-1518684079-3c830dcef090", "David Rodrigo", NATURAL),
    CityCard("CityCardThamesHollow", "London (Tower Bridge)",
             "photo-1513635269975-59663e0ac1ad", "Benjamin Davies", NATURAL),
    CityCard("CityCardSunsetStripBay", "Los Angeles (Hollywood)",
             "photo-1580655653885-65763b2597d0", "Avi Richards", NATURAL),
    CityCard("CityCardCoralNeonShores", "Miami (Biscayne Bay)",
             "photo-1506966953602-c20cc11f75e3", "Pedro Lastra", NATURAL),
    CityCard("CityCardBayGraniteHills", "San Francisco (Golden Gate)",
             "photo-1501594907352-04cda38ebc29", "Joseph Barrientos", NATURAL),
    CityCard("CityCardSugarloafCoastal", "Rio de Janeiro (Sugarloaf)",
             "photo-1544989164-31dc3c645987", "Agustin Diaz Gargiulo", NATURAL),
    CityCard("CityCardDesertLuxStrip", "Las Vegas (Strip)",
             "photo-1581351721010-8cf859cb14a4", "Parker Hilton", NATURAL),
    CityCard("CityCardGreatLakesWorks", "Chicago (skyline)",
             "photo-1477959858617-67f85cf4f1df", "Pedro Lastra", NATURAL),
    CityCard("CityCardCapitolGrid", "Washington DC (Capitol)",
             "photo-1501466044931-62695aada8e9", "Harold Mendoza", NATURAL),
    CityCard("CityCardEmeraldRainBay", "Dublin (St Ann's)",
             "photo-1549918864-48ac978761a4", "Anthony DELANOIX", NATURAL),
    CityCard("CityCardVolcanoRing", "Honolulu (Hawaiian coast)",
             "photo-1542259009477-d625272157b7", "Sean Oulashin", NATURAL),
    CityCard("CityCardMonolithFoundry", "Detroit (Renaissance Center)",
             "photo-1746485624341-ac2547769757", "realafm", NATURAL),
    CityCard("CityCardRedRockRun", "Arizona desert highway",
             "photo-1500530855697-b586d89ba3ee", "John Towner", NATURAL),
    CityCard("CityCardFrostHarbor", "Seattle (Space Needle)",
             "photo-1502175353174-a7a70e73b362", "Andrew Ruiz", NATURAL),
    CityCard("CityCardRioGrandeDust", "Mexico City (Zócalo)",
             "photo-1585464231875-d9ef1f5ad396", "Jezael Melgoza", NATURAL),
    CityCard("CityCardAlpinePassRing", "Swiss Alps",
             "photo-1506905925346-21bda4d32df4", "Pinipal", NATURAL),
    CityCard("CityCardHarborPearlDelta", "Hong Kong (Victoria Harbour)",
             "photo-1536599018102-9f803c140fc1", "Florian Wehde", NATURAL),
    CityCard("CityCardSaigonRiverArc", "Ho Chi Minh City (Bitexco)",
             "photo-1583417319070-4a69db38a482", "Hieu Vu Minh", NATURAL),
    CityCard("CityCardSydneyHarborLoop", "Sydney (Opera House)",
             "photo-1506973035872-a4ec16b8e8d9", "Dan Freeman", NATURAL),
    CityCard("CityCardFrostKremlinRun", "Moscow (St Basil's)",
             "photo-1513326738677-b964603b136d", "Nikolay Vorobyev", NATURAL),
    CityCard("CityCardBerlinVelocityLoop", "Berlin (Brandenburg Gate)",
             "photo-1560969184-10fe8719e047", "Florian Wehde", NATURAL),
    CityCard("CityCardParisBelleGrande", "Paris (Eiffel Tower)",
             "photo-1502602898657-3e91760cbb34", "Chris Karidis", NATURAL),
    CityCard("CityCardCairoSandCircuit", "Cairo (historic mosques)",
             "photo-1572252009286-268acec5ca0a", "Spencer Davis", NATURAL),
    CityCard("CityCardLagosPulseBay", "Lagos (Victoria Island / Ikoyi)",
             "photo-1744907895363-d351aa6019ef", "Tunde Buremo", NATURAL),
    CityCard("CityCardSeoulVoltageGrid", "Seoul (neon street)",
             "photo-1517154421773-0529f29ea451", "Jezael Melgoza", NATURAL),
    CityCard("CityCardMumbaiMonsoonMaze", "Mumbai (Gateway of India)",
             "photo-1529253355930-ddbe423a2ac7", "Jéan Béller", NATURAL),
    CityCard("CityCardJohannesburgRidge", "Cape Town / South Africa (Table Mountain)",
             "photo-1580060839134-75a5edca2e99", "Spencer Davis", NATURAL),
    CityCard("CityCardAucklandBreezeCoast", "Auckland (Sky Tower harbour)",
             "photo-1507699622108-4be3abd695ad", "Tobias Keller", NATURAL),
]


def unsplash_url(photo_id: str, w: int = 2400) -> str:
    # Width-only fetch — never force height (that was stretching some shots).
    return (
        f"https://images.unsplash.com/{photo_id}"
        f"?auto=format&fit=max&w={w}&q=95"
    )


def contents_json() -> str:
    return json.dumps(
        {
            "images": [
                {"filename": "photo.jpg", "idiom": "universal", "scale": "1x"},
                {"filename": "aaron.s@example.org", "idiom": "universal", "scale": "2x"},
                {"filename": "paula.r@example.org", "idiom": "universal", "scale": "3x"},
            ],
            "info": {"author": "xcode", "version": 1},
        },
        indent=2,
    ) + "\n"


def download_bytes(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "image/*"})
    with urllib.request.urlopen(req, timeout=90) as resp:
        data = resp.read()
    if len(data) < 12_000:
        raise ValueError(f"response too small ({len(data)} bytes)")
    return data


def crop_cover_16x9(img: "Image.Image") -> "Image.Image":
    """Center-weighted crop to 16:9 — crop only, never stretch."""
    from PIL import Image

    w, h = img.size
    target_ratio = 16 / 9
    src_ratio = w / max(1, h)
    if abs(src_ratio - target_ratio) < 0.01:
        return img
    if src_ratio > target_ratio:
        # Too wide — trim left/right.
        new_w = int(round(h * target_ratio))
        left = (w - new_w) // 2
        return img.crop((left, 0, left + new_w, h))
    # Too tall — trim top/bottom, keep a bit more sky (upper bias).
    new_h = int(round(w / target_ratio))
    top = int(round((h - new_h) * 0.32))
    top = max(0, min(top, h - new_h))
    return img.crop((0, top, w, top + new_h))


def process_image(raw: bytes, grade: tuple[float, float, float, float, float], size: tuple[int, int]) -> bytes:
    from PIL import Image, ImageEnhance, ImageOps

    img = ImageOps.exif_transpose(Image.open(io.BytesIO(raw)))
    img.load()
    img = img.convert("RGB")
    img = crop_cover_16x9(img)
    # High-quality downscale only — never stretch by non-uniform scale.
    img = img.resize(size, Image.Resampling.LANCZOS)

    # Barely-there grade (natural look).
    r_m, g_m, b_m, contrast, brightness = grade
    if (r_m, g_m, b_m) != (1.0, 1.0, 1.0):
        bands = img.split()
        bands = [
            bands[0].point(lambda p, m=r_m: min(255, int(p * m))),
            bands[1].point(lambda p, m=g_m: min(255, int(p * m))),
            bands[2].point(lambda p, m=b_m: min(255, int(p * m))),
        ]
        img = Image.merge("RGB", bands)
    if abs(contrast - 1.0) > 0.001:
        img = ImageEnhance.Contrast(img).enhance(contrast)
    if abs(brightness - 1.0) > 0.001:
        img = ImageEnhance.Brightness(img).enhance(brightness)
    # Gentle sharpen only — heavy UnsharpMask looked cheap.
    img = ImageEnhance.Sharpness(img).enhance(1.08)

    out = io.BytesIO()
    try:
        img.save(out, format="JPEG", quality=93, optimize=True, progressive=True, subsampling=0)
    except OSError:
        out = io.BytesIO()
        img.save(out, format="JPEG", quality=92, optimize=False, progressive=False)
    return out.getvalue()


def write_imageset(card: CityCard, force: bool = False) -> None:
    dest_dir = ASSETS / f"{card.asset}.imageset"
    dest_dir.mkdir(parents=True, exist_ok=True)
    targets = {
        "1x": dest_dir / "photo.jpg",
        "2x": dest_dir / "aaron.s@example.org",
        "3x": dest_dir / "paula.r@example.org",
    }
    if not force and all(p.exists() and p.stat().st_size > 8_000 for p in targets.values()):
        (dest_dir / "Contents.json").write_text(contents_json())
        print(f"✓ {card.asset} (exists)")
        return

    master_url = unsplash_url(card.photo_id, w=2400)
    print(f"→ {card.asset}  ({card.place})")
    raw = download_bytes(master_url)
    for scale, path in targets.items():
        path.write_bytes(process_image(raw, card.grade, SIZES[scale]))
    (dest_dir / "Contents.json").write_text(contents_json())


def write_credits() -> None:
    block_lines = [
        "",
        "City card / race sky photos (curated Unsplash License)",
        "  Re-download: python3 scripts/fetch_city_card_photos.py --force",
        "  License: https://unsplash.com/license — free for commercial use; attribution appreciated",
    ]
    for c in CITIES:
        block_lines.append(
            f"  - {c.place} ({c.asset}): photo by {c.photographer} — "
            f"https://unsplash.com/{c.photo_id}"
        )
    block = "\n".join(block_lines) + "\n"

    existing = CREDITS.read_text() if CREDITS.exists() else ""
    marker = "City card / race sky photos"
    if marker in existing:
        head = existing.split(marker)[0].rstrip()
        CREDITS.write_text(head + "\n" + block)
    else:
        CREDITS.write_text(existing.rstrip() + "\n" + block)

    NOTE.write_text(
        "City card photos: curated Unsplash landmark skylines (1x/2x/3x, light color grade).\n"
        "Not LoremFlickr. Re-download: python3 scripts/fetch_city_card_photos.py --force\n"
        "Credits: ../../ASSET_CREDITS.txt (repo root)\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="Re-download even if files exist")
    parser.add_argument("--only", type=str, default="", help="Comma-separated asset names")
    args = parser.parse_args()

    only = {s.strip() for s in args.only.split(",") if s.strip()}
    try:
        from PIL import Image  # noqa: F401
    except ImportError as exc:
        raise SystemExit(
            "Pillow is required. Install with: python3 -m pip install --user Pillow"
        ) from exc

    ASSETS.mkdir(parents=True, exist_ok=True)
    ok = 0
    failed: list[str] = []
    for card in CITIES:
        if only and card.asset not in only:
            continue
        try:
            write_imageset(card, force=args.force)
            ok += 1
        except Exception as exc:  # noqa: BLE001
            print(f"  FAIL {card.asset}: {exc}")
            failed.append(card.asset)
        time.sleep(0.7)
    write_credits()
    total = len(only) if only else len(CITIES)
    print(f"Done — {ok}/{total} imagesets.")
    if failed:
        print("Failed:", ", ".join(failed))
        raise SystemExit(1)


if __name__ == "__main__":
    main()
