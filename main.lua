local Game = require("game")

function love.load()
    love.window.setTitle("Western Deck Builder")
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

function love.mousepressed(x, y, button)
    if Game.mousepressed then
        Game:mousepressed(x, y, button)
    end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    if Game.mousepressed then
        Game:mousepressed(x, y, 1)
    end
end
