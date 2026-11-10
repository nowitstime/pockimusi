-- ============================================================================
-- src/instruments/drums.lua — Customizable Drum Kit + Live Expression Compass
-- ============================================================================

local Config = require("src.config")
local Input  = require("src.input")
local Synth  = require("src.synth")
local Looper = require("src.looper")

local clamp      = Config.clamp
local math_floor = math.floor
local math_max   = math.max

local Drums = {
    id = "drums",
    name = "DRUMS",
    shortName = "DRUM",
    title = "DRUM MACHINE",
    defaultGridIndex = 3, -- 1/16
}

function Drums:newState()
    return {
        -- Each pad (B, Y, A, X) indexes into Synth.drumCatalog (1..24)
        padCatalogIndex = {
            B = 1,  -- 01. 808 SUB KICK
            Y = 6,  -- 06. ANALOG SNARE
            A = 11, -- 11. CLOSED HI-HAT
            X = 16, -- 16. STUDIO CLAP
        },
        browserPad = "B",
        browserTimer = 0.0,
        expressionName = "NORMAL (85%)",
        pitchSemis = 0,
        velocity = 0.85,
        decayMod = 1.0,
        repeatLabel = "1-SHOT",
        padFlash = { B = 0, Y = 0, A = 0, X = 0 },
    }
end

function Drums:getPadSound(state, padBtn)
    local idx = state.padCatalogIndex[padBtn] or 1
    return Synth.drumCatalog[idx] or Synth.drumCatalog[1]
end

function Drums:cyclePadSound(state, padBtn, delta)
    delta = delta or 1
    local total = #Synth.drumCatalog
    local cur = state.padCatalogIndex[padBtn] or 1
    local nextIdx = ((cur - 1 + delta) % total) + 1
    state.padCatalogIndex[padBtn] = nextIdx
    state.browserPad = padBtn
    state.browserTimer = 1.6
    local item = Synth.drumCatalog[nextIdx]
    Synth:trigger(item.id, 0, 0.90, 1.0)
    state.padFlash[padBtn] = 1.0
    Looper:showToast("PAD " .. padBtn .. " -> " .. item.full)
end

function Drums:getActionLabel(state, btn)
    return btn .. " (" .. self:getPadSound(state, btn).short .. ")"
end

function Drums:getSelectHint()
    return "CONFIGURE:  [B/Y/A/X] Pad Sound   [L1/R1] ◄/►   [U/D] BPM   [L/R] Key   [START] 2/4 Bars"
end

function Drums:handleSelectCombo(state)
    local used = false
    for _, btn in ipairs({ "B", "Y", "A", "X" }) do
        if Input.pressed[btn] then
            self:cyclePadSound(state, btn, 1)
            used = true
        end
    end
    if Input.pressed.L1 then
        self:cyclePadSound(state, state.browserPad or "B", -1)
        used = true
    elseif Input.pressed.R1 then
        self:cyclePadSound(state, state.browserPad or "B", 1)
        used = true
    end
    return used
end

