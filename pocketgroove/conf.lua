-- PocketGroove — LÖVE (Love2D 11.x) Configuration
-- Target: Anbernic RG35XX Plus (640x480 4:3 IPS) & Desktop PC

function love.conf(t)
    t.identity = "pocketgroove"
    t.appendidentity = true
    t.version = "11.5"
    t.console = false

    t.audio.mixwithsystem = true

    t.window.title = "PocketGroove — 4-Track Handheld Groovebox"
    t.window.width = 640
    t.window.height = 480
    t.window.resizable = true
    t.window.minwidth = 640
    t.window.minheight = 480
    t.window.vsync = 1
    t.window.msaa = 2

    t.modules.audio = true
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = true
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.physics = false
    t.modules.sound = true
    t.modules.system = true
    t.modules.thread = false
    t.modules.timer = true
    t.modules.touch = false
    t.modules.video = false
    t.modules.window = true
end
