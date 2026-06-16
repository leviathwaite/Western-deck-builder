local Deck = {}
Deck.__index = Deck

local function shuffle(list)
    for i = #list, 2, -1 do
        local j = love.math.random(i)
        list[i], list[j] = list[j], list[i]
    end
end

function Deck.new(cards)
    local self = setmetatable({}, Deck)
    self.drawPile = {}
    self.discardPile = {}
    for _, card in ipairs(cards or {}) do
        table.insert(self.drawPile, card)
    end
    shuffle(self.drawPile)
    return self
end

function Deck:shuffleDiscardIntoDrawIfNeeded()
    if #self.drawPile == 0 and #self.discardPile > 0 then
        for _, card in ipairs(self.discardPile) do
            table.insert(self.drawPile, card)
        end
        self.discardPile = {}
        shuffle(self.drawPile)
    end
end

function Deck:draw(amount)
    local cards = {}
    for _ = 1, amount do
        self:shuffleDiscardIntoDrawIfNeeded()
        if #self.drawPile == 0 then break end
        table.insert(cards, table.remove(self.drawPile, 1))
    end
    return cards
end

function Deck:addToDiscard(card)
    table.insert(self.discardPile, card)
end

function Deck:discardHand(hand)
    for _, card in ipairs(hand) do
        self:addToDiscard(card)
    end
end

return Deck
