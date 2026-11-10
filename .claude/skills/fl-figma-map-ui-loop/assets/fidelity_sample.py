#!/usr/bin/env python3
"""fl-figma-map-ui-loop · 保真采样工具（验收硬门禁）。

用途：把「figma 设计稿 vs 我的渲染/真机截图」的对比，从**肉眼判断**变成**数字判断**。
凡要宣布某行「保真通过」，必须先用本工具产出数字（背景 hex / 文字色 / 字号 cap 高 / 元素 bbox），
不准只凭并排看图下结论——实测踩过的坑：青蓝当淡紫、绿数字当红、漏掉背景装饰图案层、插图摆错位置，
全是肉眼放过、采样一上就现形。

依赖：Pillow（`pip install pillow` 或项目自带）。
约定：所有坐标用**归一化 fraction [0,1]**，避免两图分辨率不同对不齐。

子命令：
  bg     FIG REN                背景网格采样 + 平整度 → 判定纯色 vs 有图案/装饰层 + 通道差异告警
  strip  IMG [--x 0.025]        沿竖直边缘采背景条（看渐变走向、纯色 or 有 blob）
  point  IMG XF YF              单点 hex（+冷暖/色相提示）
  glyph  IMG X0 Y0 X1 Y1        测区域内深色文字高度 → 设计 px + 估算 fontSize（核字号）
  bbox   IMG X0 Y0 X1 Y1 HUE    测某色系元素 bbox（IP/图标 的大小/位置/是否叠放）
  sxs    FIG REN Y0 Y1 [..]     生成并排对照图（按宽对齐），人工复核兜底

HUE ∈ {blue,yellow,red,green,dark,white}
典型流程：先 `bg` 对背景（最常被忽略的一层），再 `glyph` 核标题字号，
再 `bbox` 核 IP/图标位置，最后 `sxs` 出并排图人工兜底。
"""

import argparse
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("需要 Pillow：pip install pillow")


def _load(p):
    return Image.open(p).convert("RGB")


def _hex(rgb):
    return "#%02X%02X%02X" % rgb


def _at(img, xf, yf):
    w, h = img.size
    x = min(int(xf * w), w - 1)
    y = min(int(yf * h), h - 1)
    return img.getpixel((x, y))


def _tint(r, g, b):
    mx, mn = max(r, g, b), min(r, g, b)
    if mx - mn < 12:
        return "neutral"
    if b > r + 6 and abs(r - g) < 8:
        return "purple/periwinkle(R=G<B)"
    if g > r + 4 and b >= g:
        return "cyan(G>R)"
    if r > g and r > b:
        return "warm/red"
    if g > r and g > b:
        return "green"
    return "?"


# ---- bg：背景网格 + 平整度 ----------------------------------------------------
_GRID_X = [0.05, 0.27, 0.50, 0.73, 0.95]
_GRID_Y = [0.04, 0.10, 0.18, 0.30, 0.55, 0.85]


def _grid(img):
    rows = []
    for yf in _GRID_Y:
        rows.append([(xf, yf, _at(img, xf, yf)) for xf in _GRID_X])
    return rows


def _flatness(grid):
    """背景结构指标：各采样点 RGB 的逐通道极差最大值。
    值小 = 接近纯色；值大 = 有渐变/装饰图案（需在渲染里还原层次，不能用平涂代替）。"""
    pts = [c for row in grid for (_, _, c) in row]
    spread = max(max(c[k] for c in pts) - min(c[k] for c in pts) for k in range(3))
    return spread


def cmd_bg(a):
    fig, ren = _load(a.fig), _load(a.ren)
    gf, gr = _grid(fig), _grid(ren)
    print("背景网格采样（左列=y，行内=x: %s）" % _GRID_X)
    print("  FIGMA:")
    for row in gf:
        print("   y=%.2f " % row[0][1] + " ".join(_hex(c) for (_, _, c) in row))
    print("  RENDER:")
    for row in gr:
        print("   y=%.2f " % row[0][1] + " ".join(_hex(c) for (_, _, c) in row))
    ff, fr = _flatness(gf), _flatness(gr)
    print("平整度（通道极差，越大越有图案）  figma=%d  render=%d" % (ff, fr))
    # 告警
    warned = False
    if ff - fr >= 18:
        print("  ⚠️ figma 背景明显比渲染更有层次 → 可能漏了渐变/装饰图案(blob)层，"
              "别用平涂色代替。")
        warned = True
    # 顶部中心色相对比（最常错：青 vs 紫）
    cf = _at(fig, 0.5, 0.10)
    cr = _at(ren, 0.5, 0.10)
    if _tint(*cf) != _tint(*cr):
        print("  ⚠️ 顶部色相不一致：figma=%s%s  render=%s%s" %
              (_hex(cf), _tint(*cf), _hex(cr), _tint(*cr)))
        warned = True
    # 逐点最大通道差
    dmax = 0
    for rf, rr in zip(gf, gr):
        for (_, _, cf), (_, _, cr) in zip(rf, rr):
            dmax = max(dmax, max(abs(cf[k] - cr[k]) for k in range(3)))
    print("逐点最大通道差 = %d  %s" % (dmax, "(>20 视为不通过)" if dmax > 20 else "(OK)"))
    if not warned and dmax <= 20:
        print("  ✓ 背景采样通过")
    else:
        print("  ✗ 背景采样未通过：按上面差异修正后重采")


# ---- strip：竖直边缘背景条 ----------------------------------------------------
def cmd_strip(a):
    img = _load(a.img)
    print("背景竖条 x=%.3f：" % a.x)
    for yf in [0.0, 0.04, 0.08, 0.13, 0.18, 0.25, 0.32, 0.45, 0.6, 0.85]:
        c = _at(img, a.x, yf)
        print("  y=%.2f %s %s" % (yf, _hex(c), _tint(*c)))


