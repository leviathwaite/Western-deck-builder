local json = require("json")

local Weapons = {}

function Weapons.loadAll()
    local raw = love.filesystem.read("weapons.json")
    local data = json.decode(raw)
    data.byId = {}
    for _, weapon in ipairs(data.weapons) do
        data.byId[weapon.id] = weapon
    end
    return data
end

return Weapons
