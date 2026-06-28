local Player = require("player")
local Weapons = require("weapons")

local LoadoutState = {}
LoadoutState.__index = LoadoutState

function LoadoutState.new(shared, onStartRun)
    local self = setmetatable({}, LoadoutState)
    self.shared = shared
    self.onStartRun = onStartRun
    self.weaponData = Weapons.loadAll()
    self.player = Player.new(self.weaponData)
    self.message = "Choose equipment, then press ENTER to start. Press A/D to change weapon in selected slot."
    self.selectedSlotIndex = 1
    self.slotOrder = {"left_holster", "right_holster", "knife_sheath", "back"}
    self.choices = self:buildChoices()
    return self
end

function LoadoutState:buildChoices()
    local choices = {}
    for slotId, slot in pairs(self.player.weaponSlots) do
        choices[slotId] = {}
        for _, weapon in ipairs(self.weaponData.weapons) do
            if weapon.slot == slotId and (slot.unlocked or weapon.id == slot.equipped) then
                table.insert(choices[slotId], weapon.id)
            end
        end
        if slot.unlocked and slotId == "back" then
            table.insert(choices[slotId], 1, "")
        end
    end
    return choices
end

function LoadoutState:update(dt)
end

function LoadoutState:keypressed(key)
    if key == "up" then
        self.selectedSlotIndex = math.max(1, self.selectedSlotIndex - 1)
    elseif key == "down" then
        self.selectedSlotIndex = math.min(#self.slotOrder, self.selectedSlotIndex + 1)
    elseif key == "a" or key == "left" then
        self:cycleSelected(-1)
    elseif key == "d" or key == "right" then
        self:cycleSelected(1)
    elseif key == "return" or key == "kpenter" then
        self.onStartRun(self.player:exportRunData())
    end
end

function LoadoutState:cycleSelected(dir)
    local slotId = self.slotOrder[self.selectedSlotIndex]
    local slot = self.player.weaponSlots[slotId]
    if not slot.unlocked then
        self.message = "That slot is locked at the start of a run."
        return
    end

    local options = self.choices[slotId]
    if not options or #options == 0 then
        return
    end

    local current = slot.equipped or ""
    local currentIndex = 1
    for i, weaponId in ipairs(options) do
        if weaponId == current then
            currentIndex = i
            break
        end
    end

    local nextIndex = currentIndex + dir
    if nextIndex < 1 then nextIndex = #options end
    if nextIndex > #options then nextIndex = 1 end

    slot.equipped = options[nextIndex]
    self.message = "Equipped updated for " .. slot.name .. "."
end

function LoadoutState:drawSlotCard(x, y, width, height, slot, selected, weaponData)
    local bg = selected and {0.42, 0.28, 0.16} or {0.22, 0.16, 0.12}
    love.graphics.setColor(bg)
    love.graphics.rectangle("fill", x, y, width, height, 8, 8)

    love.graphics.setColor(0.95, 0.90, 0.82)
    love.graphics.setFont(self.shared.fonts.medium)
    love.graphics.print(slot.name, x + 14, y + 10)

    love.graphics.setFont(self.shared.fonts.small)
    local equippedLabel = slot.equipped ~= "" and weaponData.byId[slot.equipped].name or "Empty"
    love.graphics.print("Status: " .. (slot.unlocked and "Unlocked" or "Locked"), x + 14, y + 42)
    love.graphics.print("Equipped: " .. equippedLabel, x + 14, y + 62)

    if slot.equipped ~= "" and weaponData.byId[slot.equipped] then
        local w = weaponData.byId[slot.equipped]
        love.graphics.printf("Type: " .. w.weaponType .. " | Ammo: " .. tostring(w.ammo or 0), x + 14, y + 84, width - 28)
        love.graphics.printf(w.description, x + 14, y + 104, width - 28)
    end
end

function LoadoutState:draw()
    local screenW = self.shared.screen.width
    local screenH = self.shared.screen.height

    love.graphics.setBackgroundColor(0.14, 0.10, 0.08)
    love.graphics.setColor(0.93, 0.86, 0.72)
    love.graphics.setFont(self.shared.fonts.large)
    love.graphics.printf("Western Deck Builder", 20, 24, screenW - 40, "center")

    love.graphics.setFont(self.shared.fonts.medium)
    love.graphics.printf("Loadout", 20, 64, screenW - 40, "center")
    love.graphics.printf("Starting slots", 20, 110, screenW - 40, "center")

    local cardX = 24
    local cardWidth = screenW - 48
    local cardHeight = 150
    local gap = 16
    local y = 150

    for i, slotId in ipairs(self.slotOrder) do
        local slot = self.player.weaponSlots[slotId]
        local selected = i == self.selectedSlotIndex
        self:drawSlotCard(cardX, y, cardWidth, cardHeight, slot, selected, self.weaponData)
        y = y + cardHeight + gap
    end

    love.graphics.setColor(0.90, 0.84, 0.70)
    love.graphics.setFont(self.shared.fonts.small)
    love.graphics.printf(self.message, 24, screenH - 90, screenW - 48, "center")
    love.graphics.printf("Controls: Up/Down select, A/D change, Enter start run", 24, screenH - 60, screenW - 48, "center")
end

return LoadoutState
