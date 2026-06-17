local Player = require("player")
local Enemy = require("enemy")
local Deck = require("deck")
local Card = require("card")
local Weapons = require("weapons")

local BattleState = {}
BattleState.__index = BattleState

function BattleState.new(shared, runData, onReturn)
    local self = setmetatable({}, BattleState)
    self.shared = shared
    self.onReturn = onReturn
    self.weaponData = Weapons.loadAll()
    self.player = Player.fromRunData(self.weaponData, runData)
    self.enemy = Enemy.create("deputy_hunter")
    self.turnMessage = "A bounty hunter steps into the street."
    self.selectedCardIndex = 1
    self.pendingGameOver = false
    self.fieldObjects = {}
    self:buildStartingDeck()
    self:startBattle()
    return self
end

function BattleState:buildStartingDeck()
    local cards = {}
    for _, weaponId in ipairs(self.player:getEquippedWeapons()) do
        local weapon = self.weaponData.byId[weaponId]
        if weapon and weapon.cards then
            for _, cardId in ipairs(weapon.cards) do
                local cardDef = Card.getDefinition(cardId)
                if cardDef then
                    table.insert(cards, Card.instantiate(cardDef))
                end
            end
        end
    end

    for _, cardId in ipairs({"take_cover", "hide_in_brush", "steady_breath", "quick_step", "grit"}) do
        local cardDef = Card.getDefinition(cardId)
        if cardDef then
            table.insert(cards, Card.instantiate(cardDef))
        end
    end

    self.deck = Deck.new(cards)
end

function BattleState:startBattle()
    self.player:resetTurnGrit()
    self.deck:shuffleDiscardIntoDrawIfNeeded()
    self.hand = self.deck:draw(self.player.handSize)
    self.enemy:rollIntent()
end

function BattleState:update(dt)
end

