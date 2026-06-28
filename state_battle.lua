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
        object = {kind = "rock", relx = 0.35, rely = 0.70, scale = 1.0}
    elseif positioningType == "hide" then
        object = {kind = "bush", relx = 0.34, rely = 0.64, scale = 1.0}
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

function BattleState:drawFieldObjects(fieldX, fieldY, fieldW, fieldH)
    for _, obj in ipairs(self.fieldObjects) do
        local x = fieldX + fieldW * obj.relx
        local y = fieldY + fieldH * obj.rely
        if obj.kind == "rock" then
            local rx = math.max(24, fieldW * 0.09 * obj.scale)
            local ry = math.max(14, fieldH * 0.10 * obj.scale)
            love.graphics.setColor(0.42, 0.40, 0.38)
            love.graphics.ellipse("fill", x, y, rx, ry)
            love.graphics.setColor(0.30, 0.28, 0.27)
            love.graphics.ellipse("line", x, y, rx, ry)
        elseif obj.kind == "bush" then
            local radius = math.max(16, fieldW * 0.045 * obj.scale)
            love.graphics.setColor(0.22, 0.42, 0.20)
            love.graphics.circle("fill", x, y, radius)
            love.graphics.circle("fill", x + radius * 0.9, y + radius * 0.25, radius * 0.9)
            love.graphics.circle("fill", x - radius * 0.85, y + radius * 0.3, radius * 0.8)
            love.graphics.setColor(0.16, 0.30, 0.14)
            love.graphics.rectangle("fill", x - 4, y + radius * 0.6, 8, radius)
        end
    end
end

function BattleState:drawStatBox(label, value, x, y, w, h)
    love.graphics.setColor(0.22, 0.16, 0.12)
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    love.graphics.setColor(0.95, 0.90, 0.82)
    love.graphics.setFont(self.shared.fonts.small)
    love.graphics.printf(label, x, y + 8, w, "center")
    love.graphics.setFont(self.shared.fonts.medium)
    love.graphics.printf(value, x, y + 28, w, "center")
end

function BattleState:drawCard(card, index, x, y, width, height)
    local selected = index == self.selectedCardIndex
    local playable = card.cost <= self.player.grit
    local bg = selected and {0.52, 0.35, 0.22} or {0.25, 0.18, 0.14}
    if not playable then
        bg = selected and {0.32, 0.20, 0.20} or {0.18, 0.13, 0.13}
    end

    love.graphics.setColor(bg)
    love.graphics.rectangle("fill", x, y, width, height, 10, 10)

    love.graphics.setColor(0.95, 0.90, 0.82)
    love.graphics.setFont(self.shared.fonts.small)
    love.graphics.printf(card.name, x + 10, y + 10, width - 60, "left")

    local costW = 34
    local costH = 28
    love.graphics.setColor(0.86, 0.70, 0.34)
    love.graphics.rectangle("fill", x + width - costW - 10, y + 10, costW, costH, 6, 6)
    love.graphics.setColor(0.16, 0.10, 0.06)
    love.graphics.setFont(self.shared.fonts.medium)
    love.graphics.printf(tostring(card.cost), x + width - costW - 10, y + 13, costW, "center")

    love.graphics.setColor(0.95, 0.90, 0.82)
    love.graphics.setFont(self.shared.fonts.small)
    love.graphics.printf(card.text, x + 10, y + 48, width - 20, "left")

    local infoY = y + height - 42
    if card.weapon then
        love.graphics.printf("Weapon: " .. card.weapon, x + 10, infoY, width - 20, "left")
        infoY = infoY + 16
    end
    if card.effects and card.effects.positioning then
        love.graphics.printf("Position: " .. card.effects.positioning, x + 10, infoY, width - 20, "left")
    end
end

function BattleState:draw()
    local screenW = self.shared.screen.width
    local screenH = self.shared.screen.height
    local margin = 20
    local gap = 10
    local contentW = screenW - margin * 2

    love.graphics.setBackgroundColor(0.12, 0.09, 0.07)
    love.graphics.setColor(0.95, 0.88, 0.76)
    love.graphics.setFont(self.shared.fonts.large)
    love.graphics.printf("High Noon", margin, 18, contentW, "center")

    local statY = 68
    local statW = math.floor((contentW - gap) / 2)
    local statH = 62
    self:drawStatBox("Player HP", self.player.hp .. "/" .. self.player.maxHp, margin, statY, statW, statH)
    self:drawStatBox("Enemy HP", self.enemy.hp .. "/" .. self.enemy.maxHp, margin + statW + gap, statY, statW, statH)

    local row2Y = statY + statH + 8
    local smallStatW = math.floor((contentW - gap * 2) / 3)
    self:drawStatBox("Grit", self.player.grit .. "/" .. self.player.maxGrit, margin, row2Y, smallStatW, statH)
    self:drawStatBox("Block", tostring(self.player.block), margin + smallStatW + gap, row2Y, smallStatW, statH)
    self:drawStatBox("Bleed", tostring(self.enemy.bleed), margin + (smallStatW + gap) * 2, row2Y, smallStatW, statH)

    local intentY = row2Y + statH + 8
    self:drawStatBox("Enemy Intent", self.enemy.intent.type .. " " .. self.enemy.intent.value, margin, intentY, contentW, 58)

    local fieldY = intentY + 70
    local fieldH = 170
    love.graphics.setColor(0.58, 0.47, 0.30)
    love.graphics.rectangle("fill", margin, fieldY, contentW, fieldH, 12, 12)
    love.graphics.setColor(0.82, 0.72, 0.54)
    love.graphics.setFont(self.shared.fonts.medium)
    love.graphics.printf("Street", margin, fieldY + 10, contentW, "center")
    self:drawFieldObjects(margin, fieldY, contentW, fieldH)

    local pileY = fieldY + fieldH + 10
    self:drawStatBox("Draw", tostring(#self.deck.drawPile), margin, pileY, smallStatW, 54)
    self:drawStatBox("Discard", tostring(#self.deck.discardPile), margin + smallStatW + gap, pileY, smallStatW, 54)
    self:drawStatBox("Hand", tostring(#self.hand), margin + (smallStatW + gap) * 2, pileY, smallStatW, 54)

    local messageY = pileY + 64
    love.graphics.setColor(0.90, 0.84, 0.70)
    love.graphics.setFont(self.shared.fonts.small)
    love.graphics.printf(self.turnMessage, margin, messageY, contentW, "center")

    local controlsY = messageY + 38
    love.graphics.printf("Left/Right select | Space play | E end turn | Enter continue", margin, controlsY, contentW, "center")

    local cardsTop = controlsY + 34
    local bottomPadding = 20
    local availableH = screenH - cardsTop - bottomPadding
    local cardGap = 8
    local cardsPerRow = math.min(2, math.max(1, #self.hand))
    local rows = math.max(1, math.ceil(math.max(1, #self.hand) / cardsPerRow))
    local cardW = math.floor((contentW - cardGap * (cardsPerRow - 1)) / cardsPerRow)
    local cardH = math.floor((availableH - cardGap * (rows - 1)) / rows)
    cardH = math.max(120, math.min(cardH, 180))

    for i, card in ipairs(self.hand) do
        local row = math.floor((i - 1) / cardsPerRow)
        local col = (i - 1) % cardsPerRow
        local x = margin + col * (cardW + cardGap)
        local y = cardsTop + row * (cardH + cardGap)
        self:drawCard(card, i, x, y, cardW, cardH)
    end
end

return BattleState
