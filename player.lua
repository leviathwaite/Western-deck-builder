local Player = {}
Player.__index = Player

function Player.new(weaponData)
    local self = setmetatable({}, Player)
    self.weaponData = weaponData
    self.maxHp = 70
    self.hp = 70
    self.maxEnergy = 3
    self.energy = 3
    self.handSize = 5
    self.block = 0
    self.weaponSlots = {
        left_holster = {name = "Left Holster", unlocked = true, equipped = "basic_revolver"},
        right_holster = {name = "Right Holster", unlocked = false, equipped = ""},
        knife_sheath = {name = "Knife Sheath", unlocked = true, equipped = "basic_knife"},
        back = {name = "Back Slot", unlocked = true, equipped = ""}
    }
    self.runtimeWeapons = {}
    self:refreshRuntimeWeapons()
    return self
end

function Player.fromRunData(weaponData, runData)
    local self = Player.new(weaponData)
    if runData and runData.weaponSlots then
        for slotId, slotData in pairs(runData.weaponSlots) do
            self.weaponSlots[slotId].unlocked = slotData.unlocked
            self.weaponSlots[slotId].equipped = slotData.equipped
        end
    end
    self:refreshRuntimeWeapons()
    return self
end

function Player:refreshRuntimeWeapons()
    self.runtimeWeapons = {}
    for slotId, slot in pairs(self.weaponSlots) do
        if slot.equipped ~= "" then
            local weaponDef = self.weaponData.byId[slot.equipped]
            if weaponDef then
                self.runtimeWeapons[slot.equipped] = {
                    id = weaponDef.id,
                    slot = slotId,
                    name = weaponDef.name,
                    ammo = weaponDef.ammo or 0,
                    maxAmmo = weaponDef.ammo or 0,
                    damageBonus = weaponDef.damageBonus or 0,
                    weaponType = weaponDef.weaponType
                }
            end
        end
    end
end

function Player:exportRunData()
    return {
        weaponSlots = self.weaponSlots
    }
end

function Player:getEquippedWeapons()
    local result = {}
    for _, slotId in ipairs({"left_holster", "right_holster", "knife_sheath", "back"}) do
        local equipped = self.weaponSlots[slotId].equipped
        if equipped and equipped ~= "" then
            table.insert(result, equipped)
        end
    end
    return result
end

function Player:getWeaponStatusLines()
    local lines = {}
    for _, slotId in ipairs({"left_holster", "right_holster", "knife_sheath", "back"}) do
        local slot = self.weaponSlots[slotId]
        if slot.equipped ~= "" then
            local runtime = self.runtimeWeapons[slot.equipped]
            local ammoText = runtime.maxAmmo > 0 and ("Ammo " .. runtime.ammo .. "/" .. runtime.maxAmmo) or "No ammo"
            table.insert(lines, slot.name .. ": " .. runtime.name .. " - " .. ammoText)
        else
            table.insert(lines, slot.name .. ": Empty")
        end
    end
    return lines
end

function Player:getBonusDamage(card)
    if not card.weapon then
        return 0
    end
    local weapon = self.runtimeWeapons[card.weapon]
    return weapon and weapon.damageBonus or 0
end

function Player:canPlayCard(card)
    if not card.weapon then
        return true, nil
    end
    local weapon = self.runtimeWeapons[card.weapon]
    if not weapon then
        return false, "Required weapon is not equipped."
    end
    if weapon.maxAmmo > 0 and (card.effects.damage or 0) > 0 and weapon.ammo <= 0 then
        return false, weapon.name .. " is out of ammo."
    end
    return true, nil
end

function Player:consumeAmmoForCard(card)
    if not card.weapon then
        return
    end
    local weapon = self.runtimeWeapons[card.weapon]
    if weapon and weapon.maxAmmo > 0 and (card.effects.damage or 0) > 0 then
        weapon.ammo = math.max(0, weapon.ammo - 1)
    end
end

function Player:restoreAmmo(weaponId, amount)
    local weapon = self.runtimeWeapons[weaponId]
    if weapon and weapon.maxAmmo > 0 then
        weapon.ammo = math.min(weapon.maxAmmo, weapon.ammo + amount)
    end
end

function Player:takeDamage(amount)
    local remaining = amount
    if self.block > 0 then
        local absorbed = math.min(self.block, remaining)
        self.block = self.block - absorbed
        remaining = remaining - absorbed
    end
    self.hp = math.max(0, self.hp - remaining)
end

return Player
