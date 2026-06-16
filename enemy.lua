local json = require("json")

local Enemy = {}
Enemy.__index = Enemy
Enemy.definitions = nil
Enemy.byId = {}

local function loadDefinitions()
    if Enemy.definitions then
        return
    end
    local raw = love.filesystem.read("enemies.json")
    Enemy.definitions = json.decode(raw)
    Enemy.byId = {}
    for _, enemy in ipairs(Enemy.definitions.enemies) do
        Enemy.byId[enemy.id] = enemy
    end
end

function Enemy.create(id)
    loadDefinitions()
    local def = Enemy.byId[id]
    local self = setmetatable({}, Enemy)
    self.id = def.id
    self.name = def.name
    self.maxHp = def.hp
    self.hp = def.hp
    self.block = 0
    self.bleed = 0
    self.intents = def.intents or {}
    self.intentIndex = 1
    self.intent = {type = "attack", value = 0}
    return self
end

function Enemy:rollIntent()
    if #self.intents == 0 then
        self.intent = {type = "attack", value = 5}
        return
    end
    self.intent = self.intents[self.intentIndex]
    self.intentIndex = self.intentIndex + 1
    if self.intentIndex > #self.intents then
        self.intentIndex = 1
    end
end

function Enemy:takeDamage(amount)
    local remaining = amount
    if self.block > 0 then
        local absorbed = math.min(self.block, remaining)
        self.block = self.block - absorbed
        remaining = remaining - absorbed
    end
    self.hp = math.max(0, self.hp - remaining)
end

return Enemy