function Drums:computeExpression(state)
    local u, d, l, r = Input.down.UP, Input.down.DOWN, Input.down.LEFT, Input.down.RIGHT
    local vel = 0.85
    local semis = 0
    local decay = 1.0
    local tags = {}

    if u then
        vel = 1.0
        decay = 1.25
        table.insert(tags, "ACCENT")
    elseif d then
        vel = 0.40
        decay = 0.65
        table.insert(tags, "GHOST")
    end

    if l then
        semis = -4
        decay = decay * 1.15
        table.insert(tags, "LOW -4st")
    elseif r then
        semis = 4
        decay = decay * 0.80
        table.insert(tags, "HI +4st")
    end

    state.velocity = vel
    state.pitchSemis = semis
    state.decayMod = decay
    state.expressionName = (#tags > 0) and table.concat(tags, " + ") or "NORMAL (85%)"
end

function Drums:updateVisuals(dt, state, controlsBlocked)
    if state.browserTimer > 0 then
        if Input.down.SELECT then
            state.browserTimer = math_max(state.browserTimer, 0.8)
        else
            state.browserTimer = math_max(0.0, state.browserTimer - dt)
        end
    end

    for k, v in pairs(state.padFlash) do
        state.padFlash[k] = math_max(0.0, v - dt * 5.5)
    end

    if controlsBlocked then
        state.expressionName = "NORMAL (85%)"
        state.pitchSemis = 0
        state.velocity = 0.85
        state.decayMod = 1.0
    end
end

function Drums:updateInput(dt, state, track, emitEvent)
    self:computeExpression(state)

    local l1, r1 = Input.down.L1, Input.down.R1
    local stepsPerBar = nil
    if l1 and r1 then
        local trackGrid = Looper:getTrackGrid(track.slot)
        if trackGrid.id == "1/12T" then
            stepsPerBar = 12
            state.repeatLabel = "1/12T ROLL"
        else
            stepsPerBar = 16
            state.repeatLabel = "1/16 ROLL"
        end
    elseif l1 then
        stepsPerBar = 4
        state.repeatLabel = "1/4 PULSE"
    elseif r1 then
        stepsPerBar = 8
        state.repeatLabel = "1/8 GROOVE"
    else
        state.repeatLabel = "1-SHOT"
    end

    local totalSubSteps = stepsPerBar and (stepsPerBar * Looper.bars) or nil
    local faceButtons = { "B", "A", "Y", "X" }

    for _, btn in ipairs(faceButtons) do
        if Input.pressed[btn] then
            state.browserPad = btn
            local padSound = self:getPadSound(state, btn)
            emitEvent({
                trackSlot = track.slot,
                instrumentId = self.id,
                action = btn,
                soundId = padSound.id,
                pitchSemis = state.pitchSemis,
                velocity = state.velocity,
                decayMod = state.decayMod,
                overrideGridSteps = totalSubSteps,
            }, false)
        end
    end

    if totalSubSteps and Looper.playing then
        local prevSubStep = math_floor(Looper.prevPhase * totalSubSteps)
        local currSubStep = math_floor(Looper.phase * totalSubSteps)
        if currSubStep ~= prevSubStep then
            for _, btn in ipairs(faceButtons) do
                if Input.down[btn] and not Input.pressed[btn] then
                    local padSound = self:getPadSound(state, btn)
                    emitEvent({
                        trackSlot = track.slot,
                        instrumentId = self.id,
                        action = btn,
                        soundId = padSound.id,
                        pitchSemis = state.pitchSemis,
                        velocity = state.velocity,
                        decayMod = state.decayMod,
                        overrideGridSteps = totalSubSteps,
                    }, false)
                end
            end
        end
    end
end

function Drums:triggerEvent(ev, state)
    local act   = ev.action
    local semis = ev.pitchSemis or 0
    local decay = ev.decayMod or 1.0
    local vel   = ev.velocity or 0.85
    local soundId = ev.soundId or self:getPadSound(state, act).id
    local track = Looper.tracks[ev.trackSlot or Looper.activeTrack]
    local trkVol = track and track.volume or 1.0
    Synth:trigger(soundId, semis, vel, decay, nil, trkVol)
    state.padFlash[act] = clamp(vel, 0.35, 1.0)
end

function Drums:drawSoundBrowser(state, Chrome)
    local C = Config.COLORS
    local padBtn = state.browserPad or "B"
    local padColors = { B = C.ORANGE, Y = C.CYAN, A = C.MINT, X = C.AMBER }
    local activeColor = padColors[padBtn] or C.CYAN

    local bx, by, bw, bh = 16, 60, 210, 252
    Chrome:setColor(C.BG)
    love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
    Chrome:setColor(activeColor)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", bx, by, bw, bh, 6, 6)
    love.graphics.setLineWidth(1)

    local total = #Synth.drumCatalog
    local curIdx = state.padCatalogIndex[padBtn] or 1

    Chrome:drawBadge(bx + 4, by + 4, bw - 8, 22,
        string.format("PAD [%s] SOUND (%02d/%02d)", padBtn, curIdx, total),
        activeColor, C.BG, Chrome.fontSmall)

    local rowStartY = by + 30
    local rowH = 24
    love.graphics.setFont(Chrome.fontSmall)

    for offset = -4, 4 do
        local rowIdx = ((curIdx - 1 + offset) % total) + 1
        local item = Synth.drumCatalog[rowIdx]
        local ry = rowStartY + (offset + 4) * rowH
        local isCurrent = (offset == 0)

        if isCurrent then
            Chrome:setColor(activeColor)
            love.graphics.rectangle("fill", bx + 6, ry, bw - 12, rowH - 2, 4, 4)
            Chrome:setColor(C.BG)
            love.graphics.print("► " .. item.full, bx + 10, ry + 5)
        else
            if offset % 2 == 0 then
                Chrome:setColor(C.PANEL, 0.65)
                love.graphics.rectangle("fill", bx + 6, ry, bw - 12, rowH - 2, 3, 3)
            end
            Chrome:setColor(offset > 0 and C.TEXT or C.MUTED)
            love.graphics.print("  " .. item.full, bx + 10, ry + 5)
        end

        local assignedPads = {}
        for _, pKey in ipairs({ "B", "Y", "A", "X" }) do
            if state.padCatalogIndex[pKey] == rowIdx then
                table.insert(assignedPads, pKey)
            end
        end
        if #assignedPads > 0 then
            local tag = "[" .. table.concat(assignedPads, ",") .. "]"
            local tw = Chrome.fontSmall:getWidth(tag)
            Chrome:setColor(isCurrent and C.BG or activeColor)
            love.graphics.print(tag, bx + bw - tw - 10, ry + 5)
        end
    end
end

function Drums:drawStage(state, track, Chrome)
    local C = Config.COLORS
    local isEraseMode = (Input.down.L2 and Input.down.R2)
    local isSelectMode = (Input.down.SELECT and not Input.down.L2)
    local isMuteMode = (Input.down.R2 and not Input.down.L2)
    local showSoundBrowser = (state.browserTimer > 0)

    if showSoundBrowser then
        self:drawSoundBrowser(state, Chrome)
    else
        Chrome:setColor(C.TEXT)
        love.graphics.setFont(Chrome.fontLarge)
        love.graphics.print(self.title, 22, 62)

        local l1 = Input.down.L1 and not isSelectMode
        local r1 = Input.down.R1 and not isSelectMode
        Chrome:drawBadge(22, 86, 56, 20, "L1: 1/4", l1 and not r1 and C.ORANGE or C.PANEL_HI, l1 and not r1 and C.BG or C.MUTED, Chrome.fontSmall)
        Chrome:drawBadge(82, 86, 56, 20, "R1: 1/8", r1 and not l1 and C.ORANGE or C.PANEL_HI, r1 and not l1 and C.BG or C.MUTED, Chrome.fontSmall)
        Chrome:drawBadge(142, 86, 68, 20, "BOTH:1/16", (l1 and r1) and C.ORANGE or C.PANEL_HI, (l1 and r1) and C.BG or C.MUTED, Chrome.fontSmall)

        local cx, cy, cr = 115, 196, 66
        Chrome:setColor(C.BG)
        love.graphics.circle("fill", cx, cy, cr)
        Chrome:setColor(C.GRID)
        love.graphics.circle("line", cx, cy, cr)

        Chrome:setColor(C.PANEL_HI)
        love.graphics.line(cx - cr + 8, cy, cx + cr - 8, cy)
        love.graphics.line(cx, cy - cr + 8, cx, cy + cr - 8)

        local expNodes = {
            { key = "UP",    label = "ACCENT",  dx = 0,   dy = -44, active = Input.down.UP,    color = C.ORANGE },
            { key = "DOWN",  label = "GHOST",   dx = 0,   dy = 44,  active = Input.down.DOWN,  color = C.CYAN   },
            { key = "LEFT",  label = "LOW -4",  dx = -44, dy = 0,   active = Input.down.LEFT,  color = C.VIOLET },
            { key = "RIGHT", label = "HI +4",   dx = 44,  dy = 0,   active = Input.down.RIGHT, color = C.MINT   },
        }

        love.graphics.setFont(Chrome.fontSmall)
        for _, n in ipairs(expNodes) do
            local nx = cx + n.dx
            local ny = cy + n.dy
            if n.active and not isSelectMode and not isMuteMode then
                Chrome:setColor(n.color)
                love.graphics.rectangle("fill", nx - 28, ny - 10, 56, 20, 4, 4)
                Chrome:setColor(C.BG)
            else
                Chrome:setColor(C.PANEL_HI)
                love.graphics.rectangle("fill", nx - 28, ny - 10, 56, 20, 4, 4)
                Chrome:setColor(C.TEXT)
            end
            local tw = Chrome.fontSmall:getWidth(n.label)
            love.graphics.print(n.label, math_floor(nx - tw * 0.5), math_floor(ny - 6))
        end

        local anyDpad = Input.down.UP or Input.down.DOWN or Input.down.LEFT or Input.down.RIGHT
        Chrome:setColor(anyDpad and C.DIM or C.TEXT)
        love.graphics.circle("fill", cx, cy, 5)

        Chrome:drawBadge(22, 272, 188, 22, "D-PAD: " .. state.expressionName, C.PANEL_HI, C.TEXT, Chrome.fontSmall)
    end

    local pxCenter, pyCenter = 428, 186
    local pads = {
        { btn = "X", posLabel = "X (TOP)",    dx = 0,    dy = -76, color = C.AMBER,  muteTrack = 4 },
        { btn = "Y", posLabel = "Y (LEFT)",   dx = -108, dy = 0,   color = C.CYAN,   muteTrack = 3 },
        { btn = "A", posLabel = "A (RIGHT)",  dx = 108,  dy = 0,   color = C.MINT,   muteTrack = 2 },
        { btn = "B", posLabel = "B (BOTTOM)", dx = 0,    dy = 76,  color = C.ORANGE, muteTrack = 1 },
    }

    love.graphics.setFont(Chrome.fontSmall)
    local topHint = "L1: 1/4 PULSE   •   R1: 1/8 GROOVE   •   L1+R1: 1/16"
    local topColor = C.MUTED
    if isEraseMode then
        topHint = "▼ [B / Y / A / X] ERASE PAD   •   [LEFT] UNDO ▼"
        topColor = C.RED
    elseif showSoundBrowser or isSelectMode then
        topHint = "▼ [B / Y / A / X] PAD SOUND   •   [L1 / R1] ◄/► ▼"
        topColor = C.CYAN
    elseif isMuteMode then
        topHint = "▼ [B / A / Y / X] MUTE TRACK 1-4 ▼"
        topColor = C.AMBER
    end
    Chrome:setColor(topColor)
    local thw = Chrome.fontSmall:getWidth(topHint)
    love.graphics.print(topHint, math_floor(pxCenter - thw * 0.5), 64)

    for _, p in ipairs(pads) do
        local flash = state.padFlash[p.btn] or 0.0
        local px = pxCenter + p.dx
        local py = pyCenter + p.dy
        local w = 138 + flash * 10
        local h = 62 + flash * 6

        local soundItem = self:getPadSound(state, p.btn)
        local hitCount = Looper:countTrackAction(track.slot, p.btn)
        local padColor = p.color
        local isFocusedInBrowser = showSoundBrowser and (state.browserPad == p.btn)

        if isEraseMode then
            padColor = C.RED
        elseif isFocusedInBrowser then
            padColor = p.color
        elseif isSelectMode then
            padColor = C.CYAN
        elseif isMuteMode then
            padColor = C.AMBER
        end

        Chrome:setColor(C.BG)
        love.graphics.rectangle("fill", px - w * 0.5, py - h * 0.5, w, h, 8, 8)

        if flash > 0.02 or isEraseMode or isFocusedInBrowser or isMuteMode then
            local fillAlpha = (flash > 0.02) and (0.25 + flash * 0.55) or (isFocusedInBrowser and 0.24 or 0.14)
            Chrome:setColor(padColor, fillAlpha)
            love.graphics.rectangle("fill", px - w * 0.5, py - h * 0.5, w, h, 8, 8)
        end

        Chrome:setColor((flash > 0.08 or isEraseMode or isSelectMode or isFocusedInBrowser or isMuteMode) and padColor or C.GRID)
        love.graphics.setLineWidth((flash > 0.08 or isEraseMode or isFocusedInBrowser) and 2.5 or 1.5)
        love.graphics.rectangle("line", px - w * 0.5, py - h * 0.5, w, h, 8, 8)

        love.graphics.setFont(Chrome.fontSmall)
        Chrome:setColor(padColor)
        love.graphics.print(p.btn, math_floor(px - w * 0.5 + 10), math_floor(py - h * 0.5 + 7))

        local countStr = isMuteMode
            and (Looper.tracks[p.muteTrack].muted and "MUTED" or "ACTIVE")
            or (hitCount > 0 and (hitCount .. " hits") or "empty")
        local cw = Chrome.fontSmall:getWidth(countStr)
        Chrome:setColor(hitCount > 0 and C.TEXT or C.DIM)
        love.graphics.print(countStr, math_floor(px + w * 0.5 - cw - 8), math_floor(py - h * 0.5 + 7))

        love.graphics.setFont(Chrome.fontMed)
        local mainLabel = soundItem.short
        if isEraseMode then
            mainLabel = "ERASE " .. p.btn
        elseif showSoundBrowser or isSelectMode then
            mainLabel = isFocusedInBrowser and ("◄ " .. soundItem.short .. " ►") or soundItem.short
        elseif isMuteMode then
            mainLabel = "MUTE TRK " .. p.muteTrack
        end
        Chrome:setColor(C.TEXT)
        local mw = Chrome.fontMed:getWidth(mainLabel)
        love.graphics.print(mainLabel, math_floor(px - mw * 0.5), math_floor(py + 2))
    end
    love.graphics.setLineWidth(1)
end

return Drums
