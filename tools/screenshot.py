#!/usr/bin/env python3
"""Render PocketGroove screens to PNG without LÖVE (rough preview).

Boots the real game headless (LuaJIT via lupa, LÖVE faked by tests/helpers.lua),
drives inputs for a named scene, records every love.graphics call made by
love.draw(), and rasterises them with Pillow at 2x. Text uses DejaVu Sans
(derived from LÖVE's default Vera Sans), so layout is close but not exact;
check the real device for final pixels.

    python3 tools/screenshot.py                 # every scene -> screenshots/
    python3 tools/screenshot.py harp-colour     # one scene
"""
import math
import os
import sys

from lupa.luajit21 import LuaRuntime
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCALE = 2
FONT_FILE = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

# Each scene is Lua run after boot, using the tests/helpers.lua input helpers
SCENES = {
    "play-drums": 'H.play(0.5)',
    "drums-pattern": 'H.tap("L2"); H.hold("B", "R1"); H.play(2.2); H.release("B", "R1");'
                     ' H.hold("Y", "UP"); H.play(0.05); H.release("Y", "UP"); H.play(1.0);'
                     ' H.hold("A", "L1", "R1"); H.play(1.0); H.release("A", "L1", "R1"); H.tap("L2"); H.play(0.3)',
    "track-drums": 'H.hold("SELECT"); H.play(0.3)',
    "swap-preview": 'H.hold("SELECT"); H.play(0.3); H.tap("RIGHT")',
    "harp-play": 'H.tap("SELECT"); H.play(0.2)',
    "harp-colour": 'H.tap("SELECT"); H.hold("SELECT"); H.play(0.3); H.tap("DOWN"); H.tap("R1")',
    "harp-maj7": 'H.tap("SELECT"); H.hold("SELECT"); H.play(0.3); H.tap("DOWN"); H.tap("R1");'
                 ' H.release("SELECT"); H.play(0.2)',
    "transport": 'H.hold("START"); H.play(0.3)',
    "grain-hold": 'for _ = 1, 3 do H.tap("SELECT") end; H.tap("L2"); H.hold("B", "RIGHT"); H.play(0.8)',
    "grain-recording": 'for _ = 1, 3 do H.tap("SELECT") end; H.play(1.0); H.tap("L2"); H.hold("B"); H.play(1.0)',
    "held-notes": 'for _ = 1, 3 do H.tap("SELECT") end; H.tap("L2"); H.play(0.5); H.hold("B"); H.play(0.9); H.release("B");'
                  ' H.play(0.6); H.hold("Y"); H.play(0.4); H.release("Y"); H.play(1.6); H.hold("X"); H.play(1.2);'
                  ' H.release("X"); H.tap("L2"); H.play(1.1)',
    "grain-playback": 'for _ = 1, 3 do H.tap("SELECT") end; H.tap("L2"); H.hold("A"); H.play(1.2); H.release("A");'
                      ' H.play(0.05); H.tap("L2"); H.play(3.4)',
}

_fonts = {}


def font(size):
    if size not in _fonts:
        _fonts[size] = ImageFont.truetype(FONT_FILE, max(1, int(size * SCALE)))
    return _fonts[size]


def measure(text, size):
    return font(size).getlength(str(text)) / SCALE


RECORDER = r'''
local ops = {}
local state = { color = {1,1,1,1}, lw = 1, font = nil, tx = 0, ty = 0, sx = 1, stack = {} }
local function rec(kind, ...) ops[#ops+1] = { kind, state.color, state.lw, state.font and state.font.size or 12,
                                              state.tx, state.ty, state.sx, {...} } end
local function newFont(size)
    size = size or 12
    return { size = size,
             getWidth = function(_, t) return MEASURE(tostring(t), size) end,
             getHeight = function() return math.floor(size * 1.17 + 0.5) end }
end
GFX = setmetatable({
    newFont = newFont,
    getDimensions = function() return 640, 480 end,
    setColor = function(r, g, b, a) state.color = { r, g, b, a or 1 } end,
    setLineWidth = function(w) state.lw = w end,
    setFont = function(f) state.font = f end,
    push = function() table.insert(state.stack, { state.tx, state.ty, state.sx }) end,
    pop = function() local t = table.remove(state.stack); state.tx, state.ty, state.sx = t[1], t[2], t[3] end,
    translate = function(x, y) state.tx = state.tx + x * state.sx; state.ty = state.ty + y * state.sx end,
    scale = function(s) state.sx = state.sx * s end,
    clear = function(r, g, b) ops = {}; rec("clear", r, g, b) end,
    rectangle = function(...) rec("rectangle", ...) end,
    circle = function(...) rec("circle", ...) end,
    line = function(...) rec("line", ...) end,
    polygon = function(...) rec("polygon", ...) end,
    arc = function(...) rec("arc", ...) end,
    print = function(...) rec("print", ...) end,
}, { __index = function() return function() end end })
function TAKE() return ops end
'''


