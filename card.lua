local json = require("json")

local Card = {
    definitions = nil,
    byId = {}
}

local function loadDefinitions()
    if Card.definitions then
        return
    end
    local raw = love.filesystem.read("cards.json")
    Card.definitions = json.decode(raw)
    Card.byId = {}
    for _, card in ipairs(Card.definitions.cards) do
        Card.byId[card.id] = card
    end
end

function Card.getDefinition(id)
    loadDefinitions()
    return Card.byId[id]
end

function Card.instantiate(def)
    return {
        id = def.id,
        name = def.name,
        cost = def.cost,
        type = def.type,
        weapon = def.weapon,
        text = def.text,
        effects = def.effects or {}
    }
end

return Card