function BattleState:keypressed(key)
    if self.pendingGameOver and (key == "return" or key == "kpenter") then
        self.onReturn()
        return
    end

    if key == "left" then
        self.selectedCardIndex = math.max(1, self.selectedCardIndex - 1)
    elseif key == "right" then
        self.selectedCardIndex = math.min(#self.hand, self.selectedCardIndex + 1)
    elseif key == "space" then
        self:playSelectedCard()
    elseif key == "e" then
        self:endTurn()
    end
end

function BattleState:playSelectedCard()
    local card = self.hand[self.selectedCardIndex]
    if not card then
        self.turnMessage = "No card selected."
        return
    end

    if card.cost > self.player.grit then
        self.turnMessage = "Not enough grit."
        return
    end

    local ok, reason = self.player:canPlayCard(card)
    if not ok then
        self.turnMessage = reason
        return
    end

    self.player:spendGrit(card.cost)
    self:resolveCard(card)
    table.remove(self.hand, self.selectedCardIndex)
    self.deck:addToDiscard(card)
    if self.selectedCardIndex > #self.hand then
        self.selectedCardIndex = math.max(1, #self.hand)
    end

    if self.enemy.hp <= 0 then
        self.turnMessage = "You won the fight. Press Enter to return to loadout."
        self.pendingGameOver = true
    end
end

function BattleState:resolveCard(card)
    if card.effects.damage then
        local dmg = card.effects.damage + self.player:getBonusDamage(card)
        self.enemy:takeDamage(dmg)
        self.turnMessage = "Played " .. card.name .. " for " .. dmg .. " damage."
    else
        self.turnMessage = "Played " .. card.name .. "."
    end

    if card.effects.block then
        self.player.block = self.player.block + card.effects.block
        self.turnMessage = self.turnMessage .. " Gained " .. card.effects.block .. " block."
    end
    if card.effects.draw then
        local drawn = self.deck:draw(card.effects.draw)
        for _, c in ipairs(drawn) do table.insert(self.hand, c) end
        self.turnMessage = self.turnMessage .. " Drew " .. #drawn .. " card(s)."
    end
    if card.effects.bleed then
        self.enemy.bleed = self.enemy.bleed + card.effects.bleed
        self.turnMessage = self.turnMessage .. " Applied bleed " .. card.effects.bleed .. "."
    end
    if card.effects.ammo_restore then
        self.player:restoreAmmo(card.weapon, card.effects.ammo_restore)
        self.turnMessage = self.turnMessage .. " Reloaded " .. tostring(card.effects.ammo_restore) .. "."
    end
    if card.effects.positioning then
        self:spawnFieldObject(card.effects.positioning)
        self.turnMessage = self.turnMessage .. " Took a " .. card.effects.positioning .. " position."
    end
    self.player:consumeAmmoForCard(card)
end

function BattleState:spawnFieldObject(positioningType)
    local object = nil
    if positioningType == "cover" then
        object = {kind = "rock", x = 250, y = 305, w = 90, h = 55}
    elseif positioningType == "hide" then
        object = {kind = "bush", x = 230, y = 280, w = 120, h = 90}
    end

    if object then
        table.insert(self.fieldObjects, object)
    end
end

function BattleState:endTurn()
    self.deck:discardHand(self.hand)
    self.hand = {}

    if self.enemy.bleed > 0 then
        self.enemy:takeDamage(self.enemy.bleed)
    end

    if self.enemy.hp <= 0 then
        self.turnMessage = "The enemy bleeds out. Press Enter to return to loadout."
        self.pendingGameOver = true
        return
    end

    local intentValue = self.enemy.intent.value
    if self.enemy.intent.type == "attack" then
        self.player:takeDamage(intentValue)
        self.turnMessage = self.enemy.name .. " attacks for " .. intentValue .. "."
    elseif self.enemy.intent.type == "guard" then
        self.enemy.block = self.enemy.block + intentValue
        self.turnMessage = self.enemy.name .. " takes cover for " .. intentValue .. " block."
    end

    if self.player.hp <= 0 then
        self.turnMessage = "You were defeated. Press Enter to return to loadout."
        self.pendingGameOver = true
        return
    end

    self.player.block = 0
    self.enemy.block = 0
    self.player:resetTurnGrit()
    self.hand = self.deck:draw(self.player.handSize)
    self.enemy:rollIntent()
    self.selectedCardIndex = 1
end

function BattleState:drawFieldObjects()
    for _, obj in ipairs(self.fieldObjects) do
        if obj.kind == "rock" then
            love.graphics.setColor(0.42, 0.40, 0.38)
            love.graphics.ellipse("fill", obj.x, obj.y, obj.w / 2, obj.h / 2)
            love.graphics.setColor(0.30, 0.28, 0.27)
            love.graphics.ellipse("line", obj.x, obj.y, obj.w / 2, obj.h / 2)
        elseif obj.kind == "bush" then
            love.graphics.setColor(0.22, 0.42, 0.20)
            love.graphics.circle("fill", obj.x, obj.y, 34)
            love.graphics.circle("fill", obj.x + 28, obj.y + 8, 30)
            love.graphics.circle("fill", obj.x - 26, obj.y + 10, 28)
            love.graphics.setColor(0.16, 0.30, 0.14)
            love.graphics.rectangle("fill", obj.x - 6, obj.y + 25, 12, 30)
        end
    end
end

function BattleState:draw()
    love.graphics.setBackgroundColor(0.12, 0.09, 0.07)
    love.graphics.setColor(0.95, 0.88, 0.76)
    love.graphics.setFont(self.shared.fonts.large)
    love.graphics.print("High Noon", 35, 20)

    love.graphics.setFont(self.shared.fonts.medium)
    love.graphics.print("Player HP: " .. self.player.hp .. "/" .. self.player.maxHp, 40, 80)
    love.graphics.print("Grit: " .. self.player.grit .. "/" .. self.player.maxGrit, 40, 110)
    love.graphics.print("Block: " .. self.player.block, 40, 140)
    love.graphics.print("Hand Size: " .. self.player.handSize, 40, 170)

    love.graphics.print(self.enemy.name .. " HP: " .. self.enemy.hp .. "/" .. self.enemy.maxHp, 720, 80)
    love.graphics.print("Intent: " .. self.enemy.intent.type .. " " .. self.enemy.intent.value, 720, 110)
    love.graphics.print("Bleed: " .. self.enemy.bleed, 720, 140)

    love.graphics.print("Weapons:", 40, 220)
    local wy = 255
    for _, line in ipairs(self.player:getWeaponStatusLines()) do
        love.graphics.print(line, 60, wy)
        wy = wy + 26
    end

    love.graphics.setColor(0.58, 0.47, 0.30)
    love.graphics.rectangle("fill", 160, 295, 770, 95, 10, 10)
    love.graphics.setColor(0.82, 0.72, 0.54)
    love.graphics.print("Street", 520, 330)
    self:drawFieldObjects()

    love.graphics.setColor(0.95, 0.88, 0.76)
    love.graphics.print("Draw Pile: " .. #self.deck.drawPile, 40, 355)
    love.graphics.print("Discard Pile: " .. #self.deck.discardPile, 220, 355)
    love.graphics.print("Cards in Hand: " .. #self.hand, 430, 355)

    love.graphics.print("Hand:", 40, 385)
    local cardWidth = 180
    for i, card in ipairs(self.hand) do
        local x = 40 + (i - 1) * (cardWidth + 10)
        local y = 420
        local selected = i == self.selectedCardIndex
        local playable = card.cost <= self.player.grit
        local bg = selected and {0.52, 0.35, 0.22} or {0.25, 0.18, 0.14}
        if not playable then
            bg = selected and {0.32, 0.20, 0.20} or {0.18, 0.13, 0.13}
        end
        love.graphics.setColor(bg)
        love.graphics.rectangle("fill", x, y, cardWidth, 220, 8, 8)

        love.graphics.setColor(0.95, 0.90, 0.82)
        love.graphics.setFont(self.shared.fonts.medium)
        love.graphics.print(card.name, x + 10, y + 10)

        love.graphics.setColor(0.86, 0.70, 0.34)
        love.graphics.rectangle("fill", x + 135, y + 10, 32, 28, 6, 6)
        love.graphics.setColor(0.16, 0.10, 0.06)
        love.graphics.setFont(self.shared.fonts.medium)
        love.graphics.print(tostring(card.cost), x + 146, y + 13)

        love.graphics.setColor(0.95, 0.90, 0.82)
        love.graphics.setFont(self.shared.fonts.small)
        love.graphics.printf(card.text, x + 10, y + 70, cardWidth - 20)
        if card.weapon then
            love.graphics.print("Weapon: " .. card.weapon, x + 10, y + 180)
        end
        if card.effects and card.effects.positioning then
            love.graphics.print("Positioning: " .. card.effects.positioning, x + 10, y + 198)
        end
    end

    love.graphics.setColor(0.92, 0.86, 0.76)
    love.graphics.setFont(self.shared.fonts.small)
    love.graphics.print(self.turnMessage, 40, 650)
    love.graphics.print("Controls: Left/Right select card, Space play card, E end turn, Enter continue after combat", 40, 675)
end

return BattleState
