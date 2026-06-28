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
    self.message = "Tap a weapon slot to view options"
    self.selectedSlotIndex = 1
    self.slotOrder = {"left_holster", "right_holster", "knife_sheath", "back"}
    self.choices = self:buildChoices()
    self.buttons = {}
    self.showPanel = false
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
    elseif key == "escape" then
        self.showPanel = false
    end
end

function LoadoutState:mousepressed(x, y, button)
    -- Check START button first (highest priority)
    for i, btn in ipairs(self.buttons) do
        if btn.type == "start" and x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            self.onStartRun(self.player:exportRunData())
            return
        end
    end

    -- If panel is open, check panel buttons
    if self.showPanel then
        for i, btn in ipairs(self.buttons) do
            if btn.type == "panel_prev" and x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                self:cycleSelected(-1)
                return
            end
            if btn.type == "panel_next" and x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                self:cycleSelected(1)
                return
            end
            if btn.type == "panel_close" and x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                self.showPanel = false
                return
            end
        end

        -- Check if clicked inside panel area
        for i, btn in ipairs(self.buttons) do
            if btn.type == "panel_bg" then
                if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                    -- Inside panel, do nothing (don't close)
                    return
                end
            end
        end

        -- Clicked outside panel, close it
        self.showPanel = false
        return
    end

    -- Check slot cards
    for i, btn in ipairs(self.buttons) do
        if btn.type == "slot" and x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            self.selectedSlotIndex = btn.index
            self.showPanel = true
            return
        end
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
    self.message = "Equipped " .. (options[nextIndex] ~= "" and self.weaponData.byId[options[nextIndex]].name or "Empty") .. " in " .. slot.name
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

function LoadoutState:drawButton(label, x, y, width, height)
    love.graphics.setColor(0.58, 0.47, 0.30)
    love.graphics.rectangle("fill", x, y, width, height, 8, 8)
    love.graphics.setColor(0.95, 0.90, 0.82)
    love.graphics.setFont(self.shared.fonts.medium)
    love.graphics.printf(label, x, y + (height - 20) / 2, width, "center")
end

function LoadoutState:drawPanel()
    local screenW = self.shared.screen.width
    local screenH = self.shared.screen.height

    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Panel dimensions
    local panelW = screenW - 48
    local panelH = 320
    local panelX = 24
    local panelY = (screenH - panelH) / 2

    -- Panel background
    love.graphics.setColor(0.18, 0.14, 0.12)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 12, 12)
    table.insert(self.buttons, {type = "panel_bg", x = panelX, y = panelY, w = panelW, h = panelH})

    local slotId = self.slotOrder[self.selectedSlotIndex]
    local slot = self.player.weaponSlots[slotId]

    -- Header
    love.graphics.setColor(0.93, 0.86, 0.72)
    love.graphics.setFont(self.shared.fonts.large)
    love.graphics.printf(slot.name, panelX, panelY + 20, panelW, "center")

    -- Current equipment display
    local equippedY = panelY + 70
    love.graphics.setFont(self.shared.fonts.medium)
    love.graphics.setColor(0.95, 0.90, 0.82)
    
    if slot.equipped ~= "" and self.weaponData.byId[slot.equipped] then
        local w = self.weaponData.byId[slot.equipped]
        love.graphics.printf("Currently Equipped:", panelX + 20, equippedY, panelW - 40, "center")
        love.graphics.setFont(self.shared.fonts.large)
        love.graphics.printf(w.name, panelX + 20, equippedY + 30, panelW - 40, "center")
        love.graphics.setFont(self.shared.fonts.small)
        love.graphics.printf(w.description, panelX + 20, equippedY + 70, panelW - 40, "center")
    else
        love.graphics.printf("Currently Equipped:", panelX + 20, equippedY, panelW - 40, "center")
        love.graphics.setFont(self.shared.fonts.large)
        love.graphics.printf("Empty", panelX + 20, equippedY + 30, panelW - 40, "center")
    end

    -- Buttons at bottom of panel
    local btnY = panelY + panelH - 70
    local btnHeight = 50
    local btnGap = 10
    local btnWidth = (panelW - 60 - btnGap * 2) / 3

    if slot.unlocked then
        -- Previous button
        self:drawButton("<", panelX + 20, btnY, btnWidth, btnHeight)
        table.insert(self.buttons, {type = "panel_prev", x = panelX + 20, y = btnY, w = btnWidth, h = btnHeight})

        -- Close button
        self:drawButton("DONE", panelX + 20 + btnWidth + btnGap, btnY, btnWidth, btnHeight)
        table.insert(self.buttons, {type = "panel_close", x = panelX + 20 + btnWidth + btnGap, y = btnY, w = btnWidth, h = btnHeight})

        -- Next button
        self:drawButton(">", panelX + 20 + (btnWidth + btnGap) * 2, btnY, btnWidth, btnHeight)
        table.insert(self.buttons, {type = "panel_next", x = panelX + 20 + (btnWidth + btnGap) * 2, y = btnY, w = btnWidth, h = btnHeight})
    else
        -- Just close button for locked slots
        local closeW = panelW - 40
        self:drawButton("CLOSE", panelX + 20, btnY, closeW, btnHeight)
        table.insert(self.buttons, {type = "panel_close", x = panelX + 20, y = btnY, w = closeW, h = btnHeight})
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
    love.graphics.printf("Starting slots", 20, 90, screenW - 40, "center")

    -- Clear buttons for this frame
    self.buttons = {}

    local cardX = 24
    local cardWidth = screenW - 48
    local cardHeight = 130
    local gap = 12
    local y = 125

    for i, slotId in ipairs(self.slotOrder) do
        local slot = self.player.weaponSlots[slotId]
        local selected = i == self.selectedSlotIndex
        self:drawSlotCard(cardX, y, cardWidth, cardHeight, slot, selected, self.weaponData)
        -- Register slot as clickable
        table.insert(self.buttons, {type = "slot", index = i, x = cardX, y = y, w = cardWidth, h = cardHeight})
        y = y + cardHeight + gap
    end

    -- Message area
    local messageY = y + 10
    love.graphics.setColor(0.90, 0.84, 0.70)
    love.graphics.setFont(self.shared.fonts.small)
    love.graphics.printf(self.message, 24, messageY, screenW - 48, "center")

    -- START button at bottom
    local btnY = screenH - 100
    local btnHeight = 60
    local btnWidth = screenW - 48

    self:drawButton("START RUN", 24, btnY, btnWidth, btnHeight)
    table.insert(self.buttons, {type = "start", x = 24, y = btnY, w = btnWidth, h = btnHeight})

    -- Instructions
    love.graphics.setFont(self.shared.fonts.small)
    love.graphics.printf("Tap any slot to change equipment", 24, screenH - 30, screenW - 48, "center")

    -- Draw panel on top if active
    if self.showPanel then
        self:drawPanel()
    end
end

return LoadoutState
