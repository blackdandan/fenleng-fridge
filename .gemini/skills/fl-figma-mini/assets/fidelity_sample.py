#!/usr/bin/env python3
"""fl-figma-mini · 微信小程序截图保真采样工具。

依赖：Pillow。坐标参数均为归一化 fraction [0, 1]，便于比较相同内容但分辨率不同的截图。
脚本只做确定性测量；像素结果不能替代交互、滚动、字体和真机复核。

子命令：
  compare FIG REN [--out diff.png]  尺寸、平均差、P95、最大差和超阈值比例
  point IMG XF YF                 关键位置颜色 hex
  glyph IMG X0 Y0 X1 Y1           区域内深色文字可见高度和字号估算
  bbox IMG X0 Y0 X1 Y1 HUE        色系元素包围盒与位置
  sxs FIG REN Y0 Y1 [--out x.png] 局部并排图
"""

import argparse
import math
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("需要 Pillow：pip install pillow")


def _load(path):
    try:
        return Image.open(path).convert("RGB")
    except OSError as exc:
        raise SystemExit(f"无法读取图片 {path}: {exc}")


def _hex(rgb):
    return "#%02X%02X%02X" % tuple(rgb)


def _at(img, xf, yf):
    w, h = img.size
    x = min(max(int(xf * w), 0), w - 1)
    y = min(max(int(yf * h), 0), h - 1)
    return img.getpixel((x, y))


def _tint(r, g, b):
    mx, mn = max(r, g, b), min(r, g, b)
    if mx - mn < 12:
        return "neutral"
    if b > r + 20 and b > g + 20:
        return "blue"
    if b > r + 6 and abs(r - g) < 8:
        return "purple/periwinkle"
    if g > r + 4 and b >= g:
        return "cyan"
    if r > g and r > b:
        return "warm/red"
    if g > r and g > b:
        return "green"
    return "other"


def _box(img, x0, y0, x1, y1):
    w, h = img.size
    return (
        max(0, int(x0 * w)),
        max(0, int(y0 * h)),
        min(w, int(x1 * w)),
        min(h, int(y1 * h)),
    )


def cmd_compare(args):
    fig, ren = _load(args.fig), _load(args.ren)
    if fig.size != ren.size:
        raise SystemExit(
            f"截图尺寸不同：figma={fig.size[0]}x{fig.size[1]} "
            f"render={ren.size[0]}x{ren.size[1]}；请先统一 profile，不要直接缩放掩盖问题"
        )

    total = fig.size[0] * fig.size[1]
    values = []
    max_diff = 0
    mismatch = 0
    diff = Image.new("RGB", fig.size)
    diff_pixels = diff.load()
    for y in range(fig.size[1]):
        for x in range(fig.size[0]):
            a = fig.getpixel((x, y))
            b = ren.getpixel((x, y))
            d = max(abs(a[i] - b[i]) for i in range(3))
            values.append(d)
            max_diff = max(max_diff, d)
            if d > args.threshold:
                mismatch += 1
            scale = min(255, d * 5)
            diff_pixels[x, y] = (scale, 0, 0) if d else (255, 255, 255)

    values.sort()
    mean = sum(values) / len(values)
    p95 = values[min(len(values) - 1, math.floor(len(values) * 0.95))]
    ratio = mismatch / total * 100
    print(f"尺寸：{fig.size[0]}x{fig.size[1]}")
    print(f"平均最大通道差：{mean:.2f}")
    print(f"P95 最大通道差：{p95}")
    print(f"最大通道差：{max_diff}")
    print(f"超阈值像素：{mismatch}/{total} ({ratio:.2f}%，阈值={args.threshold})")
    if args.out:
        diff.save(args.out)
        print(f"差异图：{Path(args.out)}")


def cmd_point(args):
    color = _at(_load(args.img), args.xf, args.yf)
    print(f"({args.xf:.3f},{args.yf:.3f}) {_hex(color)} {_tint(*color)}")


def cmd_glyph(args):
    img = _load(args.img)
    left, top, right, bottom = _box(img, args.x0, args.y0, args.x1, args.y1)
    pixels = []
    for x in range(left, right):
        for y in range(top, bottom):
            r, g, b = img.getpixel((x, y))
            if r < args.dark and g < args.dark and b < args.dark + 20:
                pixels.append(y)
    if not pixels:
        print("区域内未找到深色文字；调大 --dark 或更换区域")
        return
    cap_px = max(pixels) - min(pixels)
    cap_design = cap_px / img.size[1] * args.base
    font_est = cap_design / 0.70
    print(
        f"深色文字像素高={cap_px}；设计基准({args.base:g})下 "
        f"cap≈{cap_design:.1f}px；估算 fontSize≈{font_est:.1f}px"
    )


