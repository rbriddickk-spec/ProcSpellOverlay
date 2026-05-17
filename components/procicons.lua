local AddonName, SAO = ...
local Module = "procicons"

-- Minimal, universal "Blizzard-like" proc icon display.
-- Shows fixed-order icons for active proc overlays.

local DefaultOrderBySpec = {
  ["WARRIOR:72"] = {190411, 5308, 184367},
}

local function db()
  ProcSpellOverlayDB = ProcSpellOverlayDB or {}
  ProcSpellOverlayDB.procIcons = ProcSpellOverlayDB.procIcons or {}
  local p = ProcSpellOverlayDB.procIcons

  if p.enabled == nil then p.enabled = true end
  if p.locked == nil then p.locked = true end
  if p.size == nil then p.size = 56 end
  if p.point == nil then p.point = "CENTER" end
  if p.x == nil then p.x = 0 end
  if p.y == nil then p.y = -140 end
  if p.gap == nil then p.gap = 10 end
  if p.maxIcons == nil then p.maxIcons = 4 end
  if p.testMode == nil then p.testMode = false end
  p.maxIcons = math.max(1, math.floor(tonumber(p.maxIcons) or 4))
  p.order = p.order or {}
  for key, defaultOrder in pairs(DefaultOrderBySpec) do
    if type(p.order[key]) ~= "table" then
      p.order[key] = CopyTable(defaultOrder)
    end
  end

  return p
end

local active = {}     -- [spellID] = true
local function ResolveDisplaySpellID(triggerSpellID)
  return (type(GlowTrackerDB)=="table" and type(GlowTrackerDB.alias)=="table" and GlowTrackerDB.alias[triggerSpellID]) or triggerSpellID
end

local container = CreateFrame("Frame", "SAO_ProcIconsContainer", UIParent)
container:SetClampedToScreen(true)
container:SetMovable(true)
container:EnableMouse(true)
container:RegisterForDrag("LeftButton")
container:SetScript("OnDragStart", function(self)
  local p = db()
  if not p.locked then self:StartMoving() end
end)
container:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local p = db()
  local point, _, _, x, y = self:GetPoint(1)
  p.point, p.x, p.y = point, x, y
end)

local function CreateIconFrame(name)
  local f = CreateFrame("Frame", name, container)
  f:Hide()

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetAllPoints(true)
  f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  f.border = f:CreateTexture(nil, "OVERLAY")
  f.border:SetAllPoints(true)
  f.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

  return f
end

local iconFrames = {}

local function EnsureIconFrames(count)
  for i = #iconFrames + 1, count do
    iconFrames[i] = CreateIconFrame("SAO_ProcIcon"..tostring(i))
  end
end

local function GetCurrentClassSpecKey()
  local _, classFile = UnitClass("player")
  if not classFile then return nil end
  local spec = GetSpecialization and GetSpecialization()
  local specID = spec and GetSpecializationInfo and GetSpecializationInfo(spec) or nil
  if specID then
    return classFile..":"..tostring(specID)
  end
  return classFile..":0"
end

local function ApplyLayout()
  local p = db()
  EnsureIconFrames(p.maxIcons)
  local point = p.point or "CENTER"

  container:ClearAllPoints()
  container:SetPoint(point, UIParent, point, p.x, p.y)

  local size = p.size
  local gap = p.gap
  local maxIcons = p.maxIcons

  container:SetSize(size * maxIcons + gap * (maxIcons - 1), size)
  for i = 1, maxIcons do
    local icon = iconFrames[i]
    icon:SetSize(size, size)
    icon:ClearAllPoints()
    if i == 1 then
      icon:SetPoint("LEFT", container, "LEFT", 0, 0)
    else
      icon:SetPoint("LEFT", iconFrames[i-1], "RIGHT", gap, 0)
    end
  end
end

local function SetIcon(iconFrame, spellID, isPlaceholder)
  if not spellID and not isPlaceholder then
    iconFrame:Hide()
    iconFrame.spellID = nil
    iconFrame:SetAlpha(1)
    return
  end

  local tex = isPlaceholder and "Interface\\Icons\\INV_Misc_QuestionMark" or GetSpellTexture(spellID)
  iconFrame.icon:SetTexture(tex)
  iconFrame.spellID = isPlaceholder and nil or spellID
  iconFrame:SetAlpha(isPlaceholder and 0.35 or 1)
  iconFrame:Show()
end

local function Refresh()
  local p = db()
  ApplyLayout()
  if not p.enabled then
    for i = 1, #iconFrames do
      iconFrames[i]:Hide()
    end
    container:Hide()
    return
  end

  local orderKey = GetCurrentClassSpecKey()
  local order = orderKey and p.order and p.order[orderKey] or nil
  local hasFixedOrder = type(order) == "table" and #order > 0
  local hasVisibleIcon = false
  if hasFixedOrder then
    for i = 1, p.maxIcons do
      local spellID = order[i]
      if spellID and (p.testMode or active[spellID]) then
        SetIcon(iconFrames[i], spellID)
        hasVisibleIcon = true
      else
        SetIcon(iconFrames[i], nil)
      end
    end
  else
    local activeSpellIDs = {}
    for spellID in pairs(active) do
      table.insert(activeSpellIDs, spellID)
    end
    table.sort(activeSpellIDs)
    for i = 1, p.maxIcons do
      local spellID = activeSpellIDs[i]
      if spellID then
        SetIcon(iconFrames[i], spellID)
        hasVisibleIcon = true
      elseif p.testMode and #activeSpellIDs == 0 then
        SetIcon(iconFrames[i], nil, true)
        hasVisibleIcon = true
      else
        SetIcon(iconFrames[i], nil)
      end
    end
  end
  for i = p.maxIcons + 1, #iconFrames do
    iconFrames[i]:Hide()
  end

  container:SetShown(hasVisibleIcon or p.testMode)
end

function SAO:ProcIcons_Activate(spellID)
  if type(spellID) ~= "number" then return end
  active[ResolveDisplaySpellID(spellID)] = true
  Refresh()
end

function SAO:ProcIcons_Deactivate(spellID)
  if type(spellID) ~= "number" then return end
  active[ResolveDisplaySpellID(spellID)] = nil
  Refresh()
end

function SAO:ProcIcons_SetTestMode(on)
  local p = db()
  p.testMode = on == true
  Refresh()
  return p.testMode
end

function SAO:ProcIcons_ToggleTestMode()
  return self:ProcIcons_SetTestMode(not db().testMode)
end

function SAO:ProcIcons_ApplyLayoutAndRefresh()
  ApplyLayout()
  Refresh()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_SHOW")
ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_HIDE")
ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")

ev:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
    ApplyLayout()
    Refresh()
    return
  end

  local spellID = ...
  if type(spellID) ~= "number" then return end

  if event == "SPELL_ACTIVATION_OVERLAY_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
    SAO:ProcIcons_Activate(spellID)
  elseif event == "SPELL_ACTIVATION_OVERLAY_HIDE" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
    SAO:ProcIcons_Deactivate(spellID)
  end
end)
