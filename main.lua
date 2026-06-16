local Game = require("game")

function love.load()
    love.window.setTitle("Western Deck Builder")
    love.window.setMode(1100, 700, {resizable = false})
    Game:init()
end

function love.update(dt)
    Game:update(dt)
end

function love.draw()
    Game:draw()
end

function love.keypressed(key)
    Game:keypressed(key)
end