def lua_list(t):
    return [t[i] for i in range(1, len(t) + 1)] if t is not None else []


def flat_points(args):
    if len(args) == 1 and not isinstance(args[0], (int, float)):
        args = lua_list(args[0])
    return [(args[i], args[i + 1]) for i in range(0, len(args) - 1, 2)]


def rgba(c, bg):
    r, g, b, a = (lua_list(c) + [1])[:4]
    a = max(0.0, min(1.0, a))
    return tuple(int(255 * max(0, min(1, v))) for v in (r, g, b)) + (int(255 * a),)


def render(ops, path):
    img = Image.new("RGBA", (640 * SCALE, 480 * SCALE), (0, 0, 0, 255))
    for op in lua_list(ops):
        kind, color, lw, fsize, tx, ty, sx, args = op[1], op[2], op[3], op[4], op[5], op[6], op[7], lua_list(op[8])
        if kind == "clear":
            img.paste((int(args[0] * 255), int(args[1] * 255), int(args[2] * 255), 255), (0, 0, img.width, img.height))
            continue
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        col = rgba(color, None)
        k = SCALE * sx
        P = lambda x, y: (tx * SCALE + x * k, ty * SCALE + y * k)
        w = max(1, int(round(lw * k)))
        if kind == "rectangle":
            mode, x, y, ww, hh = args[:5]
            rad = (args[5] if len(args) > 5 and args[5] else 0) * k
            box = [P(x, y), P(x + ww, y + hh)]
            if box[1][0] < box[0][0] or box[1][1] < box[0][1]:
                continue
            if mode == "fill":
                d.rounded_rectangle(box, radius=rad, fill=col)
            else:
                d.rounded_rectangle(box, radius=rad, outline=col, width=w)
        elif kind == "circle":
            mode, x, y, r = args[:4]
            (cx, cy), rr = P(x, y), r * k
            box = [(cx - rr, cy - rr), (cx + rr, cy + rr)]
            if mode == "fill":
                d.ellipse(box, fill=col)
            else:
                d.ellipse(box, outline=col, width=w)
        elif kind == "line":
            pts = [P(x, y) for x, y in flat_points(args)]
            if len(pts) >= 2:
                d.line(pts, fill=col, width=w)
        elif kind == "polygon":
            mode = args[0]
            pts = [P(x, y) for x, y in flat_points(args[1:])]
            if len(pts) >= 3:
                if mode == "fill":
                    d.polygon(pts, fill=col)
                else:
                    d.polygon(pts, outline=col, width=w)
        elif kind == "arc":
            mode = args[0]
            rest = args[1:]
            if isinstance(rest[0], str):
                rest = rest[1:]
            x, y, r, a1, a2 = rest[:5]
            (cx, cy), rr = P(x, y), r * k
            lo, hi = sorted((math.degrees(a1), math.degrees(a2)))
            box = [(cx - rr, cy - rr), (cx + rr, cy + rr)]
            if mode == "fill":
                d.pieslice(box, lo, hi, fill=col)
            else:
                d.arc(box, lo, hi, fill=col, width=w)
        elif kind == "print":
            text, x, y = str(args[0]), args[1], args[2]
            d.text(P(x, y), text, font=font(fsize * sx), fill=col)
        img.alpha_composite(layer)
    img.convert("RGB").save(path)


def main():
    os.chdir(ROOT)
    names = sys.argv[1:] or list(SCENES)
    out_dir = os.path.join(ROOT, "screenshots")
    os.makedirs(out_dir, exist_ok=True)
    for name in names:
        lua = LuaRuntime()
        lua.globals().MEASURE = measure
        lua.execute(RECORDER)
        lua.execute('package.path = "pocketgroove/?.lua;pocketgroove/?/init.lua;tests/?.lua;" .. package.path')
        lua.execute('H = require("helpers"); H.graphicsOverride = GFX; H.loadMain(); H.play(0.1)')
        lua.execute(SCENES[name])
        lua.execute('love.draw()')
        path = os.path.join(out_dir, name + ".png")
        render(lua.eval('TAKE()'), path)
        print("wrote", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    main()
