function love.conf(t)
    t.identity = "western_deck_builder"
    t.version = "11.5"
    t.console = false

    t.window.title = "Western Deck Builder"
    t.window.width = 720
    t.window.height = 1280
    t.window.resizable = false
    t.window.minwidth = 720
    t.window.minheight = 1280

    t.modules.joystick = false
    t.modules.physics = false
end
