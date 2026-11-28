#!/usr/bin/env python3
"""Render Pockimusi sounds to .wav files to listen to them without the device.

Boots the real sound generators headless (LuaJIT via lupa, LÖVE faked by
tests/helpers.lua with sample capture on) and writes 44.1 kHz 16-bit mono
files to renders/. A patch renders as one held note (attack one-shot, loop
fading in under it, release at the end) at the patch's own 0 semitones; with
a bright layer, a second file has it fully open. Drums render as one hit.
A break renders as its pattern played on a kit (see src/breaks.lua).

    python3 tools/render.py                    # every patch, drum sound and break
    python3 tools/render.py bass_reese         # one patch or drum sound
    python3 tools/render.py patches            # every patch
    python3 tools/render.py drums              # every drum sound
    python3 tools/render.py breaks             # every break on its default kit
    python3 tools/render.py break:amen         # one break (add :KIT NAME for a kit)
    python3 tools/render.py kit:FUNK BREAKS    # a two-bar test beat on a kit
"""
import math
import os
import struct
import sys
import wave

from lupa.luajit21 import LuaRuntime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "renders")
SR = 44100

BOOT = r"""
package.path = "pockimusi/?.lua;pockimusi/?/init.lua;tests/?.lua;" .. package.path
H = require("helpers")
H.captureSamples = true
M = H.fresh({ realSynth = true })
S = M.Synth
S:init()
S:ensureAllDrums()

local function samples(sd)
    local out, n = {}, sd.n
    for i = 0, n - 1 do out[i + 1] = sd.samples[i] or 0.0 end
    return out, n
end

-- One held note of a patch: { samples }, bright = 0..1
function renderPatch(id, seconds, bright)
    local p = S:preparePatch(id)
    if not p or p.silent then return nil end
    local att, na = {}, 0
    if p.attack then att, na = samples(S.pools[p.attack].data) end
    local loop, nl, br, nb
    if p.loop then loop, nl = samples(S.loopPools[p.loop].data) end
    if p.bright then br, nb = samples(S.loopPools[p.bright].data) end
    local total = math.floor(seconds * 44100)
    if not p.loop then total = math.max(total, na) end
    local rel = math.max(0.02, p.release or 0.1)
    local holdEnd = p.loop and (total - math.floor(rel * 44100)) or total
    local out = {}
    local xf = math.max(0.004, p.xfade or 0.01)
    for i = 0, total - 1 do
        local t = i / 44100
        local s = (i < na) and att[i + 1] or 0.0
        if loop then
            local env = math.min(1.0, t / xf) * (p.sustain or 0.5)
            if i >= holdEnd then env = env * math.max(0.0, 1.0 - (i - holdEnd) / (rel * 44100)) end
            local l = loop[(i % nl) + 1]
            if br and bright > 0 then l = l + br[(i % nb) + 1] * bright end
            s = s + l * env
        end
        out[i + 1] = s
    end
    return out
end

function patchIds()
    local out = {}
    for _, id in ipairs(S.patchOrder) do
        if not S.patches[id].silent then out[#out + 1] = id end
    end
    return out
end

function hasBright(id) return S.patches[id].bright ~= nil end

function drumIds()
    local out = {}
    for _, item in ipairs(S.drumCatalog) do out[#out + 1] = item.id end
    return out
end

function drumSamples(id)
    local pool = S.pools[id]
    if not pool then return nil end
    return (samples(pool.data))
end

-- A pattern as hits { time, sound, vol, semis } (from src/breaks.lua when present)
function breakIds()
    local ok, B = pcall(require, "src.breaks")
    if not ok then return {} end
    local out = {}
    for _, b in ipairs(B.LIST) do out[#out + 1] = b.id end
    return out
end

function breakHits(id, kitName, bpm, loops)
    local B = require("src.breaks")
    return B.renderHits(id, kitName, bpm or 170, loops or 2)
end

function kitHits(kitName, bpm)
    local B = require("src.breaks")
    return B.renderHits("two_step", kitName, bpm or 170, 2)
end
"""


def write_wav(name, data, peak_norm=False):
    os.makedirs(OUT, exist_ok=True)
    if peak_norm:
        peak = max((abs(x) for x in data), default=0.0)
        if peak > 0.98:
            data = [x * 0.98 / peak for x in data]
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for x in data:
            x = max(-1.0, min(1.0, x))
            frames += struct.pack("<h", int(x * 32767))
        w.writeframes(bytes(frames))
    print("wrote", os.path.relpath(path, ROOT))


def lua_list(t):
    return [t[i] for i in range(1, len(t) + 1)] if t is not None else None


def render_patch(g, pid):
    data = lua_list(g.renderPatch(pid, 1.6, 0))
    if data is None:
        return
    write_wav("patch_" + pid, data)
    if g.hasBright(pid):
        write_wav("patch_" + pid + "_bright", lua_list(g.renderPatch(pid, 1.6, 1.0)))


def render_drum(g, did):
    data = lua_list(g.drumSamples(did))
    if data is not None:
        write_wav("drum_" + did, data)


def mix_hits(g, hits):
    """hits: Lua list of { t, sound, vol, semis } -> mixed samples"""
    cache = {}
    events = []
    end = 0
    for i in range(1, len(hits) + 1):
        h = hits[i]
        t, sound, vol, semis = h[1], h[2], h[3], h[4] or 0.0
        if sound not in cache:
            cache[sound] = lua_list(g.drumSamples(sound)) or []
        src = cache[sound]
        ratio = 2.0 ** (semis / 12.0)
        start = int(t * SR)
        length = int(len(src) / ratio)
        events.append((start, src, vol, ratio, length))
        end = max(end, start + length)
    out = [0.0] * (end + 1)
    for start, src, vol, ratio, length in events:
        for j in range(length):
            k = int(j * ratio)
            if k >= len(src):
                break
            out[start + j] += src[k] * vol
    return out


def render_break(g, spec):
    parts = spec.split(":")
    bid = parts[0]
    kit = parts[1] if len(parts) > 1 else None
    hits = g.breakHits(bid, kit, 170, 2)
    write_wav("break_" + bid + ("_" + kit.replace(" ", "_").lower() if kit else ""), mix_hits(g, hits), True)


def main():
    os.chdir(ROOT)
    lua = LuaRuntime()
    g = lua.globals()
    g.TEST_EMBEDDED = True
    lua.execute(BOOT)
    args = sys.argv[1:] or ["patches", "drums", "breaks"]
    patches = lua_list(g.patchIds())
    drums = lua_list(g.drumIds())
    for arg in args:
        if arg == "patches":
            for pid in patches:
                render_patch(g, pid)
        elif arg == "drums":
            for did in drums:
                render_drum(g, did)
        elif arg == "breaks":
            for bid in lua_list(g.breakIds()):
                render_break(g, bid)
        elif arg.startswith("break:"):
            render_break(g, arg[len("break:"):])
        elif arg.startswith("kit:"):
            kit = arg[len("kit:"):]
            write_wav("kit_" + kit.replace(" ", "_").lower(), mix_hits(g, g.kitHits(kit, 170)), True)
        elif arg in patches:
            render_patch(g, arg)
        elif arg in drums:
            render_drum(g, arg)
        else:
            sys.exit("unknown sound: " + arg)


if __name__ == "__main__":
    main()
