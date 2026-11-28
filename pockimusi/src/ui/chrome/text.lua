-- Text helpers shared by the stage views

local math_floor = math.floor

local M = {}

function M.printRight(self, text, x, y)
    love.graphics.print(text, math_floor(x - self.fontTiny:getWidth(text)), y)
end

function M.printCentre(self, font, text, x, y)
    love.graphics.print(text, math_floor(x - font:getWidth(text) * 0.5), y)
end


return M
