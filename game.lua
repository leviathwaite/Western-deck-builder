local LoadoutState = require("state_loadout")
local BattleState = require("state_battle")

local Game = {
    stateName = "loadout",
    state = nil,
    shared = {}
}

function Game:init()
    local width, height = love.graphics.getDimensions()
    self.shared = {
        screen = {
            width = width,
            height = height
        },
        fonts = {
            large = love.graphics.newFont(26),
            medium = love.graphics.newFont(18),
            small = love.graphics.newFont(14)
        },
        runConfig = {}
    }
    self:switchState("loadout")
end

function Game:switchState(name, params)
    self.stateName = name
    if name == "loadout" then
        self.state = LoadoutState.new(self.shared, function(runData)
            self:switchState("battle", runData)
        end)
    elseif name == "battle" then
        self.state = BattleState.new(self.shared, params, function()
            self:switchState("loadout")
        end)
    end
end

function Game:update(dt)
    if self.state and self.state.update then
        self.state:update(dt)
    end
end

function Game:draw()
    if self.state and self.state.draw then
        self.state:draw()
    end
end

function Game:keypressed(key)
    if self.state and self.state.keypressed then
        self.state:keypressed(key)
    end
end

return Game