# ---- point ----------------------------------------------------------------
def cmd_point(a):
    c = _at(_load(a.img), a.xf, a.yf)
    print("(%.3f,%.3f) %s %s" % (a.xf, a.yf, _hex(c), _tint(*c)))


# ---- glyph：文字高度 → 字号 ---------------------------------------------------
def cmd_glyph(a):
    img = _load(a.img)
    w, h = img.size
    ys = []
    for x in range(int(a.x0 * w), int(a.x1 * w)):
        for y in range(int(a.y0 * h), int(a.y1 * h)):
            r, g, b = img.getpixel((x, y))
            if r < a.dark and g < a.dark and b < a.dark + 20:
                ys.append(y)
    if not ys:
        print("区域内未找到深色文字（调大 --dark 或换区域）")
        return
    cap_px = max(ys) - min(ys)
    cap_design = cap_px / h * a.base
    font_est = cap_design / 0.70  # cap height ≈ 0.7 * fontSize
    print("深色文字像素高=%d  → 设计基准(%g)下 cap≈%.1f px  估算 fontSize≈%.1f px"
          % (cap_px, a.base, cap_design, font_est))


# ---- bbox：元素包围盒 ---------------------------------------------------------
def _hue_pred(name):
    def dark(r, g, b):
        return r < 120 and g < 120 and b < 140

    def blue(r, g, b):
        return b > 170 and b > r + 25 and g > r and r < 150

    def yellow(r, g, b):
        return r > 200 and g > 180 and b < 150

    def red(r, g, b):
        return r > 170 and r > g + 50 and r > b + 50

    def green(r, g, b):
        return g > 140 and g > r + 30 and g > b + 10

    def white(r, g, b):
        return r > 235 and g > 235 and b > 235

    return {"dark": dark, "blue": blue, "yellow": yellow,
            "red": red, "green": green, "white": white}[name]


def cmd_bbox(a):
    img = _load(a.img)
    w, h = img.size
    pred = _hue_pred(a.hue)
    xs, ys = [], []
    for x in range(int(a.x0 * w), int(a.x1 * w)):
        for y in range(int(a.y0 * h), int(a.y1 * h)):
            if pred(*img.getpixel((x, y))):
                xs.append(x)
                ys.append(y)
    if not xs:
        print("区域内未命中 %s 色系像素" % a.hue)
        return
    bw, bh = max(xs) - min(xs), max(ys) - min(ys)
    print("%s 元素 bbox(px): x[%d-%d] y[%d-%d]  w=%d h=%d" %
          (a.hue, min(xs), max(xs), min(ys), max(ys), bw, bh))
    print("  设计基准(%g): w≈%.0f h≈%.0f" % (a.base, bw / w * a.base, bh / h * a.base))
    print("  位置 fraction: left=%.3f right=%.3f top=%.3f bottom=%.3f" %
          (min(xs) / w, max(xs) / w, min(ys) / h, max(ys) / h))


# ---- sxs：并排对照 ------------------------------------------------------------
def cmd_sxs(a):
    fig, ren = _load(a.fig), _load(a.ren)

    def crop(img, y0, y1):
        w, h = img.size
        c = img.crop((0, int(y0 * h), w, int(y1 * h)))
        return c.resize((420, int(420 * c.size[1] / c.size[0])))

    f = crop(fig, a.y0, a.y1)
    r = crop(ren, a.ry0 if a.ry0 is not None else a.y0,
             a.ry1 if a.ry1 is not None else a.y1)
    H = max(f.size[1], r.size[1])
    cv = Image.new("RGB", (860, H), (255, 255, 255))
    cv.paste(f, (0, 0))
    cv.paste(r, (440, 0))
    cv.save(a.out)
    print("已存并排图（左 figma / 右 render）：%s" % a.out)


def main():
    p = argparse.ArgumentParser(description="fl-figma-map-ui-loop 保真采样门禁")
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("bg"); s.add_argument("fig"); s.add_argument("ren"); s.set_defaults(fn=cmd_bg)
    s = sub.add_parser("strip"); s.add_argument("img"); s.add_argument("--x", type=float, default=0.025); s.set_defaults(fn=cmd_strip)
    s = sub.add_parser("point"); s.add_argument("img"); s.add_argument("xf", type=float); s.add_argument("yf", type=float); s.set_defaults(fn=cmd_point)
    s = sub.add_parser("glyph"); s.add_argument("img"); s.add_argument("x0", type=float); s.add_argument("y0", type=float); s.add_argument("x1", type=float); s.add_argument("y1", type=float); s.add_argument("--base", type=float, default=375); s.add_argument("--dark", type=int, default=110); s.set_defaults(fn=cmd_glyph)
    s = sub.add_parser("bbox"); s.add_argument("img"); s.add_argument("x0", type=float); s.add_argument("y0", type=float); s.add_argument("x1", type=float); s.add_argument("y1", type=float); s.add_argument("hue", choices=["dark", "blue", "yellow", "red", "green", "white"]); s.add_argument("--base", type=float, default=375); s.set_defaults(fn=cmd_bbox)
    s = sub.add_parser("sxs"); s.add_argument("fig"); s.add_argument("ren"); s.add_argument("y0", type=float); s.add_argument("y1", type=float); s.add_argument("--ry0", type=float); s.add_argument("--ry1", type=float); s.add_argument("--out", default="/tmp/sxs.png"); s.set_defaults(fn=cmd_sxs)

    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
