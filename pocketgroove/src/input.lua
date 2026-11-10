-- ============================================================================
-- src/input.lua — Hardware Input Abstraction (Gamepad + Keyboard + Hold Timers)
-- ============================================================================

local Input = {
    BUTTON_LIST = {
        "UP", "DOWN", "LEFT", "RIGHT",
        "B", "A", "Y", "X",
        "L1", "R1", "L2", "R2",
        "SELECT", "START"
    },
    down = {},
    pressed = {},
    released = {},
    selectComboUsed = false,
    selectHoldTime = 0.0,
    l2ComboUsed = false,
    r2ComboUsed = false,
    lastStartTapTime = -10.0,
}

for _, btn in ipairs(Input.BUTTON_LIST) do
    Input.down[btn] = false
    Input.pressed[btn] = false
    Input.released[btn] = false
end

Input.KEY_MAP = {
    UP     = { "w" },
    DOWN   = { "s" },
    LEFT   = { "a" },
    RIGHT  = { "d" },
    B      = { "j", "down" },
    A      = { "k", "right" },
    Y      = { "u", "left" },
    X      = { "i", "up" },
    L1     = { "q" },
    R1     = { "e" },
    L2     = { "lshift", "rshift" },
    R2     = { "space" },
    SELECT = { "tab" },
    START  = { "return", "kpenter" },
}

Input.GAMEPAD_MAP = {
    UP     = { "dpup" },
    DOWN   = { "dpdown" },
    LEFT   = { "dpleft" },
    RIGHT  = { "dpright" },
    B      = { "a" },
    A      = { "b" },
    Y      = { "x" },
    X      = { "y" },
    L1     = { "leftshoulder" },
    R1     = { "rightshoulder" },
    L2     = { "leftstick" },
    R2     = { "rightstick" },
    SELECT = { "back", "guide" },
    START  = { "start" },
}

function Input:pollRawButton(btn)
    local keys = self.KEY_MAP[btn]
    if keys then
        for i = 1, #keys do
            if love.keyboard.isDown(keys[i]) then
                return true
            end
        end
    end

    local joysticks = love.joystick.getJoysticks()
    for _, js in ipairs(joysticks) do
        if js:isGamepad() then
            local gpButtons = self.GAMEPAD_MAP[btn]
            if gpButtons then
                for i = 1, #gpButtons do
                    if js:isGamepadDown(gpButtons[i]) then
                        return true
                    end
                end
            end
            if btn == "LEFT" and js:getGamepadAxis("leftx") < -0.45 then return true end
            if btn == "RIGHT" and js:getGamepadAxis("leftx") > 0.45 then return true end
            if btn == "UP" and js:getGamepadAxis("lefty") < -0.45 then return true end
            if btn == "DOWN" and js:getGamepadAxis("lefty") > 0.45 then return true end
            if btn == "L2" and js:getGamepadAxis("triggerleft") > 0.45 then return true end
            if btn == "R2" and js:getGamepadAxis("triggerright") > 0.45 then return true end
        end
    end

    return false
end

function Input:update(dt)
    for _, btn in ipairs(self.BUTTON_LIST) do
        local isNowDown = self:pollRawButton(btn)
        local wasDown = self.down[btn]
        self.pressed[btn]  = (isNowDown and not wasDown)
        self.released[btn] = (not isNowDown and wasDown)
        self.down[btn]     = isNowDown
    end

    if self.pressed.SELECT then
        self.selectHoldTime = 0.0
    elseif self.down.SELECT then
        self.selectHoldTime = self.selectHoldTime + (dt or 0.016)
    end
end

function Input:get8WayDirection()
    local u = self.down.UP
    local d = self.down.DOWN
    local l = self.down.LEFT
    local r = self.down.RIGHT

    if u and l then return "UP_LEFT" end
    if u and r then return "UP_RIGHT" end
    if d and l then return "DOWN_LEFT" end
    if d and r then return "DOWN_RIGHT" end
    if u then return "UP" end
    if d then return "DOWN" end
    if l then return "LEFT" end
    if r then return "RIGHT" end
    return "NEUTRAL"
end

return Input