def _hue_pred(name):
    def dark(r, g, b):
        return r < 120 and g < 120 and b < 140

    def blue(r, g, b):
        return b > 170 and b > r + 25 and b > g + 25 and r < 150

    def yellow(r, g, b):
        return r > 200 and g > 180 and b < 150

    def red(r, g, b):
        return r > 170 and r > g + 50 and r > b + 50

    def green(r, g, b):
        return g > 140 and g > r + 30 and g > b + 10

    def white(r, g, b):
        return r > 235 and g > 235 and b > 235

    return {"dark": dark, "blue": blue, "yellow": yellow, "red": red,
            "green": green, "white": white}[name]


def cmd_bbox(args):
    img = _load(args.img)
    left, top, right, bottom = _box(img, args.x0, args.y0, args.x1, args.y1)
    pred = _hue_pred(args.hue)
    xs, ys = [], []
    for x in range(left, right):
        for y in range(top, bottom):
            if pred(*img.getpixel((x, y))):
                xs.append(x)
                ys.append(y)
    if not xs:
        print(f"区域内未命中 {args.hue} 色系像素")
        return
    min_x, max_x, min_y, max_y = min(xs), max(xs), min(ys), max(ys)
    print(
        f"{args.hue} bbox(px): x[{min_x}-{max_x}] y[{min_y}-{max_y}] "
        f"w={max_x - min_x} h={max_y - min_y}"
    )
    print(
        f"设计基准({args.base:g})：w≈{(max_x - min_x) / img.size[0] * args.base:.1f} "
        f"h≈{(max_y - min_y) / img.size[1] * args.base:.1f}"
    )
    print(
        f"位置 fraction：left={min_x / img.size[0]:.3f} "
        f"right={max_x / img.size[0]:.3f} top={min_y / img.size[1]:.3f} "
        f"bottom={max_y / img.size[1]:.3f}"
    )


def cmd_sxs(args):
    fig, ren = _load(args.fig), _load(args.ren)
    y0, y1 = args.y0, args.y1

    def crop(img):
        w, h = img.size
        part = img.crop((0, int(y0 * h), w, int(y1 * h)))
        return part.resize((420, max(1, int(420 * part.size[1] / part.size[0]))))

    left, right = crop(fig), crop(ren)
    height = max(left.size[1], right.size[1])
    canvas = Image.new("RGB", (860, height), (255, 255, 255))
    canvas.paste(left, (0, 0))
    canvas.paste(right, (440, 0))
    canvas.save(args.out)
    print(f"已存并排图（左 Figma / 右 render）：{args.out}")


def main():
    parser = argparse.ArgumentParser(description="fl-figma-mini 截图保真采样门禁")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("compare")
    p.add_argument("fig")
    p.add_argument("ren")
    p.add_argument("--threshold", type=int, default=20)
    p.add_argument("--out")
    p.set_defaults(fn=cmd_compare)

    p = sub.add_parser("point")
    p.add_argument("img")
    p.add_argument("xf", type=float)
    p.add_argument("yf", type=float)
    p.set_defaults(fn=cmd_point)

    p = sub.add_parser("glyph")
    p.add_argument("img")
    p.add_argument("x0", type=float)
    p.add_argument("y0", type=float)
    p.add_argument("x1", type=float)
    p.add_argument("y1", type=float)
    p.add_argument("--base", type=float, default=375)
    p.add_argument("--dark", type=int, default=110)
    p.set_defaults(fn=cmd_glyph)

    p = sub.add_parser("bbox")
    p.add_argument("img")
    p.add_argument("x0", type=float)
    p.add_argument("y0", type=float)
    p.add_argument("x1", type=float)
    p.add_argument("y1", type=float)
    p.add_argument("hue", choices=["dark", "blue", "yellow", "red", "green", "white"])
    p.add_argument("--base", type=float, default=375)
    p.set_defaults(fn=cmd_bbox)

    p = sub.add_parser("sxs")
    p.add_argument("fig")
    p.add_argument("ren")
    p.add_argument("y0", type=float)
    p.add_argument("y1", type=float)
    p.add_argument("--out", default="sxs.png")
    p.set_defaults(fn=cmd_sxs)

    args = parser.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
