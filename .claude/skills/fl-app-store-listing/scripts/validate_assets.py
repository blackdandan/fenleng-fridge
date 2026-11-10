#!/usr/bin/env python3
"""Validate store icon and screenshot files without external dependencies."""
import argparse
import json
import struct
from pathlib import Path


def png_info(path):
    data = path.read_bytes()
    if len(data) < 33 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError("not a PNG with IHDR")
    width, height = struct.unpack(">II", data[16:24])
    color_type = data[25]
    return {"path": str(path), "width": width, "height": height,
            "bytes": len(data), "format": "png",
            "hasAlpha": color_type in (4, 6)}


def jpeg_info(path):
    data = path.read_bytes()
    if len(data) < 4 or data[:2] != b"\xff\xd8":
        raise ValueError("not a JPEG")
    offset = 2
    while offset + 9 < len(data):
        if data[offset] != 0xFF:
            offset += 1
            continue
        marker = data[offset + 1]
        offset += 2
        if marker in (0xD8, 0xD9) or 0xD0 <= marker <= 0xD7:
            continue
        if offset + 2 > len(data):
            break
        length = struct.unpack(">H", data[offset:offset + 2])[0]
        if marker in {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
                      0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}:
            height, width = struct.unpack(">HH", data[offset + 3:offset + 7])
            return {"path": str(path), "width": width, "height": height,
                    "bytes": len(data), "format": "jpeg", "hasAlpha": False}
        if length < 2:
            break
        offset += length
    raise ValueError("JPEG dimensions not found")


def image_info(path):
    return png_info(path) if path.suffix.lower() == ".png" else jpeg_info(path)


def validate_tencent(root):
    errors, images = [], []
    candidates = [(root / "icon/app-icon.png", True)]
    screenshots = sorted((root / "screenshots").glob("*.png"))
    if not 4 <= len(screenshots) <= 5:
        errors.append("expected 4-5 PNG screenshots")
    candidates.extend((p, False) for p in screenshots)
    for path, icon in candidates:
        try:
            info = png_info(path)
            images.append(info)
            w, h, size = info["width"], info["height"], info["bytes"]
            if icon and (w, h) != (512, 512):
                errors.append(f"{path}: icon must be 512x512")
            if not icon and (w < 320 or h < 480):
                errors.append(f"{path}: screenshot below 320x480")
            # Decimal thresholds safely fit both common upload size conventions.
            if size > (200000 if icon else 1000000):
                errors.append(f"{path}: exceeds byte limit")
        except (OSError, ValueError, struct.error) as exc:
            errors.append(f"{path}: {exc}")
    return {"valid": not errors, "market": "tencent-myapp",
            "images": images, "errors": errors,
            "scope": "PNG header/dimensions/bytes only; visual and platform checks are separate"}


APPLE_IPHONE_PORTRAIT = {
    (1260, 2736), (1290, 2796), (1320, 2868),
    (1242, 2688), (1284, 2778), (1179, 2556), (1206, 2622),
}
APPLE_SCREENSHOT_SIZES = APPLE_IPHONE_PORTRAIT | {
    (height, width) for width, height in APPLE_IPHONE_PORTRAIT
}


def validate_vivo(root):
    errors, images = [], []
    screenshots = sorted(
        p for p in (root / "screenshots").glob("*")
        if p.suffix.lower() in {".png", ".jpg", ".jpeg"}
    )
    if not 3 <= len(screenshots) <= 5:
        errors.append("expected 3-5 vivo screenshots")
    for path, icon in [(root / "icon/app-icon.png", True),
                       *((p, False) for p in screenshots)]:
        try:
            info = image_info(path)
            images.append(info)
            size = (info["width"], info["height"])
            if icon and size not in {(256, 256), (512, 512)}:
                errors.append(f"{path}: icon must be 256x256 or 512x512")
            if not icon and size not in {(1080, 1920), (1920, 1080)}:
                errors.append(f"{path}: screenshot must be 1080x1920 or landscape equivalent")
            if info["bytes"] > (500000 if icon else 2000000):
                errors.append(f"{path}: exceeds byte limit")
        except (OSError, ValueError, struct.error) as exc:
            errors.append(f"{path}: {exc}")
    orientations = {i["width"] > i["height"] for i in images
                    if Path(i["path"]).parent.name == "screenshots"}
    if len(orientations) > 1:
        errors.append("vivo screenshots must use one orientation")
    return {"valid": not errors, "market": "vivo",
            "requirementsSnapshot": "2026-10-15",
            "images": images, "errors": errors,
            "scope": "image headers/dimensions/bytes only; visual and current-platform checks are separate"}


def validate_apple(root):
    errors, images = [], []
    icon = root / "icon/app-icon-1024.png"
    screenshots = sorted(
        path for path in (root / "screenshots").glob("*")
        if path.suffix.lower() in {".png", ".jpg", ".jpeg"}
    )
    if not 1 <= len(screenshots) <= 10:
        errors.append("expected 1-10 Apple screenshots")
    for path, is_icon in [(icon, True), *((path, False) for path in screenshots)]:
        try:
            info = image_info(path)
            images.append(info)
            size = (info["width"], info["height"])
            if is_icon and (info["format"] != "png" or size != (1024, 1024)):
                errors.append(f"{path}: icon must be a 1024x1024 PNG")
            if not is_icon and size not in APPLE_SCREENSHOT_SIZES:
                errors.append(f"{path}: size {size[0]}x{size[1]} is not in the 2026-09-20 iPhone snapshot")
            if info["hasAlpha"]:
                errors.append(f"{path}: Apple image must not contain an alpha channel")
        except (OSError, ValueError, struct.error) as exc:
            errors.append(f"{path}: {exc}")
    return {"valid": not errors, "market": "apple-app-store",
            "requirementsSnapshot": "2026-09-20",
            "images": images, "errors": errors,
            "scope": "image headers/dimensions/alpha only; visual, signing and current-platform checks are separate"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--assets", type=Path, required=True)
    parser.add_argument("--market", choices=("tencent-myapp", "apple-app-store", "vivo"),
                        default="tencent-myapp")
    args = parser.parse_args()
    validators = {"apple-app-store": validate_apple,
                  "tencent-myapp": validate_tencent, "vivo": validate_vivo}
    result = validators[args.market](args.assets)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(0 if result["valid"] else 1)
